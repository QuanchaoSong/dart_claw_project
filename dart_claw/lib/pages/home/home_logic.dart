import 'package:dart_claw/others/services/app_config_service.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:get/get.dart';

class HomeLogic extends GetxController {
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

    _runAgent(content.trim(), assistantMsg.id, history);
  }

  // ─── 事件处理 ─────────────────────────────────────────────────────────────

  /// 处理来自 ClawAgentRunner 的事件（阶段二实现，目前为 stub）
  void handleEvent(ClawAgentEvent event) {
    switch (event) {
      case ClawAgentMessageChunkEvent(:final messageId, :final chunk):
        _appendChunk(messageId, chunk);

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

  void _appendError(String message) {
    if (streamingMessageId != null) {
      final idx = messages.indexWhere((m) => m.id == streamingMessageId);
      if (idx != -1) {
        messages[idx] = messages[idx].copyWith(
          content: message,
          status: ClawChatMessageStatus.error,
        );
        return;
      }
    }
    messages.add(ClawChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      role: ClawChatMessageRole.assistant,
      timestamp: DateTime.now(),
      status: ClawChatMessageStatus.error,
      content: message,
    ));
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

