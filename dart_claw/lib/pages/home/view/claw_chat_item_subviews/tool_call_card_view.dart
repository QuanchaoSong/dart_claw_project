import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:dart_claw/pages/home/view/claw_chat_item_subviews/chart_card_view.dart';
import 'package:dart_claw/pages/home/view/claw_chat_item_subviews/image_card_view.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ToolCallCardView extends StatelessWidget {
  const ToolCallCardView({super.key, required this.record});

  final ClawToolCallRecord record;

  @override
  Widget build(BuildContext context) {
    if (record.name == 'show_chart') {
      return ChartCardView(record: record);
    }

    if (record.name == 'show_image') {
      return ImageCardView(record: record);
    }

    if (record.status == ClawToolStatus.awaitingConfirmation) {
      return _ConfirmCard(record: record);
    }

    final (statusColor, statusIcon) = _statusStyle(record.status);

    final subtitle = record.args['command'] as String? ??
        record.args['path'] as String? ??
        record.args['pattern'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          record.status == ClawToolStatus.running
              ? const CupertinoActivityIndicator(radius: 7)
              : Icon(statusIcon, size: 14, color: statusColor.withOpacity(0.9)),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static (Color, IconData) _statusStyle(ClawToolStatus status) =>
      switch (status) {
        ClawToolStatus.success => (Colors.green, Icons.check_circle_outline),
        ClawToolStatus.error => (Colors.red, Icons.error_outline),
        ClawToolStatus.running => (Colors.orange, Icons.sync),
        ClawToolStatus.awaitingConfirmation =>
          (Colors.amber, Icons.warning_amber_outlined),
        ClawToolStatus.pending => (Colors.white54, Icons.schedule),
      };
}

// ─── 内嵌确认卡片 ─────────────────────────────────────────────────────────────

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({required this.record});

  final ClawToolCallRecord record;

  @override
  Widget build(BuildContext context) {
    final subtitle = record.args['command'] as String? ??
        record.args['path'] as String? ??
        record.args['pattern'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Colors.amber,
              ),
              const SizedBox(width: 6),
              Text(
                record.name,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ConfirmButton(
                label: 'Allow',
                color: AppColors.confirmAllow,
                onTap: () => Get.find<HomeLogic>().confirmTool(
                  record.confirmRequestId!,
                  allow: true,
                ),
              ),
              const SizedBox(width: 8),
              _ConfirmButton(
                label: 'Deny',
                color: Colors.red.shade700,
                onTap: () => Get.find<HomeLogic>().confirmTool(
                  record.confirmRequestId!,
                  allow: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Get.find<HomeLogic>().toggleInfoPanel(),
            child: const Text(
              'Always allow for this session →',
              style: TextStyle(
                fontSize: 11,
                color: Colors.amber,
                decoration: TextDecoration.underline,
                decorationColor: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
