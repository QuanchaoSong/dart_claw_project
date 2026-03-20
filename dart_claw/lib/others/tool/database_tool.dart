import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_claw/others/model/claw_session_info.dart';
import 'package:dart_claw/others/model/scheduled_task_info.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ─── DatabaseTool ─────────────────────────────────────────────────────────────

/// 封装 SQLite 的 CRUD 操作
///
/// 使用前必须调用 [init]（在 main() 或首次使用前）。
class DatabaseTool {
  static const _dbFileName = 'dart_claw.db';
  static const _dbVersion = 4;

  Database? _db;

  // 单例
  static final DatabaseTool shared = DatabaseTool._();
  DatabaseTool._();

  // ─── 初始化 ──────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_db != null) return;

    // 桌面端必须先初始化 FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final supportDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(supportDir.path, 'dart_claw'));
    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);

    final dbPath = p.join(dbDir.path, _dbFileName);
    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: (db, oldVersion, newVersion) async {
          // 开发阶段直接重建，不考虑数据迁移
          await db.execute('DROP TABLE IF EXISTS messages');
          await db.execute('DROP TABLE IF EXISTS sessions');
          await db.execute('DROP TABLE IF EXISTS scheduled_tasks');
          await _onCreate(db, newVersion);
        },
      ),
    );
  }

  Database get _database {
    assert(_db != null, 'DatabaseTool not initialised — call init() first');
    return _db!;
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
        id             TEXT PRIMARY KEY,
        session_id     TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        role           TEXT NOT NULL,
        blocks_json    TEXT NOT NULL,
        attached_paths TEXT,
        status         TEXT NOT NULL,
        sort_index     INTEGER NOT NULL,
        created_at     INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_messages_session ON messages(session_id, sort_index)',
    );

    await db.execute('''
      CREATE TABLE scheduled_tasks (
        id                       TEXT PRIMARY KEY,
        name                     TEXT NOT NULL,
        mode                     TEXT NOT NULL,
        hour                     INTEGER NOT NULL,
        minute                   INTEGER NOT NULL,
        weekdays                 TEXT NOT NULL DEFAULT '',
        once_at                  INTEGER,
        action_type              TEXT NOT NULL,
        payload                  TEXT NOT NULL,
        allow_all_tools          INTEGER NOT NULL DEFAULT 1,
        allow_tool_deviation     INTEGER NOT NULL DEFAULT 1,
        skill_name               TEXT,
        auto_fill_sudo_password  INTEGER NOT NULL DEFAULT 0,
        sudo_password            TEXT NOT NULL DEFAULT '',
        is_enabled               INTEGER NOT NULL DEFAULT 1,
        last_run_at              INTEGER
      )
    ''');
  }

  // ─── Session CRUD ─────────────────────────────────────────────────────────

  /// 插入新 session
  Future<void> insertSession(ClawSessionInfo session) async {
    await _database.insert(
      'sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 所有 session，按最近更新排序
  Future<List<ClawSessionInfo>> listSessions() async {
    final rows = await _database.query(
      'sessions',
      orderBy: 'updated_at DESC',
    );
    return rows.map(ClawSessionInfo.fromMap).toList();
  }

  /// 更新 session 标题 & updated_at
  Future<void> updateSessionTitle(String sessionId, String title) async {
    await _database.update(
      'sessions',
      {
        'title': title,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// 仅更新 updated_at（新消息到来时调用）
  Future<void> touchSession(String sessionId) async {
    await _database.update(
      'sessions',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// 删除 session（关联 messages 通过 ON DELETE CASCADE 自动删除）
  Future<void> deleteSession(String sessionId) async {
    await _database.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // ─── Message CRUD ─────────────────────────────────────────────────────────

  /// 插入或替换一条消息
  Future<void> upsertMessage(
    String sessionId,
    ClawChatMessage msg,
    int sortIndex,
  ) async {
    await _database.insert(
      'messages',
      {
        'id': msg.id,
        'session_id': sessionId,
        'role': msg.role.name,
        'blocks_json': jsonEncode(msg.toJson()['blocks']),
        'attached_paths': msg.attachedPaths.isEmpty
            ? null
            : jsonEncode(msg.attachedPaths),
        'status': msg.status.name,
        'sort_index': sortIndex,
        'created_at': msg.timestamp.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 读取某个 session 下的所有消息，按 sort_index 排序
  Future<List<ClawChatMessage>> loadMessages(String sessionId) async {
    final rows = await _database.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sort_index ASC',
    );
    return rows.map(_rowToMessage).toList();
  }

  ClawChatMessage _rowToMessage(Map<String, dynamic> row) {
    final blocksJson = jsonDecode(row['blocks_json'] as String) as List;
    final pathsRaw = row['attached_paths'] as String?;
    final paths = pathsRaw != null
        ? (jsonDecode(pathsRaw) as List).cast<String>()
        : <String>[];
    return ClawChatMessage.fromJson({
      'id': row['id'],
      'role': row['role'],
      'timestamp': row['created_at'],
      'status': row['status'],
      'blocks': blocksJson,
      'attached_paths': paths,
    });
  }

  /// 删除某个 session 的所有消息（一般不需要手动调，deleteSession 会级联）
  Future<void> deleteMessages(String sessionId) async {
    await _database.delete(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  // ─── ScheduledTaskInfo CRUD ─────────────────────────────────────────────────

  Future<List<ScheduledTaskInfo>> loadScheduledTasks() async {
    final rows = await _database.query('scheduled_tasks', orderBy: 'name ASC');
    return rows.map(ScheduledTaskInfo.fromMap).toList();
  }

  Future<void> upsertScheduledTask(ScheduledTaskInfo task) async {
    await _database.insert(
      'scheduled_tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteScheduledTask(String id) async {
    await _database.delete(
      'scheduled_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
