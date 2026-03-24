import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../others/model/chat_session_info.dart';
import '../../others/model/remote_message_info.dart';
import '../../others/services/connection_service.dart';
import '../../others/tool/database_tool.dart';

class ChatLogic extends GetxController {
  final inputController = TextEditingController();
  final scrollController = ScrollController();

  final currentSessionTitle = 'New Chat'.obs;
  final isRunning = false.obs;
  final messages = <RemoteMessageInfo>[].obs;
  final sessions = <ChatSessionInfo>[].obs;

  StreamSubscription<Map<String, dynamic>>? _sub;
  String? _streamingMsgId;
  String? _sessionId;

  @override
  void onInit() {
    super.onInit();
    _sub = ConnectionService().incomingMessages.listen(_handleRemoteMessage);
    _loadSessions();
  }

  @override
  void onClose() {
    _sub?.cancel();
    inputController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  Future<void> _loadSessions() async {
    sessions.assignAll(await DatabaseTool().listSessions());
  }

  // ── WS message handling ────────────────────────────────────────────────────

  void _handleRemoteMessage(Map<String, dynamic> msg) {
    // 按 session_id 过滤，忽略不属于当前 session 的事件
    final sid = msg['session_id'] as String?;
    if (sid != null && sid != _sessionId) return;

    switch (msg['type'] as String?) {
      case 'chunk':
        _onChunk(msg['content'] as String? ?? '');
      case 'reasoning_chunk':
        _onReasoningChunk(msg['content'] as String? ?? '');
      case 'tool':
        _onTool(msg);
      case 'message_done':
        _onMessageDone();
      case 'confirm_request':
        _onConfirmRequest(msg);
      case 'done':
        _onDone();
      case 'error':
        _onError(msg['message'] as String? ?? '未知错误');
      case 'log':
        break;
    }
    _scrollToBottom();
  }

  void _onChunk(String chunk) {
    _ensureStreamingBubble();
    final idx = messages.indexWhere((m) => m.id == _streamingMsgId);
    if (idx == -1) return;
    messages[idx].content += chunk;
    messages.refresh();
  }

  void _onReasoningChunk(String chunk) {
    _ensureStreamingBubble();
    final idx = messages.indexWhere((m) => m.id == _streamingMsgId);
    if (idx == -1) return;
    messages[idx].reasoning += chunk;
    messages.refresh();
  }

  // 多轮 agent：message_done 后 _streamingMsgId 为 null，下一轮 chunk 到来时新建气泡
  void _ensureStreamingBubble() {
    if (_streamingMsgId != null) return;
    final msg = RemoteMessageInfo.assistantStreaming();
    _streamingMsgId = msg.id;
    messages.add(msg);
  }

  void _onTool(Map<String, dynamic> data) {
    final toolId = data['id'] as String? ?? '';
    final name = data['name'] as String? ?? '';
    final status = data['status'] as String? ?? 'running';
    final args = data['args'] as Map<String, dynamic>?;
    if (toolId.isNotEmpty) {
      final idx = messages.lastIndexWhere(
        (m) => m.type == RemoteMessageInfoType.tool && m.toolId == toolId,
      );
      if (idx != -1) {
        messages[idx].toolStatus = status;
        if (args != null) messages[idx].toolArgs = args;
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
    final toolName = data['message'] as String? ?? '';
    final args = data['args'] as Map<String, dynamic>?;
    // Build a human-readable description: tool name + all arg values
    final argLines = args?.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
    final message = argLines != null && argLines.isNotEmpty
        ? '$toolName\n$argLines'
        : toolName;
    messages.add(RemoteMessageInfo.confirm(confirmId: id, message: message));
  }

  void _onMessageDone() {
    // 本轮 LLM 响应结束：finalize 当前气泡，下轮 chunk 新建气泡
    _finalizeStreaming();
  }

  void _onDone() {
    _finalizeStreaming();
    isRunning.value = false;
    _persistConversation();
    if (_sessionId != null) {
      DatabaseTool().touchSession(_sessionId!);
      _updateSessionUpdatedAt(_sessionId!);
    }
  }

  void _onError(String text) {
    _finalizeStreaming();
    messages.add(RemoteMessageInfo.log('⚠ $text'));
    isRunning.value = false;
    _persistConversation();
    if (_sessionId != null) {
      DatabaseTool().touchSession(_sessionId!);
      _updateSessionUpdatedAt(_sessionId!);
    }
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

  // 在 done 时将对话持久化到 SQLite
  void _persistConversation() {
    if (_sessionId == null) return;
    for (final msg in messages) {
      if (msg.type == RemoteMessageInfoType.confirm) continue;
      if (msg.type == RemoteMessageInfoType.assistant && msg.isStreaming) continue;
      DatabaseTool().upsertMessage(_sessionId!, msg);
    }
  }

  void _updateSessionUpdatedAt(String sessionId) {
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      sessions[idx] = sessions[idx].copyWith(updatedAt: DateTime.now());
    }
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

    // 懒创建 session（第一条消息触发）
    if (_sessionId == null) _createSession(text);

    final userMsg = RemoteMessageInfo.user(text);
    messages.add(userMsg);
    DatabaseTool().upsertMessage(_sessionId!, userMsg);

    // 立即建流式占位气泡，确保 LoadingDots 渲染
    final assistantMsg = RemoteMessageInfo.assistantStreaming();
    _streamingMsgId = assistantMsg.id;
    messages.add(assistantMsg);
    isRunning.value = true;

    ConnectionService()
        .send({'type': 'task', 'session_id': _sessionId, 'content': text});
    _scrollToBottom();
  }

  void _createSession(String firstMessage) {
    final t = DateTime.now().microsecondsSinceEpoch;
    _sessionId = (t ^ (t >> 16)).toRadixString(36);
    final title = firstMessage.length > 50
        ? '${firstMessage.substring(0, 50)}…'
        : firstMessage;
    final session = ChatSessionInfo(
      id: _sessionId!,
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    DatabaseTool().insertSession(session);
    sessions.insert(0, session);
    currentSessionTitle.value = title;
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
    ConnectionService().send({'type': 'stop'});
  }

  void newSession() {
    _sessionId = null;
    currentSessionTitle.value = 'New Chat';
    messages.clear();
    _streamingMsgId = null;
    isRunning.value = false;
    // 不需要发送 WS 消息：下一条 task 携带新 session_id，桌面端自动新建 session
  }

  Future<void> switchToSession(ChatSessionInfo session) async {
    if (_sessionId == session.id) return;
    _sessionId = session.id;
    currentSessionTitle.value = session.title;
    messages.clear();
    _streamingMsgId = null;
    isRunning.value = false;
    final loaded = await DatabaseTool().loadMessages(session.id);
    messages.assignAll(loaded);
    _scrollToBottom();
  }

  Future<void> deleteSession(ChatSessionInfo session) async {
    await DatabaseTool().deleteSession(session.id);
    sessions.remove(session);
    if (_sessionId == session.id) newSession();
  }
}



