import 'dart:async';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../judge_screen/data/timing_api.dart';
import '../../judge_screen/domain/models.dart';
import '../data/pending_action_dao.dart';
import '../domain/pending_action.dart';

const _uuid = Uuid();

/// Errores de red (sin conexión, timeout) — se encolan para reintentar.
/// Errores de negocio (400/403/404/409 por reglas del backend) — se
/// propagan tal cual al llamador, igual que hoy en la web, porque encolarlos
/// solo pospondría un error que va a repetirse.
bool _isNetworkFailure(Object e) {
  if (e is! DioException) return false;
  return e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.response == null;
}

/// Un reintento puede llegar tarde: el servidor ya proceso la petición original
/// pero la respuesta se perdió por la red. En ese caso el reintento choca con
/// una regla de negocio que en realidad significa "el efecto ya ocurrió" — se
/// trata como éxito silencioso en vez de como fallo (ver plan sección 3.3).
bool _isAlreadyProcessed(Object e) {
  if (e is! DioException) return false;
  final status = e.response?.statusCode;
  final msg = (e.response?.data is Map ? e.response!.data['message'] : e.response?.data)?.toString() ?? '';
  if (status == 409) return true; // "ya en progreso" / "ya está anulado", etc.
  if (status == 400 && (msg.contains('ya está COMPLETADO') || msg.contains('ya finalizó'))) return true;
  return false;
}

/// Cola offline de acciones del juez — ver plan sección 3.
/// Estrategia: cada acción intenta ir directo al servidor primero; solo se
/// encola si falla por conectividad. Al recuperar la señal (o al reanudar la
/// app desde background) se procesa la cola en orden estricto, respetando
/// dependencias entre acciones (ej. una salida que depende de un dorsal
/// marcado offline, que aún no tiene registroId real del servidor).
class OfflineQueueService {
  OfflineQueueService(this._api) {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) flush();
    });
  }

  final TimingApi _api;
  final _dao = PendingActionDao();
  StreamSubscription? _connectivitySub;
  bool _flushing = false;

  final _onActionResolved = StreamController<void>.broadcast();
  /// Emite cada vez que una acción encolada se confirma o falla — la UI puede
  /// escuchar esto para refrescar la pantalla "en base" sin esperar al polling.
  Stream<void> get onActionResolved => _onActionResolved.stream;

  void dispose() => _connectivitySub?.cancel();

  Future<List<PendingAction>> pendientes() => _dao.listNotConfirmed();

  // ── Wrappers online-first con fallback a cola ──────────────────────────

  /// Devuelve el resultado si se pudo marcar online; null si quedó encolado
  /// (sin conexión) — en ese caso el llamador debe avisar al juez que se
  /// sincronizará después, ya que no hay datos del competidor todavía.
  Future<MarcarDorsalResult?> marcarDorsal({
    required int numeroDorsal,
    required String tokenSesion,
  }) async {
    try {
      return await _api.marcarDorsal(numeroDorsal, tokenSesion);
    } catch (e) {
      if (!_isNetworkFailure(e)) rethrow;
      await _dao.insert(PendingAction(
        id: _uuid.v4(),
        actionType: ActionType.marcarDorsal,
        payload: {'numeroDorsal': numeroDorsal, 'tokenSesion': tokenSesion},
        createdAt: DateTime.now(),
      ));
      return null;
    }
  }

  Future<void> registrarSalida({
    required String registroId,
    required String tokenSesion,
    String? dependsOnActionId,
  }) async {
    try {
      await _api.registrarSalida(registroId, tokenSesion);
    } catch (e) {
      if (!_isNetworkFailure(e)) rethrow;
      await _dao.insert(PendingAction(
        id: _uuid.v4(),
        actionType: ActionType.registrarSalida,
        payload: {'registroId': registroId, 'tokenSesion': tokenSesion},
        dependsOnActionId: dependsOnActionId,
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<void> penalizarCatalogo({
    required String registroId,
    required String catalogoId,
    String? motivo,
    required String tokenSesion,
    String? dependsOnActionId,
  }) async {
    try {
      await _api.penalizarCatalogo(
          registroId: registroId, catalogoId: catalogoId, motivo: motivo, tokenSesion: tokenSesion);
    } catch (e) {
      if (!_isNetworkFailure(e)) rethrow;
      await _dao.insert(PendingAction(
        id: _uuid.v4(),
        actionType: ActionType.penalizacionCatalogo,
        payload: {
          'registroId': registroId, 'catalogoId': catalogoId, 'motivo': motivo, 'tokenSesion': tokenSesion,
        },
        dependsOnActionId: dependsOnActionId,
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<void> penalizarLibre({
    required String registroId,
    required int segundos,
    required String motivo,
    required String tokenSesion,
    String? dependsOnActionId,
  }) async {
    try {
      await _api.penalizarLibre(registroId: registroId, segundos: segundos, motivo: motivo, tokenSesion: tokenSesion);
    } catch (e) {
      if (!_isNetworkFailure(e)) rethrow;
      await _dao.insert(PendingAction(
        id: _uuid.v4(),
        actionType: ActionType.penalizacionLibre,
        payload: {
          'registroId': registroId, 'segundos': segundos, 'motivo': motivo, 'tokenSesion': tokenSesion,
        },
        dependsOnActionId: dependsOnActionId,
        createdAt: DateTime.now(),
      ));
    }
  }

  // ── Procesamiento de la cola ────────────────────────────────────────────

  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      var progressed = true;
      while (progressed) {
        progressed = false;
        final pending = await _dao.listNotConfirmed();
        if (pending.isEmpty) break;

        final confirmedIds = pending.where((a) => a.status == ActionStatus.confirmed).map((a) => a.id).toSet();

        for (final action in pending) {
          if (action.status == ActionStatus.failed) continue;
          if (action.dependsOnActionId != null && !confirmedIds.contains(action.dependsOnActionId)) {
            continue; // la dependencia todavía no se confirmó — se reintenta en la próxima pasada
          }
          if (!action.readyToRetry) continue;

          final resolved = await _tryExecute(action, pending);
          if (resolved) progressed = true;
        }
      }
      await _dao.purgeConfirmedOlderThan(const Duration(hours: 24));
    } finally {
      _flushing = false;
    }
  }

  Future<bool> _tryExecute(PendingAction action, List<PendingAction> batch) async {
    final withAttempt = action.copyWith(attempts: action.attempts + 1, lastAttemptAt: DateTime.now());
    await _dao.update(withAttempt);

    try {
      String? serverRegistroId;
      switch (action.actionType) {
        case ActionType.marcarDorsal:
          final result = await _api.marcarDorsal(
            action.payload['numeroDorsal'] as int,
            action.payload['tokenSesion'] as String,
          );
          serverRegistroId = result.registroId;
          break;
        case ActionType.registrarSalida:
          await _api.registrarSalida(
            _resolveRegistroId(action, batch, 'registroId'),
            action.payload['tokenSesion'] as String,
          );
          break;
        case ActionType.penalizacionCatalogo:
          await _api.penalizarCatalogo(
            registroId: _resolveRegistroId(action, batch, 'registroId'),
            catalogoId: action.payload['catalogoId'] as String,
            motivo: action.payload['motivo'] as String?,
            tokenSesion: action.payload['tokenSesion'] as String,
          );
          break;
        case ActionType.penalizacionLibre:
          await _api.penalizarLibre(
            registroId: _resolveRegistroId(action, batch, 'registroId'),
            segundos: action.payload['segundos'] as int,
            motivo: action.payload['motivo'] as String,
            tokenSesion: action.payload['tokenSesion'] as String,
          );
          break;
      }
      await _dao.update(withAttempt.copyWith(status: ActionStatus.confirmed, serverRegistroId: serverRegistroId));
      _onActionResolved.add(null);
      return true;
    } catch (e) {
      if (_isAlreadyProcessed(e)) {
        await _dao.update(withAttempt.copyWith(status: ActionStatus.confirmed));
        _onActionResolved.add(null);
        return true;
      }
      final exhausted = withAttempt.attempts >= PendingAction.maxAttempts;
      await _dao.update(withAttempt.copyWith(
        status: exhausted ? ActionStatus.failed : ActionStatus.pending,
        errorMessage: e.toString(),
      ));
      if (exhausted) _onActionResolved.add(null);
      return false;
    }
  }

  /// Si la acción dependía de un marcar-dorsal encolado, resuelve el registroId
  /// real ya confirmado por el servidor en vez del id local temporal.
  String _resolveRegistroId(PendingAction action, List<PendingAction> batch, String key) {
    final raw = action.payload[key] as String;
    if (action.dependsOnActionId == null) return raw;
    final dep = batch.where((a) => a.id == action.dependsOnActionId).firstOrNull;
    return dep?.serverRegistroId ?? raw;
  }
}
