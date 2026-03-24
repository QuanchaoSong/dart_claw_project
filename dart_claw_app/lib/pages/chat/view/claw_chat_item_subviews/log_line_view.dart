import 'package:flutter/material.dart';

import '../../model/remote_message_info.dart';

class LogLineView extends StatelessWidget {
  const LogLineView({super.key, required this.msg});
  final RemoteMessageInfo msg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Text(
        msg.content,
        style: const TextStyle(color: Colors.white30, fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }
}
