import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_session.dart';

class EstacionOption {
  final String id;
  final int numeroOrden;
  final String tipo; // BASE | LLEGADA
  final String nombreEjercicio;
  final String detalleRepeticiones;

  const EstacionOption({
    required this.id,
    required this.numeroOrden,
    required this.tipo,
    required this.nombreEjercicio,
    required this.detalleRepeticiones,
  });

  factory EstacionOption.fromJson(Map<String, dynamic> json) => EstacionOption(
        id: json['id'] as String,
        numeroOrden: json['numeroOrden'] as int,
        tipo: json['tipo'] as String,
        nombreEjercicio: json['nombreEjercicio'] as String? ?? '',
        detalleRepeticiones: json['detalleRepeticiones'] as String? ?? '',
      );
}

/// Equivalente a juezService en services/api.ts.
class JuezApi {
  final _dio = ApiClient.instance.dio;

  /// Paso 1: GET /juez/estaciones/by-codigo/:codigo — valida el código y
  /// devuelve las estaciones de esa competencia. Deduplica por numeroOrden
  /// (una estación física por posición, igual que hace JudgeAccessModal.tsx).
  Future<List<EstacionOption>> estacionesPorCodigo(String codigo) async {
    final res = await _dio.get('/juez/estaciones/by-codigo/$codigo');
    final list = (res.data as List)
        .map((e) => EstacionOption.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.numeroOrden.compareTo(b.numeroOrden));

    final seen = <int>{};
    return list.where((e) => seen.add(e.numeroOrden)).toList();
  }

  /// Paso 2: POST /juez/conectar — crea la sesión y devuelve el tokenSesion.
  Future<JuezSession> conectar({
    required String codigoAcceso,
    required EstacionOption estacion,
  }) async {
    final res = await _dio.post('/juez/conectar', data: {
      'codigoAcceso': codigoAcceso,
      'estacionId': estacion.id,
    });
    final data = res.data as Map<String, dynamic>;
    return JuezSession(
      tokenSesion: data['tokenSesion'] as String,
      sesionId: data['id'] as String,
      competenciaId: data['competenciaId'] as String,
      estacionId: estacion.id,
      nombreEstacion: estacion.nombreEjercicio,
      codigoAcceso: codigoAcceso,
      nombreCompetencia: data['nombreCompetencia'] as String?,
    );
  }

  Future<void> desconectar(String tokenSesion) async {
    await _dio.delete('/juez/desconectar', data: {'tokenSesion': tokenSesion});
  }
}
