import 'package:dart_claw/others/tool/database_tool.dart';
import 'package:dart_claw_core/dart_claw_core.dart';

/// 对历史消息进行 LLM 摘要并归档，缩减上下文长度。
///
/// 调用 [compress] 后：
/// 1. 调用 LLM 生成带 [ref:id] 标记的摘要
/// 2. 在 DB 中归档 [toArchive] 中的消息（is_archived = 1）
/// 3. 插入摘要消息（role=system, type=summary）
/// 4. 插入 UI 分隔行（type=divider）
class ContextCompressor {
  const ContextCompressor({required this.client});

  final ClawLlmClient client;

  Future<void> compress({
    required String sessionId,
    required List<ClawChatMessage> toArchive,
    required int insertSortIndex,
  }) async {
    if (toArchive.isEmpty) return;

    // 1. 生成摘要
    final summaryText = await _summarize(toArchive);

    // 2. 归档原始消息
    await DatabaseTool.shared
        .archiveMessages(toArchive.map((m) => m.id).toList());

    // 3. 插入摘要消息
    final summaryMsg = ClawChatMessage.summary(summaryText);
    await DatabaseTool.shared.upsertSummary(
      sessionId,
      summaryMsg,
      insertSortIndex,
      coversFrom: toArchive.first.id,
      coversTo: toArchive.last.id,
    );

    // 4. 插入分隔行（sort_index 紧跟摘要之后）
    final dividerMsg = ClawChatMessage.divider();
    await DatabaseTool.shared.upsertDivider(
      sessionId,
      dividerMsg,
      insertSortIndex + 1,
    );
  }

  Future<String> _summarize(List<ClawChatMessage> messages) async {
    final sb = StringBuffer();
    for (final msg in messages) {
      final content = msg.content.trim();
      if (content.isEmpty) continue;
      sb.writeln('--- [ID: ${msg.id}] ${msg.role.name.toUpperCase()} ---');
      // 超长消息截断，避免摘要提示本身过大
      if (content.length > 2000) {
        sb.writeln('${content.substring(0, 2000)}... [truncated]');
      } else {
        sb.writeln(content);
      }
      sb.writeln();
    }

    final prompt = [
      {
        'role': 'system',
        'content': 'You are a context summarizer. Summarize the following '
            'conversation excerpt into a compact summary. Requirements:\n'
            '1. Capture key topics, decisions, file paths, errors, and outcomes\n'
            '2. After each important point, append the source message ID as [ref:ID]\n'
            '3. Use the same language as the conversation\n'
            '4. Keep it concise — aim for 200-400 words max\n'
            '5. Output the summary directly without any preamble',
      },
      {
        'role': 'user',
        'content': 'CONVERSATION TO SUMMARIZE:\n\n${sb.toString()}',
      },
    ];

    final textBuffer = StringBuffer();
    await for (final delta in client.streamChat(messages: prompt)) {
      if (delta is ClawLlmTextDelta) {
        textBuffer.write(delta.text);
      }
    }

    final result = textBuffer.toString().trim();
    return result.isEmpty ? '[Context summary unavailable]' : result;
  }
}
