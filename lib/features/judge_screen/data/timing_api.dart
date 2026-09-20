import '../../../core/network/api_client.dart';
import '../../auth/data/juez_api.dart' show CircuitoJuez;
import '../domain/models.dart';

/// Equivalente a timingService en services/api.ts.
class TimingApi {
  final _dio = ApiClient.instance.dio;

  Future<MarcarDorsalResult> marcarDorsal(int numeroDorsal, String tokenSesion) async {
    final res = await _dio.post(
      '/timing/marcar-dorsal',
      data: {'numeroDorsal': numeroDorsal},
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
    return MarcarDorsalResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> registrarSalida(String registroId, String tokenSesion) async {
    await _dio.post(
      '/timing/registrar-salida',
      data: {'registroId': registroId},
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
  }

  /// Corrige de inmediato una entrada marcada por error de tipeo mientras
  /// sigue EN_PROGRESO — el tiempo de esa base queda en 0 si se vuelve a
  /// marcar correctamente después.
  Future<void> deshacerEntrada(String registroId, String tokenSesion) async {
    await _dio.patch(
      '/timing/entradas/$registroId/deshacer',
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
  }

  /// Deshace una base ya completada (salida marcada por error de tipeo):
  /// anula el par entrada/salida para que quede vacía y el competidor pueda
  /// volver a ingresar con datos limpios.
  Future<void> deshacerSalida(String registroEntradaId, String tokenSesion) async {
    await _dio.patch(
      '/timing/bases/$registroEntradaId/deshacer',
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
  }

  /// Descalificación en pista — decisión de arbitraje del juez, requiere
  /// confirmación en la UI antes de llamarse.
  Future<void> descalificar(String competidorId, String? motivo, String tokenSesion) async {
    await _dio.patch(
      '/timing/competidores/$competidorId/descalificar',
      data: {'motivo': motivo},
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
  }

  /// Igual que [descalificar] pero por número de dorsal — para modo dorsal,
  /// donde no siempre se tiene el competidorId a mano.
  Future<void> descalificarPorDorsal(int numeroDorsal, String? motivo, String tokenSesion) async {
    await _dio.patch(
      '/timing/descalificar-dorsal',
      data: {'numeroDorsal': numeroDorsal, 'motivo': motivo},
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
  }

  /// [estacionId]: en asignación móvil el juez no está atado a una posición
  /// física — debe indicar explícitamente en qué base está parado para ver
  /// quién está en base ahí. Ignorado en modo fijo (usa la estación de la
  /// conexión).
  Future<List<CompetidorEnBase>> getPantalla(String tokenSesion, {String? estacionId}) async {
    final res = await _dio.get(
      '/timing/pantalla',
      queryParameters: estacionId != null ? {'estacionId': estacionId} : null,
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
    return (res.data as List)
        .map((e) => CompetidorEnBase.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CompetidorListado>> competidoresJuez(String tokenSesion) async {
    final res = await _dio.get(
      '/timing/competidores',
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
    return (res.data as List)
        .map((e) => CompetidorListado.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RepsPorCategoria>> repsPorCategoria(String tokenSesion) async {
    final res = await _dio.get(
      '/timing/reps-por-categoria',
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
    return (res.data as List)
        .map((e) => RepsPorCategoria.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /timing/circuito — circuito completo por categoría, usado en modo
  /// móvil para que el juez vea todas las bases que debe recorrer siguiendo
  /// a un competidor/pareja, filtrable por categoría.
  Future<CircuitoJuez> circuitoJuez(String tokenSesion) async {
    final res = await _dio.get(
      '/timing/circuito',
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
    return CircuitoJuez.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<PenalizacionCatalogoItem>> catalogoPenalizaciones(String tokenSesion) async {
    final res = await _dio.get(
      '/timing/penalizaciones',
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
    return (res.data as List)
        .map((e) => PenalizacionCatalogoItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> penalizarCatalogo({
    required String registroId,
    required String catalogoId,
    String? motivo,
    required String tokenSesion,
  }) async {
    await _dio.post(
      '/timing/penalizacion/catalogo',
      data: {'registroId': registroId, 'catalogoId': catalogoId, 'motivo': ?motivo},
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
  }

  Future<void> penalizarLibre({
    required String registroId,
    required int segundos,
    required String motivo,
    required String tokenSesion,
  }) async {
    await _dio.post(
      '/timing/penalizacion/libre',
      data: {'registroId': registroId, 'segundos': segundos, 'motivo': motivo},
      options: ApiClient.instance.withTokenSesion(tokenSesion),
    );
  }
}
