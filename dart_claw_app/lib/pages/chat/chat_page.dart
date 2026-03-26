import 'package:dart_claw_app/others/tool/global_tool.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../sessions/sessions_drawer_page.dart';
import 'chat_logic.dart';
import 'view/input_area_view.dart';
import 'view/message_list_view.dart';
import 'view/session_info_and_settings_view.dart';

class ChatPage extends StatelessWidget {
  ChatPage({super.key});

  final logic = Get.put(ChatLogic());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const SessionsDrawerPage(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Obx(() => Text(logic.currentSessionTitle.value)),
        actions: [
          // 停止按钮：仅在运行中显示，位于 Info 按钮左侧
          Obx(() => logic.isRunning.value
              ? IconButton(
                  icon: const Icon(Icons.stop_circle_outlined,
                      color: Colors.redAccent),
                  tooltip: '停止',
                  onPressed: logic.stopRunning,
                )
              : const SizedBox.shrink()),
          // Info 面板入口：始终显示在最右侧
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white54),
            tooltip: 'Session Info',
            onPressed: () => showSessionInfoAndSettingsView(context),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => hideKeyboard(context),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            const Divider(color: Colors.white12, height: 1),
            const Expanded(child: MessageListView()),
            const Divider(color: Colors.white12, height: 1),
            InputAreaView(),
          ],
        ),
      ),
    );
  }
}

