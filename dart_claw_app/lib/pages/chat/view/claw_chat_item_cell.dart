import 'package:flutter/material.dart';

import '../../../others/model/remote_message_info.dart';
import 'claw_chat_item_subviews/content_bubble_view.dart';
import 'claw_chat_item_subviews/reasoning_block_view.dart';
import 'loading_dots.dart';

class AssistantBubbleView extends StatefulWidget {
  const AssistantBubbleView({super.key, required this.msg});
  final RemoteMessageInfo msg;

  @override
  State<AssistantBubbleView> createState() => _AssistantBubbleViewState();
}

class _AssistantBubbleViewState extends State<AssistantBubbleView> {
  bool _reasoningExpanded = true;
  bool _prevIsStreaming = true;

  @override
  void didUpdateWidget(AssistantBubbleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isStreaming = widget.msg.isStreaming;
    // 流式输出结束时自动收起推理块（与桌面端行为一致）
    if (_prevIsStreaming && !isStreaming && widget.msg.reasoning.isNotEmpty) {
      setState(() => _reasoningExpanded = false);
    }
    _prevIsStreaming = isStreaming;
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final hasReasoning = msg.reasoning.isNotEmpty;
    final hasContent = msg.content.isNotEmpty;
    final isStreaming = msg.isStreaming;

    // 尚未收到任何内容：显示跳动加载点
    if (!hasReasoning && !hasContent && isStreaming) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LoadingDots(),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasReasoning)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ReasoningBlockView(
                reasoning: msg.reasoning,
                // 推理阶段：仍在流式输出且正文还未到达
                isStreaming: isStreaming && !hasContent,
                isExpanded: _reasoningExpanded,
                onToggle: () =>
                    setState(() => _reasoningExpanded = !_reasoningExpanded),
              ),
            ),
          if (hasContent || (isStreaming && hasReasoning))
            ContentBubbleView(
              content: msg.content,
              isStreaming: isStreaming,
            ),
        ],
      ),
    );
  }
}

