import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'model/ask_user_info.dart';
import 'model/chat_session_info.dart';
import 'dialog/ask_user_dialog.dart';
import 'dialog/skill_failure_dialog.dart';
import 'dialog/sudo_prompt_dialog.dart';
import 'model/remote_message_info.dart';
import 'model/skill_item_info.dart';
import '../../others/services/connection_service.dart';
import '../../others/tool/database_tool.dart';

class ChatLogic extends GetxController {
  final inputController = TextEditingController();
  final scrollController = ScrollController();

  final currentSessionTitle = 'New Chat'.obs;
  final isRunning = false.obs;
  final messages = <RemoteMessageInfo>[].obs;
  final sessions = <ChatSessionInfo>[].obs;

  // ── 桌面端设置镜像（通过 WS settings_state 同步）────────────────────────
  final allowAllTools = false.obs;
  final allowToolDeviation = true.obs;
  final autoFillSudo = false.obs;
  final pendingSkill = Rxn<String>();

  // ── 模型和 Token 统计─────────────────────────────────────────────────
  final sessionTokens = 0.obs;
  final sessionModelId = ''.obs;

  // ── LLM ask_user 待回答请求───────────────────────────────────────────
  final pendingAskUser = Rxn<AskUserInfo>();

  /// 从桌面端获取的已安装 Skill 列表（按需拉取，内存缓存）
  final availableSkills = <SkillItemInfo>[].obs;

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
      case 'settings_state':
        _onSettingsState(msg);
      case 'session_stats':
        _onSessionStats(msg);
      case 'ask_user':
        _onAskUser(msg);
      case 'skill_failure':
        _onSkillFailure(msg);
      case 'sudo_prompt':
        _onSudoPrompt(msg);
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

  void _onSettingsState(Map<String, dynamic> data) {
    if (data['allow_all_tools'] is bool) {
      allowAllTools.value = data['allow_all_tools'] as bool;
    }
    if (data['allow_tool_deviation'] is bool) {
      allowToolDeviation.value = data['allow_tool_deviation'] as bool;
    }
    if (data['auto_fill_sudo'] is bool) {
      autoFillSudo.value = data['auto_fill_sudo'] as bool;
    }
    pendingSkill.value = data['pending_skill'] as String?;
  }

  void _onSessionStats(Map<String, dynamic> data) {
    if (data['total_tokens'] is int) {
      sessionTokens.value = data['total_tokens'] as int;
    }
    if (data['model_id'] is String) {
      sessionModelId.value = data['model_id'] as String;
    }
  }

  void _onAskUser(Map<String, dynamic> data) {
    final id = data['id'] as String? ?? '';
    final question = data['question'] as String? ?? '';
    final type = data['input_type'] as String? ?? 'text';
    final options = (data['options'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final hint = data['hint'] as String?;
    if (id.isEmpty) return;
    final info = AskUserInfo(
      id: id,
      question: question,
      type: type,
      options: options,
      hint: hint,
    );
    pendingAskUser.value = info;
    Get.dialog<String>(
      AskUserDialog(info: info),
      barrierDismissible: false,
    ).then((value) {
      pendingAskUser.value = null;
      if (value != null && value.isNotEmpty) {
        ConnectionService().send({'type': 'input', 'id': id, 'value': value});
      }
    });
  }

  void _onSkillFailure(Map<String, dynamic> data) {
    final skillName = data['skill_name'] as String? ?? '';
    final stepTitle = data['step_title'] as String? ?? '';
    final reason = data['reason'] as String? ?? '';
    final toolName = data['tool_name'] as String? ?? '';
    final failureReport = data['failure_report'] as String? ?? '';
    final isDeviation = reason == 'unexpected_tool';
    // 使用 Get.dialog 显示结构化报告
    Get.dialog(
      SkillFailureDialog(
        skillName: skillName,
        stepTitle: stepTitle,
        toolName: toolName,
        failureReport: failureReport,
        isDeviation: isDeviation,
      ),
      barrierDismissible: true,
    );
  }

  void _onSudoPrompt(Map<String, dynamic> data) {
    final id = data['id'] as String? ?? '';
    final prompt = data['prompt'] as String? ?? '';
    if (id.isEmpty) return;
    // 弹出密码输入 Dialog，用户提交后发 sudo_input
    Get.dialog<String>(
      SudoPromptDialog(promptText: prompt),
      barrierDismissible: false,
    ).then((password) {
      if (password != null && password.isNotEmpty) {
        respondSudoPassword(id, password);
      }
    });
  }

  // ── ask_user 公共回复 API ──────────────────────────────────────────────────

  /// 用户回答了 ask_user 问题（内部主要由 Get.dialog .then 处理，这里仅供外部调用）
  void respondAskUser(String id, String value) {
    if (pendingAskUser.value?.id != id) return;
    pendingAskUser.value = null;
    ConnectionService().send({'type': 'input', 'id': id, 'value': value});
  }

  /// 用户取消了 ask_user（告知桌面端取消，以 empty string 代表）
  void cancelAskUser(String id) {
    if (pendingAskUser.value?.id != id) return;
    pendingAskUser.value = null;
    ConnectionService().send({'type': 'input', 'id': id, 'value': ''});
  }

  /// 提交 sudo 密码给桌面端
  void respondSudoPassword(String id, String password) {
    ConnectionService()
        .send({'type': 'sudo_input', 'id': id, 'password': password});
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

  // ── 设置同步 ───────────────────────────────────────────────────────────────

  void setSetting(String key, dynamic value) {
    ConnectionService().send({'type': 'set_setting', 'key': key, 'value': value});
    // 乐观更新本地状态
    switch (key) {
      case 'allow_all_tools':
        if (value is bool) allowAllTools.value = value;
      case 'allow_tool_deviation':
        if (value is bool) allowToolDeviation.value = value;
      case 'auto_fill_sudo':
        if (value is bool) autoFillSudo.value = value;
    }
  }

  void setSkill(String? name) {
    pendingSkill.value = name;
    ConnectionService().send({'type': 'set_skill', 'name': name ?? ''});
  }

  /// 将 sudo 密码推送到桌面端写入其本地存储
  void setSudoPasswordSetting(String password) {
    ConnectionService().send({'type': 'set_sudo_password', 'password': password});
  }

  /// 向桌面端 HTTP /skills 接口拉取已安装 Skill 列表。
  Future<void> fetchSkills() async {
    if (!ConnectionService().isConnected.value) return;
    final host = ConnectionService().serverHost.value;
    final port = ConnectionService().serverPort.value;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request =
          await client.getUrl(Uri.parse('http://$host:$port/skills'));
      final response = await request.close();
      final body = await response.transform(const Utf8Decoder()).join();
      client.close();
      final list = jsonDecode(body) as List<dynamic>;
      availableSkills.assignAll(
        list.map((e) => SkillItemInfo(
              name: e['name'] as String? ?? '',
              description: e['description'] as String? ?? '',
            )),
      );
    } catch (_) {
      // 静默失败；availableSkills 保持上次值
    }
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



