import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../model/chat_session_info.dart';
import '../model/remote_message_info.dart';

class DatabaseTool {
  static final _instance = DatabaseTool._();
  factory DatabaseTool() => _instance;
  DatabaseTool._();

  static const _dbVersion = 1;
  static const _dbFileName = 'dart_claw_app.db';

  Database? _db;

  Database get _database {
    assert(_db != null, 'DatabaseTool not initialised — call init() first');
    return _db!;
  }

  Future<void> init() async {
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, _dbFileName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id         TEXT PRIMARY KEY,
        title      TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id          TEXT PRIMARY KEY,
        session_id  TEXT NOT NULL,
        type        TEXT NOT NULL,
        content     TEXT NOT NULL DEFAULT '',
        reasoning   TEXT NOT NULL DEFAULT '',
        tool_name   TEXT,
        tool_id     TEXT,
        tool_status TEXT,
        created_at  INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_msgs_session ON messages(session_id, created_at)',
    );
  }

  // ─── Session CRUD ──────────────────────────────────────────────────────────

  Future<List<ChatSessionInfo>> listSessions() async {
    final rows = await _database.query(
      'sessions',
      orderBy: 'updated_at DESC',
    );
    return rows.map(ChatSessionInfo.fromMap).toList();
  }

  Future<void> insertSession(ChatSessionInfo session) async {
    await _database.insert(
      'sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> touchSession(String id) async {
    await _database.update(
      'sessions',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSession(String id) async {
    await _database.delete('sessions', where: 'id = ?', whereArgs: [id]);
    await _database.delete(
      'messages',
      where: 'session_id = ?',
      whereArgs: [id],
    );
  }

  // ─── Message CRUD ──────────────────────────────────────────────────────────

  Future<void> upsertMessage(String sessionId, RemoteMessageInfo msg) async {
    await _database.insert(
      'messages',
      {
        'id': msg.id,
        'session_id': sessionId,
        'type': msg.type.name,
        'content': msg.content,
        'reasoning': msg.reasoning,
        'tool_name': msg.toolName,
        'tool_id': msg.toolId,
        'tool_status': msg.toolStatus,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RemoteMessageInfo>> loadMessages(String sessionId) async {
    final rows = await _database.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return rows.map(RemoteMessageInfo.fromMap).toList();
  }
}
