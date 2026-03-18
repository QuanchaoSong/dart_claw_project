import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

class ContentBubbleView extends StatelessWidget {
  const ContentBubbleView({super.key, required this.block, required this.isError});

  final ClawContentBlock block;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    if (block.content.isEmpty && block.isStreaming) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withOpacity(0.12)
            : Colors.white.withOpacity(0.06),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(
          color: isError
              ? Colors.red.withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: SelectionArea(
        child: GptMarkdown(
          block.isStreaming ? '${block.content}\u258d' : block.content,
          style: TextStyle(
            color: isError ? Colors.red[300] : Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
