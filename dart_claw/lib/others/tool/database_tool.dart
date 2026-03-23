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
  static const _dbVersion = 6;

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
        updated_at INTEGER NOT NULL,
        source     TEXT NOT NULL DEFAULT 'local'
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
        created_at     INTEGER NOT NULL,
        type           TEXT NOT NULL DEFAULT 'message',
        is_archived    INTEGER NOT NULL DEFAULT 0,
        covers_from    TEXT,
        covers_to      TEXT
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

  /// 插入或替换一条普通消息
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
        'type': 'message',
        'is_archived': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 插入一条摘要消息（type='summary'，替代已归档的原始消息在上下文中出现）
  Future<void> upsertSummary(
    String sessionId,
    ClawChatMessage msg,
    int sortIndex, {
    required String coversFrom,
    required String coversTo,
  }) async {
    await _database.insert(
      'messages',
      {
        'id': msg.id,
        'session_id': sessionId,
        'role': msg.role.name,
        'blocks_json': jsonEncode(msg.toJson()['blocks']),
        'attached_paths': null,
        'status': msg.status.name,
        'sort_index': sortIndex,
        'created_at': msg.timestamp.millisecondsSinceEpoch,
        'type': 'summary',
        'is_archived': 0,
        'covers_from': coversFrom,
        'covers_to': coversTo,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 插入一条分隔行（type='divider'，仅用于 UI 显示，不进入 API 上下文）
  Future<void> upsertDivider(
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
        'attached_paths': null,
        'status': msg.status.name,
        'sort_index': sortIndex,
        'created_at': msg.timestamp.millisecondsSinceEpoch,
        'type': 'divider',
        'is_archived': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 将指定 id 的消息标记为已归档（从活跃上下文中移除）
  Future<void> archiveMessages(List<String> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _database.rawUpdate(
      'UPDATE messages SET is_archived = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  /// 根据消息 ID 查询其 sort_index（含已归档消息）
  Future<int?> getSortIndex(String messageId) async {
    final rows = await _database.query(
      'messages',
      columns: ['sort_index'],
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['sort_index'] as int?;
  }

  /// 根据 id 读取某条消息（包括已归档的），用于 retrieve_message 工具
  Future<ClawChatMessage?> loadMessageById(String id) async {
    final rows = await _database.query(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToMessage(rows.first);
  }

  /// 读取某个 session 下的活跃消息（未归档），按 sort_index 排序
  /// 包含 summary 和 divider 行，供 UI 展示
  Future<List<ClawChatMessage>> loadMessages(String sessionId) async {
    final rows = await _database.query(
      'messages',
      where: 'session_id = ? AND is_archived = 0',
      whereArgs: [sessionId],
      orderBy: 'sort_index ASC',
    );
    return rows.map(_rowToMessage).toList();
  }

  /// 读取某个 session 下用于 API 上下文构建的消息（未归档 + 非 divider）
  Future<List<ClawChatMessage>> loadContextMessages(String sessionId) async {
    final rows = await _database.query(
      'messages',
      where: "session_id = ? AND is_archived = 0 AND type != 'divider'",
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
      'type': row['type'] as String? ?? 'message',
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
