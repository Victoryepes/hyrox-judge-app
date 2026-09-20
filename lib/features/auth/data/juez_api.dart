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

class CircuitoEstacion {
  final String id;
  final int numeroOrden;
  final String tipo;
  final String nombreEjercicio;
  final String detalleRepeticiones;

  const CircuitoEstacion({
    required this.id,
    required this.numeroOrden,
    required this.tipo,
    required this.nombreEjercicio,
    required this.detalleRepeticiones,
  });

  factory CircuitoEstacion.fromJson(Map<String, dynamic> json) => CircuitoEstacion(
        id: json['id'] as String,
        numeroOrden: json['numeroOrden'] as int,
        tipo: json['tipo'] as String,
        nombreEjercicio: json['nombreEjercicio'] as String? ?? '',
        detalleRepeticiones: json['detalleRepeticiones'] as String? ?? '',
      );
}

class CircuitoCategoria {
  final String categoriaId;
  final String nombreCategoria;
  final String colorHex;
  final List<CircuitoEstacion> estaciones;

  const CircuitoCategoria({
    required this.categoriaId,
    required this.nombreCategoria,
    required this.colorHex,
    required this.estaciones,
  });

  factory CircuitoCategoria.fromJson(Map<String, dynamic> json) => CircuitoCategoria(
        categoriaId: json['categoriaId'] as String,
        nombreCategoria: json['nombreCategoria'] as String,
        colorHex: json['colorHex'] as String? ?? '#888888',
        estaciones: (json['estaciones'] as List)
            .map((e) => CircuitoEstacion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CircuitoJuez {
  final bool asignacionMovilJuez;
  final List<CircuitoCategoria> categorias;

  const CircuitoJuez({required this.asignacionMovilJuez, required this.categorias});

  factory CircuitoJuez.fromJson(Map<String, dynamic> json) => CircuitoJuez(
        asignacionMovilJuez: json['asignacionMovilJuez'] as bool? ?? false,
        categorias: (json['categorias'] as List)
            .map((e) => CircuitoCategoria.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Equivalente a juezService en services/api.ts.
class JuezApi {
  final _dio = ApiClient.instance.dio;

  /// Paso 1: GET /juez/estaciones/by-codigo/:codigo — valida el código y
  /// devuelve las estaciones de esa competencia. El backend ya deduplica por
  /// ejercicio (catalogoEjercicioId) para toda la competencia, así que una
  /// misma base compartida entre categorías aparece una sola vez.
  Future<List<EstacionOption>> estacionesPorCodigo(String codigo) async {
    final res = await _dio.get('/juez/estaciones/by-codigo/$codigo');
    return (res.data as List)
        .map((e) => EstacionOption.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.numeroOrden.compareTo(b.numeroOrden));
  }

  /// GET /juez/circuito/by-codigo/:codigo — dice si la competencia usa
  /// asignación móvil de jueces y devuelve el circuito completo por categoría.
  Future<CircuitoJuez> circuitoPorCodigo(String codigo) async {
    final res = await _dio.get('/juez/circuito/by-codigo/$codigo');
    return CircuitoJuez.fromJson(res.data as Map<String, dynamic>);
  }

  /// Paso 2 (modo fijo): POST /juez/conectar con estacionId. La cédula debe
  /// estar previamente registrada por el organizador para esta competencia.
  Future<JuezSession> conectar({
    required String codigoAcceso,
    required String documento,
    required EstacionOption estacion,
  }) async {
    final res = await _dio.post('/juez/conectar', data: {
      'codigoAcceso': codigoAcceso,
      'documento': documento,
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
      documento: documento,
    );
  }

  /// Modo móvil: POST /juez/conectar sin categoría ni estación — el juez ve
  /// todas las categorías y bases del circuito dentro de la app y selecciona
  /// la base real antes de cada marcado (ver judge_home_screen.dart).
  Future<JuezSession> conectarMovil({
    required String codigoAcceso,
    required String documento,
  }) async {
    final res = await _dio.post('/juez/conectar', data: {
      'codigoAcceso': codigoAcceso,
      'documento': documento,
    });
    final data = res.data as Map<String, dynamic>;
    return JuezSession(
      tokenSesion: data['tokenSesion'] as String,
      sesionId: data['id'] as String,
      competenciaId: data['competenciaId'] as String,
      estacionId: data['estacionId'] as String,
      nombreEstacion: 'Asignación móvil',
      codigoAcceso: codigoAcceso,
      nombreCompetencia: data['nombreCompetencia'] as String?,
      modoMovil: true,
      documento: documento,
    );
  }

  Future<void> desconectar(String tokenSesion) async {
    await _dio.delete('/juez/desconectar', data: {'tokenSesion': tokenSesion});
  }
}
