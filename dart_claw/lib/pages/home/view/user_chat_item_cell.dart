import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/material.dart';

class UserChatItemCell extends StatelessWidget {
  const UserChatItemCell({super.key, required this.msg});

  final ClawChatMessage msg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.primaryGradient,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: DefaultSelectionStyle(
                selectionColor: Colors.white.withOpacity(0.35),
                child: SelectionArea(
                  child: Text(
                    msg.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
