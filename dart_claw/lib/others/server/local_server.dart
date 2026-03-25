import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_claw/others/model/server_settings_info.dart';
import 'package:dart_claw/others/services/app_config_service.dart';
import 'package:dart_claw/others/server/remote_http_handler.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

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

  // ── Relay 模式 ──────────────────────────────────────────────────────────
  WebSocket? _relaySocket;
  Timer? _relayReconnectTimer;

  /// 当前已连接的移动端数量
  final connectedCount = 0.obs;

  /// 服务器是否正在运行
  final isRunning = false.obs;

  /// 当前监听的端口号
  final activePort = LocalServer.defaultPort.obs;

  /// 桌面端的局域网 IP（供二维码使用）
  final localIpAddress = ''.obs;

  /// 连接模式：'direct'（同一 WiFi 直连）| 'relay'（中继）
  final connectionMode = 'direct'.obs;

  /// Relay 连接是否已建立
  final relayConnected = false.obs;

  /// 启动失败时的错误描述
  final startError = Rxn<String>();

  Timer? _pingTimer;

  Future<void> setConnectionMode(String mode) async {
    connectionMode.value = mode;
    await AppConfigService.shared.saveServerSettings(
      AppConfigService.shared.config.value.server.copyWith(
        connectionMode: mode,
      ),
    );
    // 切换模式后重启服务器（如果当前正在运行）
    if (isRunning.value) {
      await stop();
      await start();
    }
  }

  // ── 生命周期 ──────────────────────────────────────────────────────────────

  Future<void> start({int? port}) async {
    startError.value = null;
    final cfg = AppConfigService.shared.config.value.server;
    connectionMode.value = cfg.connectionMode;

    if (cfg.connectionMode == 'relay') {
      await _startRelay(cfg);
    } else {
      await _startDirect(cfg, port);
    }
  }

  Future<void> _startDirect(ServerSettingsInfo cfg, int? port) async {
    try {
      final p = port ?? cfg.port;
      _server = await HttpServer.bind(InternetAddress.anyIPv4, p);
      activePort.value = p;
      _localIp = await _resolveLocalIp();
      localIpAddress.value = _localIp ?? '0.0.0.0';
      _server!.listen(_handleRequest);
      _startPingTimer();
      isRunning.value = true;
      print('[LocalServer] Listening on ws://0.0.0.0:$p (LAN IP: $_localIp)');
    } catch (e) {
      isRunning.value = false;
      startError.value = '服务器启动失败：$e';
    }
  }

  Future<void> _startRelay(ServerSettingsInfo cfg) async {
    if (cfg.relayHost.isEmpty) {
      startError.value = '中继模式需要配置 relay 服务器地址';
      return;
    }
    try {
      await _connectRelay(cfg);
      _startPingTimer();
      isRunning.value = true;
      print(
        '[LocalServer] Relay mode: connected to ${cfg.relayHost}:${cfg.relayPort}',
      );
    } catch (e) {
      isRunning.value = false;
      startError.value = '中继连接失败：$e';
    }
  }

  Future<void> _connectRelay(ServerSettingsInfo cfg) async {
    _relaySocket?.close();
    final room = Uri.encodeComponent(cfg.securityCode);
    final uri =
        'ws://${cfg.relayHost}:${cfg.relayPort}/ws?role=host&room=$room';
    _relaySocket = await WebSocket.connect(
      uri,
    ).timeout(const Duration(seconds: 10));
    relayConnected.value = true;
    // 向首次连接的 guest 推送初始状态（relay 会透传）
    _relaySend(_buildSettingsState());
    _relaySend(_buildSessionStats());
    _relaySocket!.listen(
      (data) => _handleMessage(null, data as String),
      onDone: () {
        relayConnected.value = false;
        print('[LocalServer] Relay disconnected, scheduling reconnect...');
        _scheduleRelayReconnect();
      },
      onError: (_) {
        relayConnected.value = false;
        _scheduleRelayReconnect();
      },
      cancelOnError: true,
    );
  }

  void _scheduleRelayReconnect() {
    _relayReconnectTimer?.cancel();
    _relayReconnectTimer = Timer(const Duration(seconds: 5), () async {
      if (connectionMode.value != 'relay' || !isRunning.value) return;
      try {
        final cfg = AppConfigService.shared.config.value.server;
        await _connectRelay(cfg);
        print('[LocalServer] Relay reconnected');
      } catch (e) {
        print('[LocalServer] Relay reconnect failed: $e');
        _scheduleRelayReconnect();
      }
    });
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
    return '0.0.0.0';
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

  // ── Relay 文件上传 ────────────────────────────────────────────────────────

  bool get isRelayMode => connectionMode.value == 'relay';

  String get _relayBaseUrl {
    final cfg = AppConfigService.shared.config.value.server;
    return 'http://${cfg.relayHost}:${cfg.relayPort}';
  }

  /// 将本地文件上传到 relay 服务器，返回可供手机端访问的完整 URL。
  /// 仅在 relay 模式下调用。
  Future<String> uploadFileToRelay(String localPath, String fileName) async {
    final cfg = AppConfigService.shared.config.value.server;
    final room = Uri.encodeComponent(cfg.securityCode);
    final name = Uri.encodeComponent(fileName);
    final url = Uri.parse('$_relayBaseUrl/files?room=$room&name=$name');

    final expandedPath = localPath.startsWith('~/')
        ? (Platform.environment['HOME'] ?? '') + localPath.substring(1)
        : localPath;
    final fileBytes = await File(expandedPath).readAsBytes();

    final response = await http.post(url, body: fileBytes);
    if (response.statusCode != 200) {
      throw Exception('Relay file upload failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final relayUrl = json['url'] as String; // e.g. "/files/abc123"
    return '$_relayBaseUrl$relayUrl';
  }

  Future<void> stop() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _relayReconnectTimer?.cancel();
    _relayReconnectTimer = null;
    // Direct 模式：关闭所有客户端
    for (final ws in List.of(_clients)) {
      await ws.close();
    }
    _clients.clear();
    connectedCount.value = 0;
    await _server?.close(force: true);
    _server = null;
    // Relay 模式：断开中继连接
    _relaySocket?.close();
    _relaySocket = null;
    relayConnected.value = false;
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

  /// [ws] 在 direct 模式下为客户端 WebSocket；relay 模式下为 null。
  void _handleMessage(WebSocket? ws, String raw) {
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
          Get.find<HomeLogic>().sendMessage(
            content,
            isRemote: true,
            sessionId: sessionId,
          );
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
        if (key.isNotEmpty)
          Get.find<HomeLogic>().applyRemoteSetting(key, value);
        break;
      case 'set_skill':
        final name = msg['name'] as String?;
        Get.find<HomeLogic>().setPendingSkill(
          name?.isEmpty == true ? null : name,
        );
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
      case 'relay_file_uploaded':
        _handleRelayFileUploaded(msg);
        break;
      default:
        print('[LocalServer] Unknown message type: ${msg['type']}');
    }
  }

  /// 移动端通过中继上传文件后发此消息，桌面端从中继下载到本地。
  Future<void> _handleRelayFileUploaded(Map<String, dynamic> msg) async {
    final url = msg['url'] as String? ?? '';
    final name = msg['name'] as String? ?? 'file';
    final requestId = msg['request_id'] as String?;
    if (url.isEmpty) return;

    final safeName = name.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final rawDir = AppConfigService.shared.config.value.server.uploadSaveDir;
    final saveDir = rawDir.startsWith('~/')
        ? (Platform.environment['HOME'] ?? '') + rawDir.substring(1)
        : rawDir;
    await Directory(saveDir).create(recursive: true);
    final dest = File('$saveDir/$safeName');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await dest.writeAsBytes(response.bodyBytes);
        final homeLogic = Get.find<HomeLogic>();
        if (requestId != null && requestId.isNotEmpty) {
          homeLogic.onFileRequestFulfilled(requestId, dest.path);
        }
        homeLogic.onFileReceived(safeName, dest.path);
        print('[LocalServer] Relay file saved: ${dest.path}');
      } else {
        print(
          '[LocalServer] Failed to download relay file: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('[LocalServer] Relay file download error: $e');
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
    if (connectionMode.value == 'relay') {
      _relaySend(msg);
      return;
    }
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

  void _relaySend(Map<String, dynamic> msg) {
    final ws = _relaySocket;
    if (ws == null) return;
    try {
      ws.add(jsonEncode(msg));
    } catch (_) {
      // relay 断连由 onDone/onError 处理
    }
  }
}
