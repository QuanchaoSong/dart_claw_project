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

  String get serverUrl => 'ws://${serverHost.value}:${serverPort.value}';

  /// 建立 WebSocket 连接，成功返回 true。
  Future<bool> connect({
    required String host,
    required int port,
    String code = '',
  }) async {
    serverHost.value = host;
    serverPort.value = port;
    try {
      final codeParam = code.isNotEmpty ? '?code=${Uri.encodeComponent(code)}' : '';
      _socket = await WebSocket.connect('ws://$host:$port$codeParam')
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

