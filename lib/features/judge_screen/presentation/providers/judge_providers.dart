import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/secure_session.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../offline_queue/presentation/offline_queue_provider.dart';
import '../../data/timing_api.dart';
import '../../domain/models.dart';

final timingApiProvider = Provider((ref) => TimingApi());

/// true = socket conectado y confirmado por el servidor.
final wsConnectedProvider = StateProvider<bool>((ref) => false);

/// Alerta de heat activa (banner rojo) — null si no hay ninguna.
final alertaHeatProvider = StateProvider<AlertaHeat?>((ref) => null);

/// Notificación transitoria (salida grupal/individual, retenido/liberado).
final transientNotifProvider = StateProvider<String?>((ref) => null);

/// Pantalla "en base" — equivalente al estado `pantalla` de JudgePage.tsx.
/// Se sincroniza por polling (cada 5s, igual que la web) + eventos de socket.
class PantallaNotifier extends StateNotifier<AsyncValue<List<CompetidorEnBase>>> {
  PantallaNotifier(this._ref, this._session) : super(const AsyncValue.loading()) {
    _wireSocket();
    _startPolling();
    refresh();
  }

  final Ref _ref;
  final JuezSession _session;
  Timer? _pollTimer;
  StreamSubscription? _queueSub;
  /// Sesión cerrada por el organizador (kick) o notifier ya descartado —
  /// evita que el reintento automático de reconexión resucite un socket
  /// con un tokenSesion que el backend ya invalidó.
  bool _cerrada = false;

  TimingApi get _api => _ref.read(timingApiProvider);

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    // Cuando la cola offline confirma o agota reintentos de una acción,
    // refresca de inmediato en vez de esperar el próximo ciclo de polling.
    _queueSub = _ref.read(offlineQueueProvider).onActionResolved.listen((_) => refresh());
  }

  void _wireSocket() {
    final socket = _ref.read(socketClientProvider);

    socket.on('conexion-confirmada', (_) => _ref.read(wsConnectedProvider.notifier).state = true);
    socket.on('disconnect', (_) {
      _ref.read(wsConnectedProvider.notifier).state = false;
      if (_cerrada) return;
      Future.delayed(const Duration(seconds: 3), () {
        if (_cerrada) return;
        socket.forceReconnect(_session.tokenSesion);
      });
    });
    // El organizador puede forzar la desconexión de un juez desde su panel
    // (kickByToken) — antes esto solo mostraba "sin conexión" para siempre
    // y el dispositivo quedaba reintentando indefinidamente con un
    // tokenSesion que el backend ya borró. Ahora cierra la sesión local y
    // la app vuelve sola a la pantalla de ingresar código.
    socket.on('error', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      final msg = d['message']?.toString() ?? '';
      if (msg.contains('cerrada')) {
        _cerrada = true;
        _ref.read(sessionProvider.notifier).logout();
      }
    });

    socket.on('dorsal-marcado', (_) => refresh());
    socket.on('salida-registrada', (_) => refresh());
    socket.on('llegada-registrada', (_) => refresh());
    socket.on('penalizacion-aplicada', (_) => refresh());
    socket.on('registro-anulado', (_) => refresh());

    socket.on('alerta-heat', (data) {
      _ref.read(alertaHeatProvider.notifier).state =
          AlertaHeat.fromJson(Map<String, dynamic>.from(data as Map));
    });

    socket.on('salida-grupal', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      _showNotif('SALIDA GRUPAL — ${d['nombreHeat']}');
    });
    socket.on('salida-individual', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      _showNotif('SALIDA — #${d['numeroDorsal']} ${d['nombre']}');
    });
    socket.on('atleta-retenido', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      _showNotif('RETENIDO — #${d['numeroDorsal']} ${d['nombre']}');
    });
    socket.on('atleta-liberado', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      _showNotif('LIBERADO — #${d['numeroDorsal']} ${d['nombre']}');
    });
  }

  void _showNotif(String msg) {
    _ref.read(transientNotifProvider.notifier).state = msg;
    Future.delayed(const Duration(seconds: 8), () {
      if (_ref.read(transientNotifProvider) == msg) {
        _ref.read(transientNotifProvider.notifier).state = null;
      }
    });
  }

  Future<void> refresh() async {
    try {
      final data = await _api.getPantalla(_session.tokenSesion);
      state = AsyncValue.data(data);
    } catch (e, st) {
      // 404 en /timing/pantalla significa "sesión no encontrada o expirada"
      // (ej. el organizador te desconectó, o la sesión quedó inválida) — no
      // tiene sentido seguir reintentando con un token muerto, se cierra la
      // sesión localmente para que el juez vuelva a la pantalla de acceso
      // en vez de quedar atascado viendo un error crudo.
      if (e is DioException && e.response?.statusCode == 404) {
        _pollTimer?.cancel();
        await _ref.read(sessionProvider.notifier).logout();
        return;
      }
      // Para cualquier otro error, mantiene el último estado bueno visible
      // en vez de mostrar error en pantalla completa.
      if (!state.hasValue) state = AsyncValue.error(e, st);
    }
  }

  /// Fuerza reconexión de socket + flush de la cola offline + refresco —
  /// usado al volver de background (ver plan sección 3.4).
  void onResumed() {
    final socket = _ref.read(socketClientProvider);
    socket.forceReconnect(_session.tokenSesion);
    _ref.read(offlineQueueProvider).flush();
    refresh();
  }

  @override
  void dispose() {
    _cerrada = true;
    _pollTimer?.cancel();
    _queueSub?.cancel();
    super.dispose();
  }
}

final pantallaProvider =
    StateNotifierProvider<PantallaNotifier, AsyncValue<List<CompetidorEnBase>>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    throw StateError('pantallaProvider requiere una sesión activa');
  }
  return PantallaNotifier(ref, session);
});
