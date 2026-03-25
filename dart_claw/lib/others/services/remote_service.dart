import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_claw/others/services/app_config_service.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:get/get.dart';

/// 单例：桌面端 WebSocket 服务，监听移动端连接。
/// 访问方式：RemoteService().xxx
class RemoteService {
  static final RemoteService _instance = RemoteService._();
  RemoteService._();
  factory RemoteService() => _instance;

  static const int defaultPort = 37788;
  static const Duration _pingInterval = Duration(seconds: 15);

  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
  static const _videoExtensions = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'};

  HttpServer? _server;
  final _clients = <WebSocket>{};
  String? _localIp;

  /// 当前已连接的移动端数量
  final connectedCount = 0.obs;
  /// 服务器是否正在运行
  final isRunning = false.obs;
  /// 当前监听的端口号
  final activePort = RemoteService.defaultPort.obs;
  /// 桌面端的局域网 IP（供二维码使用）
  final localIpAddress = ''.obs;
  /// 连接模式：'direct'（同一 WiFi 直连）| 'relay'（中继，暂未实现）
  final connectionMode = 'direct'.obs;
  /// 启动失败时的错误描述
  final startError = Rxn<String>();

  Timer? _pingTimer;

  void setConnectionMode(String mode) {
    connectionMode.value = mode;
    AppConfigService.shared.saveServerSettings(
      AppConfigService.shared.config.value.server.copyWith(connectionMode: mode),
    );
  }

  // ── 生命周期 ──────────────────────────────────────────────────────────────

  Future<void> start({int? port}) async {
    startError.value = null;
    try {
      final cfg = AppConfigService.shared.config.value.server;
      final p = port ?? cfg.port;
      connectionMode.value = cfg.connectionMode;
      _server = await HttpServer.bind(InternetAddress.anyIPv4, p);
      activePort.value = p;
      _localIp = await _resolveLocalIp();
      localIpAddress.value = _localIp ?? '127.0.0.1';
      _server!.listen(_handleRequest);
      _startPingTimer();
      isRunning.value = true;
      print('[RemoteService] Listening on ws://0.0.0.0:$p (LAN IP: $_localIp)');
    } catch (e) {
      isRunning.value = false;
      startError.value = '服务器启动失败：$e';
      rethrow;
    }
  }

  /// 切换端口（先停止再重启）。
  Future<void> restart(int port) async {
    await stop();
    await AppConfigService.shared.saveServerSettings(
      AppConfigService.shared.config.value.server.copyWith(port: port),
    );
    await start(port: port);
  }

  Future<String> _resolveLocalIp() async {
    for (final iface in await NetworkInterface.list()) {
      for (final addr in iface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return '127.0.0.1';
  }

  /// 将桌面本地图片路径转为手机可访问的 HTTP URL。
  /// 网络 URL 原样返回。
  String imageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return 'http://${localIpAddress.value}:${activePort.value}/image?path=${Uri.encodeComponent(path)}';
  }

  /// 将桌面本地视频路径转为手机可访问的 HTTP URL。
  /// 网络 URL 原样返回。
  String videoUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return 'http://${localIpAddress.value}:${activePort.value}/video?path=${Uri.encodeComponent(path)}';
  }

  /// 将桌面本地文件路径转为手机可下载的 HTTP URL。
  String fileUrl(String path) {
    return 'http://${localIpAddress.value}:${activePort.value}/file?path=${Uri.encodeComponent(path)}';
  }

  Future<void> stop() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    for (final ws in List.of(_clients)) {
      await ws.close();
    }
    _clients.clear();
    connectedCount.value = 0;
    await _server?.close(force: true);
    _server = null;
    isRunning.value = false;
  }

  // ── 连接处理 ──────────────────────────────────────────────────────────────

  Future<void> _handleRequest(HttpRequest request) async {
    // ── 图片服务 (/image?path=...) ─────────────────────────────────────────
    if (request.uri.path == '/image') {
      await _serveImage(request);
      return;
    }
    // ── 视频服务 (/video?path=...) ─────────────────────────────────────────
    if (request.uri.path == '/video') {
      await _serveVideo(request);
      return;
    }
    // ── Skill 列表 (/skills) ──────────────────────────────────────────────
    if (request.uri.path == '/skills') {
      await _serveSkills(request);
      return;
    }    // ── 文件下载 (/file?path=...) ────────────────────────────────────────────
    if (request.uri.path == '/file') {
      await _serveFile(request);
      return;
    }
    // ── 手机→桌面文件上传 (POST /upload?name=...) ─────────────────────────────
    if (request.uri.path == '/upload') {
      await _handleUpload(request);
      return;
    }
    // ── WebSocket 升级 ────────────────────────────────────────────────────
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    // 验证安全码
    final expectedCode =
        AppConfigService.shared.config.value.server.securityCode;
    final clientCode = request.uri.queryParameters['code'];
    if (clientCode != expectedCode) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('Invalid security code')
        ..close();
      return;
    }
    final ws = await WebSocketTransformer.upgrade(request);
    _addClient(ws);
  }

  Future<void> _serveImage(HttpRequest request) async {
    final rawPath = request.uri.queryParameters['path'] ?? '';
    if (rawPath.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    // 仅允许图片扩展名，防止任意文件读取
    final ext = rawPath.split('.').last.toLowerCase();
    if (!_imageExtensions.contains(ext)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..close();
      return;
    }
    // Expand leading ~ — Dart's File does not do shell tilde expansion.
    final path = rawPath.startsWith('~/')
        ? (Platform.environment['HOME'] ?? '') + rawPath.substring(1)
        : rawPath;
    final file = File(path);
    if (!await file.exists()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => 'application/octet-stream',
    };
    final bytes = await file.readAsBytes();
    request.response
      ..headers.set('Content-Type', mime)
      ..headers.set('Access-Control-Allow-Origin', '*')
      ..add(bytes);
    await request.response.close();
  }

  Future<void> _serveVideo(HttpRequest request) async {
    final rawPath = request.uri.queryParameters['path'] ?? '';
    if (rawPath.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    final ext = rawPath.split('.').last.toLowerCase();
    if (!_videoExtensions.contains(ext)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..close();
      return;
    }
    // Expand leading ~ — Dart's File does not do shell tilde expansion.
    final path = rawPath.startsWith('~/')
        ? (Platform.environment['HOME'] ?? '') + rawPath.substring(1)
        : rawPath;
    final file = File(path);
    if (!await file.exists()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }
    final mime = switch (ext) {
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      'm4v' => 'video/x-m4v',
      _ => 'application/octet-stream',
    };

    final fileSize = await file.length();
    final rangeHeader = request.headers.value('range');

    request.response.headers
      ..set('Content-Type', mime)
      ..set('Accept-Ranges', 'bytes')
      ..set('Access-Control-Allow-Origin', '*');

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      // ── 分段响应（HTTP 206 Partial Content）────────────────────────────
      final rangePart = rangeHeader.substring(6); // strip "bytes="
      final parts = rangePart.split('-');
      final start = int.tryParse(parts[0]) ?? 0;
      final end = (parts.length > 1 && parts[1].isNotEmpty)
          ? int.tryParse(parts[1]) ?? (fileSize - 1)
          : fileSize - 1;
      final length = end - start + 1;

      request.response
        ..statusCode = HttpStatus.partialContent
        ..headers.set('Content-Range', 'bytes $start-$end/$fileSize')
        ..headers.set('Content-Length', length.toString())
        ..add(await _readFileRange(file, start, length));
    } else {
      // ── 完整响应（HTTP 200）─────────────────────────────────────────────
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set('Content-Length', fileSize.toString())
        ..add(await file.readAsBytes());
    }

    await request.response.close();
  }

  Future<Uint8List> _readFileRange(File file, int start, int length) async {
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      return await raf.read(length);
    } finally {
      await raf.close();
    }
  }

  // ── Skill 列表服务（GET /skills）─────────────────────────────────────────

  Future<void> _serveSkills(HttpRequest request) async {
    try {
      final skills = await Get.find<HomeLogic>().loadAvailableSkills();
      final json = jsonEncode(
        skills.map((s) => {'name': s.name, 'description': s.description}).toList(),
      );
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set('Content-Type', 'application/json; charset=utf-8')
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..write(json);
    } catch (_) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set('Content-Type', 'application/json')
        ..write('[]');
    }
    await request.response.close();
  }

  // ── 文件下载服务（GET /file?path=...）──────────────────────────────────────────

  Future<void> _serveFile(HttpRequest request) async {
    final rawPath = request.uri.queryParameters['path'] ?? '';
    if (rawPath.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    final path = rawPath.startsWith('~/')
        ? (Platform.environment['HOME'] ?? '') + rawPath.substring(1)
        : rawPath;
    final file = File(path);
    if (!await file.exists()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }
    final name = file.uri.pathSegments.last;
    final fileSize = await file.length();
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final mime = switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'txt' => 'text/plain',
      'json' => 'application/json',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
    // 流式传输——不把大文件读入内存
    request.response.headers
      ..set('Content-Type', mime)
      ..set('Content-Disposition', 'attachment; filename="$name"')
      ..set('Content-Length', fileSize.toString())
      ..set('Access-Control-Allow-Origin', '*');
    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  // ── 手机→桌面文件上传 (POST /upload?name=...) ────────────────────────────

  Future<void> _handleUpload(HttpRequest request) async {
    if (request.method.toUpperCase() != 'POST') {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..close();
      return;
    }
    // 从 query param 取文件名，做安全校验防止路径穿越攻击
    final rawName = request.uri.queryParameters['name'] ?? '';
    if (rawName.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    // 仅保留安全字符：字母、数字、下划线、连字符、点
    final safeName = rawName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    if (safeName.contains('..') || safeName.startsWith('.')) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }

    // 提取可选的 request_id（AI 主动请求文件时由移动端附带）
    final requestId = request.uri.queryParameters['request_id'] ?? '';

    final rawDir = AppConfigService.shared.config.value.server.uploadSaveDir;
    final saveDir = rawDir.startsWith('~/')
        ? (Platform.environment['HOME'] ?? '') + rawDir.substring(1)
        : rawDir;
    await Directory(saveDir).create(recursive: true);

    // 流式写入，不占内存
    final dest = File('$saveDir/$safeName');
    final sink = dest.openWrite();
    await sink.addStream(request);
    await sink.close();

    final savedPath = dest.path;

    // 通知桌面端
    final homeLogic = Get.find<HomeLogic>();
    if (requestId.isNotEmpty) {
      // AI 发起的请求：完成 Completer（工具返回路径）
      homeLogic.onFileRequestFulfilled(requestId, savedPath);
    }
    homeLogic.onFileReceived(safeName, savedPath);

    // 响应移动端
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set('Content-Type', 'application/json; charset=utf-8')
      ..headers.set('Access-Control-Allow-Origin', '*')
      ..write(jsonEncode({'ok': true, 'path': savedPath, 'name': safeName}));
    await request.response.close();
  }

  // ── 初始设置状态快照（推送给新连接的移动端）────────────────────────────────

  Map<String, dynamic> _buildSettingsState() {
    try {
      final h = Get.find<HomeLogic>();
      return {
        'type': 'settings_state',
        'allow_all_tools': h.allowAllTools.value,
        'allow_tool_deviation': h.allowToolDeviation.value,
        'auto_fill_sudo': h.autoFillSudoPassword.value,
        'pending_skill': h.pendingSkillName.value,
      };
    } catch (_) {
      return {'type': 'settings_state'};
    }
  }

  Map<String, dynamic> _buildSessionStats() {
    try {
      final h = Get.find<HomeLogic>();
      return {
        'type': 'session_stats',
        'total_tokens': h.sessionTotalTokens.value,
        'model_id': h.currentModelId,
      };
    } catch (_) {
      return {'type': 'session_stats'};
    }
  }

  void _addClient(WebSocket ws) {
    _clients.add(ws);
    connectedCount.value = _clients.length;
    print('[RemoteService] Client connected (total: ${_clients.length})');
    // 立即发一个 ping，确认链路畅通
    _send(ws, {'type': 'ping'});
    // 推送当前设置状态
    _send(ws, _buildSettingsState());
    // 推送当前模型和 token 统计
    _send(ws, _buildSessionStats());
    ws.listen(
      (data) => _handleMessage(ws, data as String),
      onDone: () => _removeClient(ws),
      onError: (_) => _removeClient(ws),
      cancelOnError: true,
    );
  }

  void _removeClient(WebSocket ws) {
    if (_clients.remove(ws)) {
      connectedCount.value = _clients.length;
      print('[RemoteService] Client disconnected (total: ${_clients.length})');
    }
  }

  // ── 消息路由 ──────────────────────────────────────────────────────────────

  void _handleMessage(WebSocket ws, String raw) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      print('[RemoteService] Invalid JSON: $e');
      return;
    }

    switch (msg['type'] as String?) {
      case 'pong':
        print('[RemoteService] ♡ pong');
        break;
      case 'task':
        final content = msg['content'] as String? ?? '';
        final sessionId = msg['session_id'] as String?;
        if (content.isNotEmpty) {
          Get.find<HomeLogic>()
              .sendMessage(content, isRemote: true, sessionId: sessionId);
        }
        break;
      case 'confirm':
        final id = msg['id'] as String? ?? '';
        final approved = msg['approved'] as bool? ?? false;
        if (id.isNotEmpty) {
          Get.find<HomeLogic>().confirmTool(id, allow: approved);
        }
        break;
      case 'input':
        final id = msg['id'] as String? ?? '';
        final value = msg['value'] as String? ?? '';
        if (id.isNotEmpty) {
          Get.find<HomeLogic>().respondUserInput(id, value);
        }
        break;
      case 'stop':
        Get.find<HomeLogic>().stopAgent();
        break;
      case 'set_setting':
        final key = msg['key'] as String? ?? '';
        final value = msg['value'];
        if (key.isNotEmpty) Get.find<HomeLogic>().applyRemoteSetting(key, value);
        break;
      case 'set_skill':
        final name = msg['name'] as String?;
        Get.find<HomeLogic>().setPendingSkill(name?.isEmpty == true ? null : name);
        break;
      case 'sudo_input':
        final id = msg['id'] as String? ?? '';
        final password = msg['password'] as String?;
        if (id.isNotEmpty) {
          Get.find<HomeLogic>().respondSudoPassword(id, password);
        }
        break;
      case 'set_sudo_password':
        final pwd = msg['password'] as String? ?? '';
        Get.find<HomeLogic>().setSudoPassword(pwd);
        break;
      default:
        print('[RemoteService] Unknown message type: ${msg['type']}');
    }
  }

  // ── 心跳 ──────────────────────────────────────────────────────────────────

  void _startPingTimer() {
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      broadcast({'type': 'ping'});
    });
  }

  // ── 发送 ──────────────────────────────────────────────────────────────────

  void _send(WebSocket ws, Map<String, dynamic> msg) {
    try {
      ws.add(jsonEncode(msg));
    } catch (_) {
      _removeClient(ws);
    }
  }

  /// 向所有已连接的移动端广播一条消息。
  void broadcast(Map<String, dynamic> msg) {
    if (_clients.isEmpty) return;
    final raw = jsonEncode(msg);
    for (final ws in List.of(_clients)) {
      try {
        ws.add(raw);
      } catch (_) {
        _removeClient(ws);
      }
    }
  }
}
