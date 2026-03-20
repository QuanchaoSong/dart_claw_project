import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/others/model/scheduled_task_info.dart';
import 'package:dart_claw/others/services/scheduler_service.dart';
import 'package:dart_claw/pages/settings/view/scheduler_subviews/task_edit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ─── Task list ────────────────────────────────────────────────────────────────

class TaskListView extends StatelessWidget {
  const TaskListView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = SchedulerService.instance;
    return Obx(() {
      final tasks = svc.tasks;
      if (tasks.isEmpty) {
        return const Center(
          child: Text(
            '暂无定时任务\n点击右上角 + 新建',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.8),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: tasks.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Colors.white12),
        itemBuilder: (ctx, i) => _TaskRow(task: tasks[i]),
      );
    });
  }
}

// ─── Task row ─────────────────────────────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});
  final ScheduledTaskInfo task;

  String _scheduleLabel() {
    final hh = task.time.hour.toString().padLeft(2, '0');
    final mm = task.time.minute.toString().padLeft(2, '0');
    switch (task.mode) {
      case ScheduleMode.daily:
        return '每天 $hh:$mm';
      case ScheduleMode.weekly:
        const dayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final days = task.weekdays.map((d) => dayNames[d]).join('、');
        return '$days $hh:$mm';
      case ScheduleMode.once:
        final d = task.onceAt;
        if (d == null) return '$hh:$mm';
        return '${d.month}/${d.day} $hh:$mm';
    }
  }

  String _lastRunLabel() {
    final lr = task.lastRunAt;
    if (lr == null) return '从未运行';
    final now = DateTime.now();
    final diff = now.difference(lr);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  @override
  Widget build(BuildContext context) {
    final svc = SchedulerService.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Switch(
            value: task.isEnabled,
            onChanged: (_) => svc.toggleTask(task.id),
            activeColor: AppColors.secondary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      task.name,
                      style: TextStyle(
                        color: task.isEnabled ? Colors.white : Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ActionBadge(task.actionType),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_scheduleLabel()}  ·  上次: ${_lastRunLabel()}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow_outlined,
                size: 16, color: Colors.white38),
            tooltip: '立即执行一次',
            onPressed: () => _confirmRunNow(context, svc),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white38),
            tooltip: '编辑',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => TaskEditDialog(existing: task),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 16, color: Colors.white38),
            tooltip: '删除',
            onPressed: () => _confirmDelete(context, svc),
          ),
        ],
      ),
    );
  }

  void _confirmRunNow(BuildContext ctx, SchedulerService svc) {
    showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: const Text('立即执行',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: Text(
          '立即执行「${task.name}」一次？\n不影响原有定时计划。',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(c).pop,
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(c).pop();
              svc.triggerNow(task.id);
            },
            child:
                const Text('执行', style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, SchedulerService svc) {
    showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: const Text('删除任务',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: Text(
          '确认删除「${task.name}」？',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(c).pop,
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              svc.deleteTask(task.id);
              Navigator.of(c).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ─── Action badge ─────────────────────────────────────────────────────────────

class _ActionBadge extends StatelessWidget {
  const _ActionBadge(this.type);
  final TaskActionType type;

  @override
  Widget build(BuildContext context) {
    final isAi = type == TaskActionType.aiPrompt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isAi ? AppColors.primary : Colors.blueGrey).withOpacity(0.25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color:
              (isAi ? AppColors.secondary : Colors.blueGrey).withOpacity(0.4),
        ),
      ),
      child: Text(
        isAi ? 'AI' : 'Shell',
        style: TextStyle(
          color: isAi ? AppColors.secondary : Colors.blueGrey[200],
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
