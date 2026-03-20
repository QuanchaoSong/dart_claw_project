import 'dart:async';
import 'dart:io';

import 'package:dart_claw/others/model/scheduled_task_info.dart';
import 'package:dart_claw/others/tool/database_tool.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// 定时任务服务（纯 Dart 单例，App 内 Timer 驱动）
///
/// 初始化：在 main() 中 await SchedulerService.instance.init()
/// 访问：SchedulerService.instance.tasks
class SchedulerService {
  SchedulerService._();
  static final SchedulerService instance = SchedulerService._();

  // ── 响应式任务列表（UI 通过 Obx 监听） ──────────────────────────────────
  final tasks = <ScheduledTaskInfo>[].obs;

  // 每个任务对应一个 Timer（key = task.id）
  final _timers = <String, Timer>{};

  // ── 初始化 ────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final loaded = await DatabaseTool.shared.loadScheduledTasks();
    tasks.assignAll(loaded);
    _scheduleAll();
  }

  // ── CRUD（同时更新内存列表 + DB + Timer） ────────────────────────────────

  Future<void> addTask(ScheduledTaskInfo task) async {
    await DatabaseTool.shared.upsertScheduledTask(task);
    tasks.add(task);
    _scheduleTask(task);
  }

  Future<void> updateTask(ScheduledTaskInfo task) async {
    await DatabaseTool.shared.upsertScheduledTask(task);
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) tasks[idx] = task;
    _cancelTimer(task.id);
    _scheduleTask(task);
  }

  Future<void> deleteTask(String id) async {
    await DatabaseTool.shared.deleteScheduledTask(id);
    tasks.removeWhere((t) => t.id == id);
    _cancelTimer(id);
  }

  Future<void> toggleTask(String id) async {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final updated = tasks[idx].copyWith(isEnabled: !tasks[idx].isEnabled);
    await updateTask(updated);
  }

  /// 立即执行一次，不影响定时计划。
  Future<void> triggerNow(String id) async {
    final task = tasks.firstWhereOrNull((t) => t.id == id);
    if (task == null) return;
    await _onFire(task, updateSchedule: false);
  }

  // ── Timer 调度 ────────────────────────────────────────────────────────────

  void _scheduleAll() {
    for (final task in tasks) {
      _scheduleTask(task);
    }
  }

  void _scheduleTask(ScheduledTaskInfo task) {
    if (!task.isEnabled) return;
    final next = task.nextRunAt;
    if (next == null) return;

    final delay = next.difference(DateTime.now());
    _timers[task.id] = Timer(delay, () => _onFire(task));
    debugPrint(
        '[Scheduler] "${task.name}" scheduled at ${next.toString()}');
  }

  void _cancelTimer(String id) {
    _timers.remove(id)?.cancel();
  }

  // ── 任务触发 ──────────────────────────────────────────────────────────────

  Future<void> _onFire(ScheduledTaskInfo task, {bool updateSchedule = true}) async {
    debugPrint('[Scheduler] Firing "${task.name}" (updateSchedule=$updateSchedule)');

    switch (task.actionType) {
      case TaskActionType.runCommand:
        await _runCommand(task);
      case TaskActionType.aiPrompt:
        _sendAiPrompt(task);
    }

    // 更新 lastRunAt
    final updated = task.copyWith(lastRunAt: DateTime.now());
    await DatabaseTool.shared.upsertScheduledTask(updated);
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) tasks[idx] = updated;

    if (!updateSchedule) return; // triggerNow 不改变计划

    // once 模式：执行后禁用
    if (task.mode == ScheduleMode.once) {
      final disabled = updated.copyWith(isEnabled: false);
      await DatabaseTool.shared.upsertScheduledTask(disabled);
      if (idx != -1) tasks[idx] = disabled;
      return;
    }

    // 重新调度下一次（daily / weekly）
    _scheduleTask(updated);
  }

  Future<void> _runCommand(ScheduledTaskInfo task) async {
    try {
      if (task.autoFillSudoPassword && task.sudoPassword.isNotEmpty) {
        // 通过 stdin 向脚本中的 sudo -S 填入密码
        final process = await Process.start('/bin/sh', ['-c', task.payload]);
        process.stdin.writeln(task.sudoPassword);
        await process.stdin.close();
        final exitCode = await process.exitCode;
        debugPrint('[Scheduler] Command done (exit $exitCode)');
      } else {
        final result = await Process.run(
          '/bin/sh',
          ['-c', task.payload],
          runInShell: false,
        );
        debugPrint(
            '[Scheduler] Command done (exit ${result.exitCode}): ${result.stdout}');
      }
    } catch (e) {
      debugPrint('[Scheduler] Command error: $e');
    }
  }

  void _sendAiPrompt(ScheduledTaskInfo task) {
    try {
      final homeLogic = Get.find<HomeLogic>();
      // 开一个全新 session，避免把任务注入用户正在进行的对话
      homeLogic.newSession();
      // 应用任务级别的执行设置
      homeLogic.allowAllTools.value = task.allowAllTools;
      homeLogic.allowToolDeviation.value = task.allowToolDeviation;
      if (task.skillName != null) homeLogic.setPendingSkill(task.skillName);
      homeLogic.sendMessage('[定时任务] ${task.name}\n\n${task.payload}');
    } catch (_) {
      debugPrint('[Scheduler] HomeLogic not ready yet for aiPrompt task');
    }
  }
}
