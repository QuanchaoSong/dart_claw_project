import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_claw/others/services/app_config_service.dart';
import 'package:dart_claw/others/server/remote_http_handler.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:get/get.dart';

/// 单例：桌面端本地服务器（WebSocket + HTTP）。
/// 访问方式：LocalServer().xxx
class LocalServer {
  static final LocalServer _instance = LocalServer._();
  LocalServer._();
  factory LocalServer() => _instance;

  static const int defaultPort = 37788;
  static const Duration _pingInterval = Duration(seconds: 15);

  HttpServer? _server;
  final _clients = <WebSocket>{};
  String? _localIp;

  /// 当前已连接的移动端数量
  final connectedCount = 0.obs;
  /// 服务器是否正在运行
  final isRunning = false.obs;
  /// 当前监听的端口号
  final activePort = LocalServer.defaultPort.obs;
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
      print('[LocalServer] Listening on ws://0.0.0.0:$p (LAN IP: $_localIp)');
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
    switch (request.uri.path) {
      case '/image':
        return RemoteHttpHandler.serveImage(request);
      case '/video':
        return RemoteHttpHandler.serveVideo(request);
      case '/skills':
        return RemoteHttpHandler.serveSkills(request);
      case '/config':
        if (request.method == 'POST') {
          return RemoteHttpHandler.handleConfigUpdate(request);
        }
        return RemoteHttpHandler.serveConfig(request);
      case '/scheduler':
        return RemoteHttpHandler.serveScheduler(request);
      case '/file':
        return RemoteHttpHandler.serveFile(request);
      case '/upload':
        return RemoteHttpHandler.handleUpload(request);
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
    print('[LocalServer] Client connected (total: ${_clients.length})');
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
      print('[LocalServer] Client disconnected (total: ${_clients.length})');
    }
  }

  // ── 消息路由 ──────────────────────────────────────────────────────────────

  void _handleMessage(WebSocket ws, String raw) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      print('[LocalServer] Invalid JSON: $e');
      return;
    }

    switch (msg['type'] as String?) {
      case 'pong':
        print('[LocalServer] ♡ pong');
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
        print('[LocalServer] Unknown message type: ${msg['type']}');
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
