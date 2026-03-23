import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../others/model/remote_message_info.dart';
import '../../others/services/connection_service.dart';

class ChatLogic extends GetxController {
  final inputController = TextEditingController();
  final scrollController = ScrollController();

  final currentSessionTitle = 'New Chat'.obs;
  final isRunning = false.obs;
  final messages = <RemoteMessageInfo>[].obs;

  StreamSubscription<Map<String, dynamic>>? _sub;
  String? _streamingMsgId;

  @override
  void onInit() {
    super.onInit();
    _sub = ConnectionService().incomingMessages.listen(_handleRemoteMessage);
  }

  @override
  void onClose() {
    _sub?.cancel();
    inputController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  // ── WS message handling ────────────────────────────────────────────────────

  void _handleRemoteMessage(Map<String, dynamic> msg) {
    switch (msg['type'] as String?) {
      case 'chunk':
        _onChunk(msg['content'] as String? ?? '');
      case 'reasoning_chunk':
        break; // 移动端不展示推理过程
      case 'tool':
        _onTool(msg);
      case 'confirm_request':
        _onConfirmRequest(msg);
      case 'done':
        _onDone();
      case 'error':
        _onError(msg['message'] as String? ?? '未知错误');
      case 'log':
        break; // 移动端暂不展示日志
    }
    _scrollToBottom();
  }

  void _onChunk(String chunk) {
    if (_streamingMsgId == null) {
      isRunning.value = true;
      final msg = RemoteMessageInfo.assistantStreaming();
      _streamingMsgId = msg.id;
      messages.add(msg);
    }
    final idx = messages.indexWhere((m) => m.id == _streamingMsgId);
    if (idx == -1) return;
    messages[idx].content += chunk;
    messages.refresh();
  }

  void _onTool(Map<String, dynamic> data) {
    final toolId = data['id'] as String? ?? '';
    final name = data['name'] as String? ?? '';
    final status = data['status'] as String? ?? 'running';
    final args = data['args'] as Map<String, dynamic>?;
    // 同一 toolId 重复出现时只更新状态
    if (toolId.isNotEmpty) {
      final idx = messages.lastIndexWhere(
        (m) => m.type == RemoteMessageInfoType.tool && m.toolId == toolId,
      );
      if (idx != -1) {
        messages[idx].toolStatus = status;
        messages.refresh();
        return;
      }
    }
    messages.add(RemoteMessageInfo.tool(
      toolId: toolId,
      toolName: name,
      toolStatus: status,
      args: args,
    ));
  }

  void _onConfirmRequest(Map<String, dynamic> data) {
    final id = data['id'] as String? ?? '';
    final message = data['message'] as String? ?? '';
    messages.add(RemoteMessageInfo.confirm(confirmId: id, message: message));
  }

  void _onDone() {
    _finalizeStreaming();
    isRunning.value = false;
  }

  void _onError(String text) {
    _finalizeStreaming();
    messages.add(RemoteMessageInfo.log('⚠ $text'));
    isRunning.value = false;
  }

  void _finalizeStreaming() {
    if (_streamingMsgId == null) return;
    final idx = messages.indexWhere((m) => m.id == _streamingMsgId);
    if (idx != -1) {
      messages[idx].isStreaming = false;
      messages.refresh();
    }
    _streamingMsgId = null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  void submitInput() {
    final text = inputController.text.trim();
    if (text.isEmpty || isRunning.value) return;
    inputController.clear();
    messages.add(RemoteMessageInfo.user(text));
    isRunning.value = true;
    ConnectionService().send({'type': 'task', 'content': text});
    _scrollToBottom();
  }

  void confirmTool(String requestId, {required bool approved}) {
    ConnectionService()
        .send({'type': 'confirm', 'id': requestId, 'approved': approved});
    messages.removeWhere(
      (m) => m.type == RemoteMessageInfoType.confirm && m.confirmId == requestId,
    );
  }

  void stopRunning() {
    isRunning.value = false;
  }

  void newSession() {
    currentSessionTitle.value = 'New Chat';
    messages.clear();
    _streamingMsgId = null;
    isRunning.value = false;
  }

  void switchToSession(String sessionId) {
    // TODO: request session history from desktop
  }
}

