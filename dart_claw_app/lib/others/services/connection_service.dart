import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'push_notification_service.dart';

/// 单例：管理与桌面端（dart_claw）的 WebSocket 连接状态。
/// 访问方式：ConnectionService().xxx
class ConnectionService with WidgetsBindingObserver {
  static final ConnectionService _instance = ConnectionService._();
  ConnectionService._() {
    WidgetsBinding.instance.addObserver(this);
  }
  factory ConnectionService() => _instance;

  final isConnected = false.obs;
  final serverHost = ''.obs;
  final serverPort = 37788.obs;

  /// 是否通过中继服务器连接（而非同一 WiFi 直连）。
  final isRelayMode = false.obs;

  /// 中继服务器地址（relay 模式有效）。
  final relayHost = ''.obs;

  /// 中继服务器端口（relay 模式有效）。
  final relayPort = 37789.obs;

  /// 中继房间 ID（= 桌面端 security code），relay 模式有效。
  String relayRoom = '';

  /// 中继模式下的 HTTP 基地址，用于文件上传等。
  String get relayBaseUrl => 'http://${relayHost.value}:${relayPort.value}';

  WebSocket? _socket;
  var _appInForeground = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground =
        state == AppLifecycleState.resumed;
  }

  final _msgController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 桌面端推送的消息流（ping/pong 心跳不在其中）。
  Stream<Map<String, dynamic>> get incomingMessages => _msgController.stream;

  String get serverUrl => isRelayMode.value
      ? 'relay://${relayHost.value}:${relayPort.value}'
      : 'ws://${serverHost.value}:${serverPort.value}';

  /// 建立 WebSocket 连接，成功返回 true。
  ///
  /// 直连模式：ws://$host:$port?code=xxx
  /// 中继模式：ws://$relayHost:$relayPort/ws?role=guest&room=xxx
  Future<bool> connect({
    required String host,
    required int port,
    String code = '',
    bool relay = false,
    String relayHostAddr = '',
    int relayPortNum = 37789,
  }) async {
    isRelayMode.value = relay;

    if (relay) {
      relayHost.value = relayHostAddr;
      relayPort.value = relayPortNum;
      relayRoom = code;
      // host/port 保持空，relay 模式下不使用直连地址
      serverHost.value = '';
      serverPort.value = 0;
    } else {
      serverHost.value = host;
      serverPort.value = port;
      relayRoom = '';
    }

    try {
      final String wsUrl;
      if (relay) {
        final roomParam = code.isNotEmpty ? Uri.encodeComponent(code) : '';
        wsUrl = 'ws://$relayHostAddr:$relayPortNum/ws?role=guest&room=$roomParam';
      } else {
        final codeParam = code.isNotEmpty ? '?code=${Uri.encodeComponent(code)}' : '';
        wsUrl = 'ws://$host:$port$codeParam';
      }
      _socket = await WebSocket.connect(wsUrl)
          .timeout(const Duration(seconds: 5));
      isConnected.value = true;
      _socket!.listen(
        _handleMessage,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: true,
      );
      return true;
    } catch (e) {
      _socket = null;
      isConnected.value = false;
      return false;
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      if (msg['type'] == 'ping') {
        print('[ConnectionService] ♡ ping → pong');
        _socket?.add(jsonEncode({'type': 'pong'}));
        return; // 心跳不转发给监听者
      }
      _dispatchNotification(msg);
      _msgController.add(msg);
    } catch (_) {}
  }

  /// 根据消息类型决定是否弹推送或播放提示音。
  void _dispatchNotification(Map<String, dynamic> msg) {
    if (_appInForeground) return;
    final type = msg['type'] as String?;
    switch (type) {
      case 'done':
        PushNotificationService().show(
          title: '任务完成',
          body: '您的 AI 任务已执行完毕',
        );
      case 'error':
        PushNotificationService().show(
          title: '任务出错',
          body: msg['message'] as String? ?? '执行过程中遇到错误',
        );
      // 以下场景需要用户交互——后续放入 SoundTool.play('alert.wav')
      // case 'confirm_request':
      // case 'ask_user':
      // case 'sudo_prompt':
      // case 'request_file':
    }
  }

  void _onDisconnected() {
    _socket = null;
    isConnected.value = false;
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
    isConnected.value = false;
  }

  /// 向桌面端发送一条消息。
  void send(Map<String, dynamic> msg) {
    _socket?.add(jsonEncode(msg));
  }
}

