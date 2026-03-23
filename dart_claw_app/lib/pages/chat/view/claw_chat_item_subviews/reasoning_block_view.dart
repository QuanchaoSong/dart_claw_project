import 'package:flutter/material.dart';

import '../../../../others/constants/color_constants.dart';

class ReasoningBlockView extends StatefulWidget {
  const ReasoningBlockView({
    super.key,
    required this.reasoning,
    required this.isStreaming,
    required this.isExpanded,
    required this.onToggle,
  });

  final String reasoning;
  final bool isStreaming;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  State<ReasoningBlockView> createState() => _ReasoningBlockViewState();
}

class _ReasoningBlockViewState extends State<ReasoningBlockView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(ReasoningBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStreaming && widget.reasoning != oldWidget.reasoning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.reasoningAccent.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.psychology_outlined,
                    size: 14,
                    color: AppColors.reasoningAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isStreaming ? '思考中…' : '已思考',
                    style: const TextStyle(
                      color: AppColors.reasoningAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    widget.isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                    color: AppColors.reasoningAccent,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: widget.isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  widget.reasoning,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.55,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
