import 'package:flutter/material.dart';

import '../../../others/model/remote_message_info.dart';

class ToolCardView extends StatelessWidget {
  const ToolCardView({super.key, required this.msg});
  final RemoteMessageInfo msg;

  @override
  Widget build(BuildContext context) {
    final isActive =
        msg.toolStatus == 'running' || msg.toolStatus == 'pending';
    final (icon, iconColor) = switch (msg.toolStatus) {
      'success' => (Icons.check_circle_outline, Colors.greenAccent),
      'error' => (Icons.error_outline, Colors.redAccent),
      'awaitingConfirmation' => (Icons.help_outline, Colors.orangeAccent),
      _ => (Icons.settings_outlined, Colors.white38),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isActive
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white38),
                  ))
              : Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Text(msg.toolName ?? '',
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontFamily: 'monospace')),
          if (msg.content.isNotEmpty) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(msg.content,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ],
      ),
    );
  }
}
