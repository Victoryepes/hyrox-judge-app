import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/secure_session.dart';
import '../../../../core/network/socket_client.dart';
import '../../data/juez_api.dart';

final juezApiProvider = Provider((ref) => JuezApi());
final secureSessionStoreProvider = Provider((ref) => SecureSessionStore());
final socketClientProvider = Provider((ref) => SocketClient());

/// Estado de la sesión del juez — equivalente a juez.store.ts (zustand).
class SessionNotifier extends StateNotifier<AsyncValue<JuezSession?>> {
  SessionNotifier(this._store, this._api, this._socket) : super(const AsyncValue.loading()) {
    _restore();
  }

  final SecureSessionStore _store;
  final JuezApi _api;
  final SocketClient _socket;

  Future<void> _restore() async {
    final session = await _store.load();
    state = AsyncValue.data(session);
    if (session != null) _socket.connect(session.tokenSesion);
  }

  Future<void> login({required String codigoAcceso, required EstacionOption estacion}) async {
    final session = await _api.conectar(codigoAcceso: codigoAcceso, estacion: estacion);
    await _store.save(session);
    state = AsyncValue.data(session);
    _socket.connect(session.tokenSesion);
  }

  Future<void> logout() async {
    final current = state.value;
    if (current != null) {
      await _api.desconectar(current.tokenSesion).catchError((_) {});
    }
    _socket.disconnect();
    await _store.clear();
    state = const AsyncValue.data(null);
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, AsyncValue<JuezSession?>>((ref) {
  return SessionNotifier(
    ref.watch(secureSessionStoreProvider),
    ref.watch(juezApiProvider),
    ref.watch(socketClientProvider),
  );
});
