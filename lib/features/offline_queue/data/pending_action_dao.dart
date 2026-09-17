import 'dart:convert';
import '../../../core/storage/local_db.dart';
import '../domain/pending_action.dart';

class PendingActionDao {
  Future<void> insert(PendingAction action) async {
    final db = await LocalDb.instance();
    await db.insert('pending_actions', {
      'id': action.id,
      'action_type': action.actionType.name,
      'payload': jsonEncode(action.payload),
      'depends_on_action_id': action.dependsOnActionId,
      'status': action.status.name,
      'attempts': action.attempts,
      'last_attempt_at': action.lastAttemptAt?.millisecondsSinceEpoch,
      'created_at': action.createdAt.millisecondsSinceEpoch,
      'server_registro_id': action.serverRegistroId,
      'error_message': action.errorMessage,
    });
  }

  Future<List<PendingAction>> listNotConfirmed() async {
    final db = await LocalDb.instance();
    final rows = await db.query(
      'pending_actions',
      where: "status != ?",
      whereArgs: [ActionStatus.confirmed.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> update(PendingAction action) async {
    final db = await LocalDb.instance();
    await db.update(
      'pending_actions',
      {
        'status': action.status.name,
        'attempts': action.attempts,
        'last_attempt_at': action.lastAttemptAt?.millisecondsSinceEpoch,
        'server_registro_id': action.serverRegistroId,
        'error_message': action.errorMessage,
      },
      where: 'id = ?',
      whereArgs: [action.id],
    );
  }

  /// Purga acciones confirmadas más viejas que N horas (mantiene rastro reciente para soporte).
  Future<void> purgeConfirmedOlderThan(Duration age) async {
    final db = await LocalDb.instance();
    final cutoff = DateTime.now().subtract(age).millisecondsSinceEpoch;
    await db.delete(
      'pending_actions',
      where: 'status = ? AND created_at < ?',
      whereArgs: [ActionStatus.confirmed.name, cutoff],
    );
  }

  PendingAction _fromRow(Map<String, Object?> row) => PendingAction(
        id: row['id'] as String,
        actionType: actionTypeFromString(row['action_type'] as String),
        payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        dependsOnActionId: row['depends_on_action_id'] as String?,
        status: actionStatusFromString(row['status'] as String),
        attempts: row['attempts'] as int,
        lastAttemptAt: row['last_attempt_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(row['last_attempt_at'] as int)
            : null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        serverRegistroId: row['server_registro_id'] as String?,
        errorMessage: row['error_message'] as String?,
      );
}
