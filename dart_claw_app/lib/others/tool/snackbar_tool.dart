import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 中国古典风格配色
class _SnackbarColors {
  static const Color success = Color(0xFF5B8D6E); // 青竹绿 - 成功
  static const Color error = Color(0xFFB85C54); // 朱砂红 - 错误
  static const Color info = Color(0xFF2C5F6F); // 靛青色 - 信息
  static const Color warning = Color(0xFFD4A574); // 琥珀黄 - 警告
}

class SnackbarTool {
  static void showError(String message, {BuildContext? context}) {
    showText(message, context: context, backgroundColor: _SnackbarColors.error);
  }

  static void showInfo(String message, {BuildContext? context}) {
    showText(message, context: context, backgroundColor: _SnackbarColors.info);
  }

  static void showSuccess(String message, {BuildContext? context}) {
    showText(
      message,
      context: context,
      backgroundColor: _SnackbarColors.success,
    );
  }

  static void showWarning(String message, {BuildContext? context}) {
    showText(
      message,
      context: context,
      backgroundColor: _SnackbarColors.warning,
    );
  }

  static void showText(
    String message, {
    BuildContext? context,
    Color backgroundColor = const Color(0xFF5B8D6E),
  }) {
    Get.rawSnackbar(
      message: message,
      backgroundColor: backgroundColor,
      borderRadius: 8,
      margin: const EdgeInsets.all(16),
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
      snackStyle: SnackStyle.FLOATING,
    );
  }

  static void showErrorWithTitle(
    String title,
    String message, {
    BuildContext? context,
  }) {
    showTextWithTitle(
      title,
      message,
      context: context,
      backgroundColor: _SnackbarColors.error,
    );
  }

  static void showInfoWithTitle(
    String title,
    String message, {
    BuildContext? context,
  }) {
    showTextWithTitle(
      title,
      message,
      context: context,
      backgroundColor: _SnackbarColors.info,
    );
  }

  static void showSuccessWithTitle(
    String title,
    String message, {
    BuildContext? context,
  }) {
    showTextWithTitle(
      title,
      message,
      context: context,
      backgroundColor: _SnackbarColors.success,
    );
  }

  static void showTextWithTitle(
    String title,
    String message, {
    BuildContext? context,
    Color backgroundColor = const Color(0xFF5B8D6E),
  }) {
    Get.rawSnackbar(
      title: title,
      message: message,
      backgroundColor: backgroundColor,
      borderRadius: 8,
      margin: const EdgeInsets.all(16),
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
      snackStyle: SnackStyle.FLOATING,
    );
  }
}
