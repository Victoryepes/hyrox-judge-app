import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/env.dart';

/// Wrapper de socket.io-client — equivalente a useTimingSocket.ts del frontend web.
/// Namespace /timing, mismo handshake auth:{token} que usa el backend NestJS
/// tanto para jueces (tokenSesion) como organizadores (Bearer JWT).
class SocketClient {
  io.Socket? _socket;
  final Map<String, void Function(dynamic)> _handlers = {};

  bool get isConnected => _socket?.connected ?? false;

  void connect(String tokenSesion) {
    _socket?.dispose();

    final socket = io.io(
      '${Env.wsBaseUrl}/timing',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': tokenSesion})
          .enableReconnection()
          .setReconnectionDelayMax(10000)
          .build(),
    );

    _handlers.forEach((event, handler) => socket.on(event, handler));
    _socket = socket;
    socket.connect();
  }

  /// Fuerza una reconexión explícita — necesario al volver de background en
  /// Android, donde el proceso puede quedar congelado y el timer interno de
  /// reconexión de socket.io-client no corre mientras tanto.
  void forceReconnect(String tokenSesion) {
    if (isConnected) return;
    connect(tokenSesion);
  }

  void on(String event, void Function(dynamic) handler) {
    _handlers[event] = handler;
    _socket?.on(event, handler);
  }

  void off(String event) {
    final handler = _handlers.remove(event);
    if (handler != null) _socket?.off(event, handler);
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _handlers.clear();
  }
}
