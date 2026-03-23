import 'package:flutter/material.dart';

import '../../../others/constants/color_constants.dart';
import '../../../others/model/remote_message_info.dart';

class UserBubbleView extends StatelessWidget {
  const UserBubbleView({super.key, required this.msg});
  final RemoteMessageInfo msg;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColors.primaryGradient),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(msg.content,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }
}
