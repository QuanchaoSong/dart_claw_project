import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ─── Session 数据模型 ──────────────────────────────────────────────────────────

class ClawSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClawSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  ClawSession copyWith({String? title, DateTime? updatedAt}) => ClawSession(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory ClawSession.fromMap(Map<String, dynamic> m) => ClawSession(
        id: m['id'] as String,
        title: m['title'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };
}

// ─── DatabaseTool ─────────────────────────────────────────────────────────────

/// 封装 SQLite 的 CRUD 操作
///
/// 使用前必须调用 [init]（在 main() 或首次使用前）。
class DatabaseTool {
  static const _dbFileName = 'dart_claw.db';
  static const _dbVersion = 1;

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
        id          TEXT PRIMARY KEY,
        session_id  TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        role        TEXT NOT NULL,
        blocks_json TEXT NOT NULL,
        status      TEXT NOT NULL,
        sort_index  INTEGER NOT NULL,
        created_at  INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_messages_session ON messages(session_id, sort_index)',
    );
  }

  // ─── Session CRUD ─────────────────────────────────────────────────────────

  /// 插入新 session
  Future<void> insertSession(ClawSession session) async {
    await _database.insert(
      'sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 所有 session，按最近更新排序
  Future<List<ClawSession>> listSessions() async {
    final rows = await _database.query(
      'sessions',
      orderBy: 'updated_at DESC',
    );
    return rows.map(ClawSession.fromMap).toList();
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
    return ClawChatMessage.fromJson({
      'id': row['id'],
      'role': row['role'],
      'timestamp': row['created_at'],
      'status': row['status'],
      'blocks': blocksJson,
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
}
