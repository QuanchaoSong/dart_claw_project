import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AgentErrorDialog extends StatelessWidget {
  const AgentErrorDialog({super.key, required this.message});

  final String message;

  static void show(String message) {
    Get.dialog(AgentErrorDialog(message: message), barrierDismissible: true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.red, width: 0.5),
      ),
      title: const Text(
        'Error',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
