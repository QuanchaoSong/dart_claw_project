import 'package:flutter/material.dart';

import '../constants/color_constants.dart';

/// 应用风格确认弹框（深色主题）。
///
/// 用法：
/// ```dart
/// final confirmed = await ConfirmDialog.show(
///   context,
///   title: '断开连接',
///   message: '确定要断开与桌面端的连接吗？',
///   destructiveLabel: '断开',
/// );
/// if (confirmed) { ... }
/// ```
class ConfirmDialog {
  /// 弹出确认框，返回 true 表示用户确认，false 表示取消。
  ///
  /// [destructiveLabel] 设为非 null 时，确认按钮显示为红色破坏性样式。
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? destructiveLabel,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
  }) async {
    final bool isDestructive = destructiveLabel != null;
    final String actionLabel = destructiveLabel ?? confirmLabel;

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.dialogBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: Text(cancelLabel),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: isDestructive
                          ? const Color(0xFFFF6B6B)
                          : AppColors.primary,
                      backgroundColor:
                          (isDestructive
                                  ? const Color(0xFFFF6B6B)
                                  : AppColors.primary)
                              .withOpacity(0.12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }
}
