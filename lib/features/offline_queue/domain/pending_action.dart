enum ActionType { marcarDorsal, registrarSalida, penalizacionCatalogo, penalizacionLibre }

enum ActionStatus { pending, inFlight, confirmed, failed }

ActionType actionTypeFromString(String s) => ActionType.values.firstWhere((e) => e.name == s);
ActionStatus actionStatusFromString(String s) => ActionStatus.values.firstWhere((e) => e.name == s);

/// Una acción del juez pendiente de sincronizar con el servidor — equivalente
/// a la fila de la tabla pending_actions (ver plan sección 3.2).
class PendingAction {
  final String id;
  final ActionType actionType;
  final Map<String, dynamic> payload;
  final String? dependsOnActionId;
  final ActionStatus status;
  final int attempts;
  final DateTime? lastAttemptAt;
  final DateTime createdAt;
  final String? serverRegistroId;
  final String? errorMessage;

  const PendingAction({
    required this.id,
    required this.actionType,
    required this.payload,
    this.dependsOnActionId,
    this.status = ActionStatus.pending,
    this.attempts = 0,
    this.lastAttemptAt,
    required this.createdAt,
    this.serverRegistroId,
    this.errorMessage,
  });

  PendingAction copyWith({
    ActionStatus? status,
    int? attempts,
    DateTime? lastAttemptAt,
    String? serverRegistroId,
    String? errorMessage,
  }) =>
      PendingAction(
        id: id,
        actionType: actionType,
        payload: payload,
        dependsOnActionId: dependsOnActionId,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
        createdAt: createdAt,
        serverRegistroId: serverRegistroId ?? this.serverRegistroId,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  /// Backoff exponencial simple: min(2^intentos seg, 30s).
  bool get readyToRetry {
    if (lastAttemptAt == null) return true;
    final waitSeconds = (1 << attempts).clamp(1, 30);
    return DateTime.now().difference(lastAttemptAt!).inSeconds >= waitSeconds;
  }

  static const maxAttempts = 10;
}
