import 'package:dio/dio.dart';

/// Distingue un fallo de red/servidor de un error de validación real —
/// evita mensajes confusos tipo "código inválido" cuando en realidad la app
/// no pudo ni conectarse al backend.
String describeApiError(Object e, {String fallback = 'Ocurrió un error'}) {
  if (e is DioException) {
    if (e.response == null) {
      return 'Sin conexión con el servidor. Guardado localmente si aplica.';
    }
    final data = e.response?.data;
    final serverMsg = data is Map ? data['message'] : null;
    if (serverMsg is String && serverMsg.isNotEmpty) return serverMsg;
    if (serverMsg is List && serverMsg.isNotEmpty) return serverMsg.first.toString();
  }
  return fallback;
}
