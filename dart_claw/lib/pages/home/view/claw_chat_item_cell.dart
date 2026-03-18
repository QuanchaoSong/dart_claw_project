import 'package:dart_claw/pages/home/view/claw_chat_item_subviews/content_bubble_view.dart';
import 'package:dart_claw/pages/home/view/claw_chat_item_subviews/reasoning_block_view.dart';
import 'package:dart_claw/pages/home/view/claw_chat_item_subviews/tool_call_card_view.dart';
import 'package:dart_claw/pages/home/view/loading_dots.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/material.dart';

/// AI 助手消息气泡
///
/// 渲染 [ClawChatMessage.blocks] 有序列表，支持多轮 reasoning / content / tool call
/// 依次追加，互不覆盖。每个 reasoning block 独立管理展开/收起状态。
class ClawChatItemCell extends StatefulWidget {
  const ClawChatItemCell({super.key, required this.msg});

  final ClawChatMessage msg;

  @override
  State<ClawChatItemCell> createState() => _ClawChatItemCellState();
}

class _ClawChatItemCellState extends State<ClawChatItemCell> {
  /// index → 用户是否主动覆盖了展开状态（null = 跟随 block.isStreaming 默认行为）
  final Map<int, bool> _expandOverride = {};

  bool _isExpanded(int index, bool blockIsStreaming) =>
      _expandOverride[index] ?? blockIsStreaming;

  void _toggleExpand(int index, bool currentExpanded) {
    setState(() => _expandOverride[index] = !currentExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final isError = msg.status == ClawChatMessageStatus.error;
    final isStreaming = msg.status == ClawChatMessageStatus.streaming;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.blocks.isEmpty && isStreaming)
            const LoadingDots()
          else
            for (var i = 0; i < msg.blocks.length; i++)
              _buildBlock(msg.blocks[i], i, isError),
        ],
      ),
    );
  }

  Widget _buildBlock(ClawChatBlock block, int index, bool isError) {
    return switch (block) {
      ClawReasoningBlock() => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ReasoningBlockView(
            reasoning: block.content,
            isStreaming: block.isStreaming,
            isExpanded: _isExpanded(index, block.isStreaming),
            onToggle: () =>
                _toggleExpand(index, _isExpanded(index, block.isStreaming)),
          ),
        ),
      ClawContentBlock() => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ContentBubbleView(block: block, isError: isError),
        ),
      ClawToolCallBlock() => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ToolCallCardView(record: block.record),
        ),
    };
  }
}
