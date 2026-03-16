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

    // 1. 添加用户消息气泡
    final userMsg = ClawChatMessage.user(content.trim());
    messages.add(userMsg.copyWith(status: ClawChatMessageStatus.done));

    // 2. 添加 assistant 占位气泡（流式输出用）
    final assistantMsg = ClawChatMessage.assistantStreaming();
    streamingMessageId = assistantMsg.id;
    messages.add(assistantMsg);

    isRunning.value = true;

    // TODO(阶段二)：调用 ClawAgentRunner，订阅 Stream<ClawAgentEvent> 更新消息列表
    // 暂时用 stub 模拟，验证 UI 链路
    _stubResponse(assistantMsg.id);
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

  /// Stub：模拟一次流式响应，验证 UI 链路（阶段二删除）
  Future<void> _stubResponse(String messageId) async {
    const reply = 'Hello! I am dart Claw. '
        'The LLM integration will be wired up in Phase 2.';
    for (final char in reply.split('')) {
      await Future.delayed(const Duration(milliseconds: 30));
      handleEvent(ClawAgentMessageChunkEvent(messageId, char));
    }
    handleEvent(ClawAgentMessageDoneEvent(messageId));
    handleEvent(ClawAgentDoneEvent('Stub response complete.'));
  }

}

