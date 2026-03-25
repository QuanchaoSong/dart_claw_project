import 'dart:async';
import 'dart:io';
import 'dart:math';

/// 临时文件存储，支持 TTL 自动清理。
///
/// 文件保存在 [baseDir]（默认系统临时目录下的 `dart_claw_relay_files/`），
/// 每个文件以随机 ID 命名，附带元数据追踪上传时间和来源房间。
///
/// 访问方式：FileStore().xxx
class FileStore {
  static final FileStore _instance = FileStore._();
  FileStore._();
  factory FileStore() => _instance;

  late final String baseDir;
  Duration ttl = const Duration(minutes: 30);
  final _meta = <String, FileMeta>{};
  static final _rand = Random.secure();
  Timer? _purgeTimer;

  /// 初始化存储目录 + 启动定时清理。
  Future<void> init({String? baseDir, Duration? ttl}) async {
    this.baseDir = baseDir ?? _defaultBaseDir();
    if (ttl != null) this.ttl = ttl;
    await Directory(this.baseDir).create(recursive: true);
    
    _startTimer();
  }

  void _startTimer() {
    _killTimer();
    _purgeTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _purgeExpired(),
    );
  }

  void _killTimer() {
    _purgeTimer?.cancel();
    _purgeTimer = null;
  }

  /// 停止定时清理。
  void dispose() {
    _killTimer();
  }

  /// 存储文件，返回 fileId。
  Future<String> save({
    required String roomId,
    required String fileName,
    required Stream<List<int>> dataStream,
  }) async {
    final id = _generateId();
    final file = File('$baseDir/$id');
    final sink = file.openWrite();
    await sink.addStream(dataStream);
    await sink.close();

    final size = await file.length();
    _meta[id] = FileMeta(
      id: id,
      roomId: roomId,
      fileName: fileName,
      size: size,
      createdAt: DateTime.now(),
    );
    _log('saved  id=$id  room=$roomId  name=$fileName  size=$size');
    return id;
  }

  /// 查询文件元数据。若已过期或不存在返回 null。
  FileMeta? getMeta(String id) {
    final m = _meta[id];
    if (m == null) return null;
    if (DateTime.now().difference(m.createdAt) > ttl) {
      _delete(id);
      return null;
    }
    return m;
  }

  /// 获取文件对象（不检查过期，调用方应先 getMeta）。
  File getFile(String id) => File('$baseDir/$id');

  /// 清理过期文件。
  void _purgeExpired() {
    final now = DateTime.now();
    final expired = _meta.entries
        .where((e) => now.difference(e.value.createdAt) > ttl)
        .map((e) => e.key)
        .toList();
    for (final id in expired) {
      _delete(id);
    }
    if (expired.isNotEmpty) {
      _log('purged ${expired.length} expired file(s)');
    }
  }

  void _delete(String id) {
    _meta.remove(id);
    try {
      File('$baseDir/$id').deleteSync();
    } catch (_) {}
  }

  static String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(16, (_) => chars[_rand.nextInt(chars.length)]).join();
  }

  static String _defaultBaseDir() =>
      '${Directory.systemTemp.path}/dart_claw_relay_files';

  static void _log(String msg) {
    final ts = DateTime.now().toIso8601String();
    print('[$ts][FileStore] $msg');
  }
}

class FileMeta {
  final String id;
  final String roomId;
  final String fileName;
  final int size;
  final DateTime createdAt;

  FileMeta({
    required this.id,
    required this.roomId,
    required this.fileName,
    required this.size,
    required this.createdAt,
  });
}
