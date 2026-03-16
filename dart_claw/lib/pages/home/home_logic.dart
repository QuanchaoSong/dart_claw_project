import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dart_claw/others/services/app_config_service.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:get/get.dart';

class HomeLogic extends GetxController {  // ─── 输入框 & 滚动控制器 ───────────────────────────────────────────────

  final inputController = TextEditingController();
  final scrollController = ScrollController();

  @override
  void onClose() {
    inputController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  /// 从输入框取文本发送，发送后清空输入框（由 UI 层调用）
  void submitInput() {
    final text = inputController.text.trim();
    if (text.isEmpty) return;
    inputController.clear();
    sendMessage(text);
  }
  // ─── 面板显示 ─────────────────────────────────────────────────────────────

  final showInfoPanel = true.obs;

  void toggleInfoPanel() {
    showInfoPanel.value = !showInfoPanel.value;
  }

  // ─── 消息列表 ─────────────────────────────────────────────────────────────

  /// 当前会话的消息列表，UI 层用 Obx 监听
  final messages = <ClawChatMessage>[].obs;

  /// Agent loop 是否正在运行（用于禁用输入框、显示 loading 状态）
  final isRunning = false.obs;

  /// 当前正在流式输出的 assistant 消息 id（null 表示无流式输出）
  String? streamingMessageId;

  // ─── 发送消息 ─────────────────────────────────────────────────────────────

  /// 用户发送一条消息（由 UI 层调用）
  void sendMessage(String content) {
    if (content.trim().isEmpty) return;
    if (isRunning.value) return;

    // 历史消息快照（不含即将添加的新消息）
    final history = List<ClawChatMessage>.from(messages);

    // 1. 添加用户消息气泡
    final userMsg = ClawChatMessage.user(content.trim());
    messages.add(userMsg.copyWith(status: ClawChatMessageStatus.done));

    // 2. 添加 assistant 占位气泡（流式输出用）
    final assistantMsg = ClawChatMessage.assistantStreaming();
    streamingMessageId = assistantMsg.id;
    messages.add(assistantMsg);

    isRunning.value = true;
    _scrollToBottom();

    _runAgent(content.trim(), assistantMsg.id, history);
  }

  // ─── 事件处理 ─────────────────────────────────────────────────────────────

  /// 处理来自 ClawAgentRunner 的事件（阶段二实现，目前为 stub）
  void handleEvent(ClawAgentEvent event) {
    switch (event) {
      case ClawAgentMessageChunkEvent(:final messageId, :final chunk):
        _appendChunk(messageId, chunk);
        _scrollToBottom();

      case ClawAgentMessageDoneEvent(:final messageId, :final toolCalls):
        _finalizeMessage(messageId, toolCalls: toolCalls);

      case ClawAgentToolEvent(:final record):
        _upsertToolRecord(record);

      case ClawAgentConfirmRequestEvent():
        // TODO(阶段四)：弹出确认 Dialog
        break;

      case ClawAgentDoneEvent():
        isRunning.value = false;
        streamingMessageId = null;

      case ClawAgentErrorEvent(:final message):
        _appendError(message);
        isRunning.value = false;
        streamingMessageId = null;

      case ClawAgentLogEvent():
        // 普通日志暂不展示在消息列表，后续可加到 Info 面板
        break;
    }
  }

  // ─── 私有辅助 ─────────────────────────────────────────────────────────────

  void _appendChunk(String messageId, String chunk) {
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    messages[idx] = messages[idx].appendChunk(chunk);
  }

  void _finalizeMessage(
    String messageId, {
    List<ClawToolCallRecord> toolCalls = const [],
  }) {
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    messages[idx] = messages[idx]
        .finalize()
        .copyWith(toolCalls: toolCalls);
  }

  void _upsertToolRecord(ClawToolCallRecord record) {
    // 找到关联的 assistant 消息并更新其 toolCalls 列表
    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      if (msg.role != ClawChatMessageRole.assistant) continue;
      final idx = msg.toolCalls.indexWhere((t) => t.id == record.id);
      if (idx == -1) continue;
      final updated = List<ClawToolCallRecord>.from(msg.toolCalls);
      updated[idx] = record;
      messages[i] = msg.copyWith(toolCalls: updated);
      return;
    }
  }

  void _appendError(String fullMessage) {
    // 1. 移除 assistant 占位消息（不在聊天中展示错误）
    if (streamingMessageId != null) {
      messages.removeWhere((m) => m.id == streamingMessageId);
    }

    // 2. 完整错误信息打印到控制台，方便复制调试
    debugPrint('[dart_claw] ❌ Agent error:\n$fullMessage');

    // 3. 弹窗展示（可滚动，方便阅读）
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.red, width: 0.5),
        ),
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Text(
              fullMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// 当前配置的模型名称（用于 Info 面板显示）
  String get currentModelId =>
      AppConfigService.shared.config.value.model.modelId;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 使用 [ClawAgentRunner] 运行一轮 Agent 对话
  Future<void> _runAgent(
    String userMessage,
    String assistantMsgId,
    List<ClawChatMessage> history,
  ) async {
    final cfg = AppConfigService.shared.config.value;
    final client = ClawLlmClient(
      baseUrl: cfg.model.effectiveBaseUrl,
      apiKey: cfg.model.apiKey,
      modelId: cfg.model.modelId,
      temperature: cfg.model.temperature,
      maxTokens: cfg.model.maxTokens,
    );
    final runner = ClawAgentRunner(client: client);

    await for (final event in runner.run(
      userMessage: userMessage,
      history: history,
      assistantMessageId: assistantMsgId,
    )) {
      handleEvent(event);
    }
  }

}

