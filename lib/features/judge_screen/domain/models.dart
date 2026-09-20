class CompetidorEnBase {
  final String registroId;
  final String competidorId;
  final int numeroDorsal;
  final String nombre;
  final DateTime horaEntrada;
  final int segundosEnBase;
  final int totalPenalizacionSegundos;
  final String nombreEjercicio;

  const CompetidorEnBase({
    required this.registroId,
    required this.competidorId,
    required this.numeroDorsal,
    required this.nombre,
    required this.horaEntrada,
    required this.segundosEnBase,
    required this.totalPenalizacionSegundos,
    this.nombreEjercicio = '',
  });

  factory CompetidorEnBase.fromJson(Map<String, dynamic> json) => CompetidorEnBase(
        registroId: json['registroId'] as String,
        competidorId: json['competidorId'] as String,
        numeroDorsal: json['numeroDorsal'] as int,
        nombre: json['nombre'] as String? ?? 'Desconocido',
        horaEntrada: DateTime.parse(json['horaEntrada'] as String),
        segundosEnBase: json['segundosEnBase'] as int,
        totalPenalizacionSegundos: json['totalPenalizacionSegundos'] as int? ?? 0,
        nombreEjercicio: json['nombreEjercicio'] as String? ?? '',
      );
}

class MarcarDorsalResult {
  final bool esLlegada;
  final bool esSalida;
  final String registroId;
  final String competidorNombre;
  final int numeroDorsal;
  final String? estacionNombre;
  final String? estacionDetalleRepeticiones;

  const MarcarDorsalResult({
    required this.esLlegada,
    required this.esSalida,
    required this.registroId,
    required this.competidorNombre,
    required this.numeroDorsal,
    this.estacionNombre,
    this.estacionDetalleRepeticiones,
  });

  factory MarcarDorsalResult.fromJson(Map<String, dynamic> json) {
    final registro = json['registro'] as Map<String, dynamic>;
    final competidor = json['competidor'] as Map<String, dynamic>;
    final estacion = json['estacion'] as Map<String, dynamic>?;
    return MarcarDorsalResult(
      esLlegada: json['esLlegada'] as bool,
      esSalida: json['esSalida'] as bool? ?? false,
      registroId: registro['id'] as String,
      competidorNombre: competidor['nombre'] as String,
      numeroDorsal: competidor['numeroDorsal'] as int,
      estacionNombre: estacion?['nombre'] as String?,
      estacionDetalleRepeticiones: estacion?['detalleRepeticiones'] as String?,
    );
  }
}

class CompetidorListado {
  final String id;
  final String nombre;
  final int numeroDorsal;
  final String? heatId;
  final String categoriaId;
  final String categoriaNombre;
  final String categoriaColorHex;
  /// id de la ENTRADA-COMPLETADO si esta base ya está completada por él —
  /// permite ofrecer "deshacer salida" en vez de solo bloquear el reingreso.
  final String? estacionCompletadaRegistroId;
  final bool descalificado;

  const CompetidorListado({
    required this.id,
    required this.nombre,
    required this.numeroDorsal,
    required this.heatId,
    required this.categoriaId,
    required this.categoriaNombre,
    required this.categoriaColorHex,
    this.estacionCompletadaRegistroId,
    this.descalificado = false,
  });

  factory CompetidorListado.fromJson(Map<String, dynamic> json) => CompetidorListado(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        numeroDorsal: json['numeroDorsal'] as int,
        heatId: json['heatId'] as String?,
        categoriaId: json['categoriaId'] as String,
        categoriaNombre: json['categoriaNombre'] as String? ?? '',
        categoriaColorHex: json['categoriaColorHex'] as String? ?? '#888888',
        estacionCompletadaRegistroId: json['estacionCompletadaRegistroId'] as String?,
        descalificado: json['descalificado'] as bool? ?? false,
      );
}

class RepsPorCategoria {
  final String id;
  final String nombre;
  final String colorHex;
  final String reps;

  const RepsPorCategoria({
    required this.id,
    required this.nombre,
    required this.colorHex,
    required this.reps,
  });

  factory RepsPorCategoria.fromJson(Map<String, dynamic> json) => RepsPorCategoria(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        colorHex: json['colorHex'] as String? ?? '#888888',
        reps: json['reps'] as String? ?? '',
      );
}

class PenalizacionCatalogoItem {
  final String id;
  final String nombre;
  final int segundosSumar;

  const PenalizacionCatalogoItem({
    required this.id,
    required this.nombre,
    required this.segundosSumar,
  });

  factory PenalizacionCatalogoItem.fromJson(Map<String, dynamic> json) => PenalizacionCatalogoItem(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        segundosSumar: json['segundosSumar'] as int,
      );
}

class AlertaHeat {
  final String nombreHeat;
  final int minutosRestantes;
  final DateTime? horaInicio;
  final int totalCompetidores;
  final List<CompetidorAlerta> competidores;

  const AlertaHeat({
    required this.nombreHeat,
    required this.minutosRestantes,
    required this.horaInicio,
    required this.totalCompetidores,
    required this.competidores,
  });

  factory AlertaHeat.fromJson(Map<String, dynamic> json) => AlertaHeat(
        nombreHeat: json['nombreHeat'] as String,
        minutosRestantes: json['minutosRestantes'] as int,
        horaInicio: json['horaInicio'] != null ? DateTime.tryParse(json['horaInicio'] as String) : null,
        totalCompetidores: json['totalCompetidores'] as int? ?? 0,
        competidores: ((json['competidores'] as List?) ?? [])
            .map((e) => CompetidorAlerta.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CompetidorAlerta {
  final String id;
  final int numeroDorsal;
  final String nombre;

  const CompetidorAlerta({required this.id, required this.numeroDorsal, required this.nombre});

  factory CompetidorAlerta.fromJson(Map<String, dynamic> json) => CompetidorAlerta(
        id: json['id'] as String,
        numeroDorsal: json['numeroDorsal'] as int,
        nombre: json['nombre'] as String,
      );
}
