import 'package:flutter/material.dart';

import '../../../others/constants/color_constants.dart';
import '../../../others/model/remote_message_info.dart';

class AssistantBubbleView extends StatelessWidget {
  const AssistantBubbleView({super.key, required this.msg});
  final RemoteMessageInfo msg;

  @override
  Widget build(BuildContext context) {
    final showCursor = msg.isStreaming;
    final text = showCursor && msg.content.isEmpty
        ? null
        : '${msg.content}${showCursor ? '▍' : ''}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: text == null
            ? const LoadingDotsView()
            : SelectionArea(
                child: Text(text,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.5))),
      ),
    );
  }
}

class LoadingDotsView extends StatelessWidget {
  const LoadingDotsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      child: Text('…', style: TextStyle(color: Colors.white38, fontSize: 20)),
    );
  }
}
