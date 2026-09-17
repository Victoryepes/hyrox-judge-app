import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Base sqlite local — usada únicamente para la cola offline (pending_actions).
/// Se eligió sqflite sobre SharedPreferences/Hive porque se necesita una cola
/// FIFO con estados y transacciones atómicas al reintentar (ver plan sección 3).
class LocalDb {
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'hyrox_judge.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_actions (
            id TEXT PRIMARY KEY,
            action_type TEXT NOT NULL,
            payload TEXT NOT NULL,
            depends_on_action_id TEXT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            attempts INTEGER NOT NULL DEFAULT 0,
            last_attempt_at INTEGER NULL,
            created_at INTEGER NOT NULL,
            server_registro_id TEXT NULL,
            error_message TEXT NULL
          )
        ''');
      },
    );
    return _db!;
  }
}
