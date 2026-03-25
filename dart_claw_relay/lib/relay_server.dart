import 'dart:convert';
import 'dart:io';
import 'file_store.dart';
import 'room_manager.dart';

/// HTTP + WebSocket 中继服务器。
///
/// 端点：
///   GET  /health                       — 健康检查，返回 200 "ok"
///   GET  /stats                        — 返回当前房间数（JSON）
///   POST /files?room=`<id>`&name=`<n>` — 上传文件到临时存储，返回 fileId
///   GET  /files/`<fileId>`             — 下载文件（支持 Range 请求）
///   WS   /ws?role=host&room=`<id>`     — 桌面端注册
///   WS   /ws?role=guest&room=`<id>`    — 移动端接入
class RelayServer {
  final _roomManager = RoomManager();
  HttpServer? _server;

  Future<void> start({int port = 37789}) async {
    await FileStore().init();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _log('Listening on ws://0.0.0.0:$port');
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    FileStore().dispose();
    await _server?.close(force: true);
    _server = null;
  }

  // ── 请求分发 ────────────────────────────────────────────────────────────

  Future<void> _handleRequest(HttpRequest req) async {
    final path = req.uri.path;

    // ── /health ─────────────────────────────────────────────────────────
    if (req.method == 'GET' && path == '/health') {
      _respond(req, 200, 'ok', contentType: 'text/plain');
      return;
    }

    // ── /stats ──────────────────────────────────────────────────────────
    if (req.method == 'GET' && path == '/stats') {
      _respond(
        req,
        200,
        '{"rooms":${_roomManager.roomCount}}',
        contentType: 'application/json',
      );
      return;
    }

    // ── /ws ─────────────────────────────────────────────────────────────
    if (path == '/ws' && WebSocketTransformer.isUpgradeRequest(req)) {
      await _handleWebSocket(req);
      return;
    }

    // ── POST /files — 上传文件 ─────────────────────────────────────────
    if (req.method == 'POST' && path == '/files') {
      await _handleFileUpload(req);
      return;
    }

    // ── GET /files/<id> — 下载文件 ─────────────────────────────────────
    if (req.method == 'GET' && path.startsWith('/files/')) {
      await _handleFileDownload(req);
      return;
    }

    _respond(req, 404, 'Not found', contentType: 'text/plain');
  }

  Future<void> _handleWebSocket(HttpRequest req) async {
    final params = req.uri.queryParameters;
    final role = params['role'];
    final roomId = params['room'];

    if ((role != 'host' && role != 'guest') ||
        roomId == null ||
        roomId.isEmpty) {
      _respond(
        req,
        400,
        'Missing or invalid query params. Required: role=(host|guest)&room=<id>',
        contentType: 'text/plain',
      );
      return;
    }

    final ws = await WebSocketTransformer.upgrade(req);

    if (role == 'host') {
      _roomManager.onHostConnect(roomId, ws);
    } else {
      _roomManager.onGuestConnect(roomId, ws);
    }
  }

  // ── 文件上传 ─────────────────────────────────────────────────────────────

  /// POST /files?room=xxx&name=myfile.jpg
  /// Body: 原始文件字节流。
  /// 返回 JSON: {"id":"abc123","url":"/files/abc123"}
  Future<void> _handleFileUpload(HttpRequest req) async {
    final params = req.uri.queryParameters;
    final roomId = params['room'];
    final name = params['name'];

    if (roomId == null || roomId.isEmpty || name == null || name.isEmpty) {
      _respond(
        req,
        400,
        'Missing query params. Required: room=<id>&name=<filename>',
        contentType: 'text/plain',
      );
      return;
    }

    try {
      final fileId = await FileStore().save(
        roomId: roomId,
        fileName: name,
        dataStream: req,
      );
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'id': fileId, 'url': '/files/$fileId'}));
      await req.response.close();
    } catch (e) {
      _respond(req, 500, 'Upload failed: $e', contentType: 'text/plain');
    }
  }

  // ── 文件下载 ─────────────────────────────────────────────────────────────

  /// GET /files/`<fileId>`
  /// 支持 Range 请求（视频流式播放需要）。
  Future<void> _handleFileDownload(HttpRequest req) async {
    // 从路径提取 fileId: "/files/abc123" → "abc123"
    final segments = req.uri.pathSegments;
    if (segments.length != 2) {
      _respond(req, 400, 'Invalid path', contentType: 'text/plain');
      return;
    }
    final fileId = segments[1];

    final meta = FileStore().getMeta(fileId);
    if (meta == null) {
      _respond(req, 404, 'File not found or expired', contentType: 'text/plain');
      return;
    }

    final file = FileStore().getFile(fileId);
    if (!await file.exists()) {
      _respond(req, 404, 'File missing from disk', contentType: 'text/plain');
      return;
    }

    final mime = _guessMime(meta.fileName);
    final fileSize = meta.size;

    req.response.headers
      ..set('Content-Type', mime)
      ..set('Accept-Ranges', 'bytes')
      ..set('Access-Control-Allow-Origin', '*')
      ..set(
        'Content-Disposition',
        'inline; filename="${Uri.encodeComponent(meta.fileName)}"',
      );

    final rangeHeader = req.headers.value('range');
    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      // Range 请求 —— 视频流式播放
      final rangePart = rangeHeader.substring(6);
      final parts = rangePart.split('-');
      final start = int.tryParse(parts[0]) ?? 0;
      final end = (parts.length > 1 && parts[1].isNotEmpty)
          ? int.tryParse(parts[1]) ?? (fileSize - 1)
          : fileSize - 1;
      final length = end - start + 1;

      req.response
        ..statusCode = HttpStatus.partialContent
        ..headers.set('Content-Range', 'bytes $start-$end/$fileSize')
        ..headers.set('Content-Length', length.toString());
      await req.response.addStream(
        file.openRead(start, end + 1),
      );
    } else {
      req.response
        ..statusCode = 200
        ..headers.set('Content-Length', fileSize.toString());
      await req.response.addStream(file.openRead());
    }
    await req.response.close();
  }

  static String _guessMime(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      'm4v' => 'video/x-m4v',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'json' => 'application/json',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }

  // ── 工具 ─────────────────────────────────────────────────────────────────

  static void _respond(
    HttpRequest req,
    int status,
    String body, {
    required String contentType,
  }) {
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.parse(contentType)
      ..write(body);
    req.response.close();
  }

  static void _log(String msg) {
    final ts = DateTime.now().toIso8601String();
    print('[$ts][RelayServer] $msg');
  }
}
