import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Skill 步骤失败时弹出的结构化报告弹窗。
///
/// 展示：激活 Skill 名称、失败步骤、失败原因（工具偏离 / 工具执行失败）、
/// 建议操作（来自 Skill 文件的 failureReport 字段）、工具原始输出（可选）。
class SkillFailureDialog extends StatelessWidget {
  const SkillFailureDialog({
    super.key,
    required this.skillName,
    required this.stepTitle,
    required this.toolName,
    required this.toolOutput,
    required this.failureReport,
    required this.reason,
  });

  final String skillName;
  final String stepTitle;
  final String toolName;
  final String toolOutput;
  final String failureReport;
  final ClawSkillFailureReason reason;

  @override
  Widget build(BuildContext context) {
    final reasonLabel = reason == ClawSkillFailureReason.unexpectedTool
        ? '工具偏离（调用了预期以外的工具）'
        : '工具执行失败';

    return AlertDialog(
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.orange, width: 0.5),
      ),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Skill 执行中止：$skillName',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('失败步骤', stepTitle),
              _row('失败原因', reasonLabel),
              _row('调用工具', toolName),
              const SizedBox(height: 12),
              const Text('建议操作',
                  style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                failureReport.isNotEmpty ? failureReport : '请检查相关权限或配置后重试。',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.5),
              ),
              if (toolOutput.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('工具原始输出',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    toolOutput.length > 800
                        ? '${toolOutput.substring(0, 800)}…'
                        : toolOutput,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text('知道了'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
