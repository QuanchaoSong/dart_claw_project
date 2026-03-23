import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../sessions/sessions_drawer_view.dart';
import 'chat_logic.dart';
import 'view/input_area_view.dart';
import 'view/message_list_view.dart';

class ChatPage extends StatelessWidget {
  ChatPage({super.key});

  final logic = Get.put(ChatLogic());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const SessionsDrawerView(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Obx(() => Text(logic.currentSessionTitle.value)),
        actions: [
          Obx(() => logic.isRunning.value
              ? IconButton(
                  icon: const Icon(Icons.stop_circle_outlined,
                      color: Colors.redAccent),
                  tooltip: '停止',
                  onPressed: logic.stopRunning,
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: Column(
        children: [
          const Divider(color: Colors.white12, height: 1),
          const Expanded(child: MessageListView()),
          const Divider(color: Colors.white12, height: 1),
          InputAreaView(),
        ],
      ),
    );
  }
}

