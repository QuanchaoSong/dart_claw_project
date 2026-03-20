import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/pages/settings/view/scheduler_subviews/task_edit_dialog.dart';
import 'package:dart_claw/pages/settings/view/scheduler_subviews/task_list_view.dart';
import 'package:flutter/material.dart';

class SettingsSchedulerView extends StatelessWidget {
  const SettingsSchedulerView({super.key});

  void _showCreateDialog(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (_) => const TaskEditDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Row(
            children: [
              const Text(
                '已配置的定时任务',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _AddButton(onTap: () => _showCreateDialog(context)),
            ],
          ),
        ),
        const Expanded(child: TaskListView()),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.secondary.withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: AppColors.secondary),
            SizedBox(width: 4),
            Text('新建',
                style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

