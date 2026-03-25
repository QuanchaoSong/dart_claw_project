import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class HudTool {
  static void showWithStatus(String text, {bool clickMaskDismiss = true}) {
    hide();
    SmartDialog.show(
      clickMaskDismiss: clickMaskDismiss,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 加载菊花
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  text,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static void show({bool clickMaskDismiss = true}) {
    showWithStatus("", clickMaskDismiss: clickMaskDismiss);
  }

  static void showError(String text) {
    showText(text);
  }

  static void showInfo(String text) {
    showText(text);
  }

  static void showText(String text) {
    hide();
    SmartDialog.showToast(
      text,
      alignment: Alignment(0, 0.8),
      maskColor: Colors.transparent,
    );
  }

  static void hide() {
    SmartDialog.dismiss();
  }

  static void dismiss() {
    SmartDialog.dismiss();
  }
}
