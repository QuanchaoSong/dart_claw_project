import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  HttpServer? _server;
  final _clients = <WebSocket>{};

  /// 当前已连接的移动端数量（可响应式绑定到 UI）。
  final connectedCount = 0.obs;

  Timer? _pingTimer;

  // ── 生命周期 ──────────────────────────────────────────────────────────────

  Future<void> start({int port = defaultPort}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handleRequest);
    _startPingTimer();
    print('[RemoteService] Listening on ws://0.0.0.0:$port');
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
  }

  // ── 连接处理 ──────────────────────────────────────────────────────────────

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    final ws = await WebSocketTransformer.upgrade(request);
    _addClient(ws);
  }

  void _addClient(WebSocket ws) {
    _clients.add(ws);
    connectedCount.value = _clients.length;
    print('[RemoteService] Client connected (total: ${_clients.length})');
    // 立即发一个 ping，确认链路畅通
    _send(ws, {'type': 'ping'});
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
        if (content.isNotEmpty) {
          Get.find<HomeLogic>().sendMessage(content, isRemote: true);
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
