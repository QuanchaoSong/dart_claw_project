import 'package:flutter/material.dart';

class LogLineView extends StatelessWidget {
  const LogLineView({super.key, required this.content});
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Text(
        content,
        style: const TextStyle(color: Colors.white30, fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }
}
