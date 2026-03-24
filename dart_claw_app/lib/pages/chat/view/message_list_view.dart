import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../model/remote_message_info.dart';
import '../chat_logic.dart';
import 'claw_chat_item_cell.dart';
import 'claw_chat_item_subviews/confirm_card_view.dart';
import 'claw_chat_item_subviews/log_line_view.dart';
import 'claw_chat_item_subviews/tool_card_view.dart';
import 'user_bubble_view.dart';

class MessageListView extends StatelessWidget {
  const MessageListView({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<ChatLogic>();
    return Obx(() {
      if (logic.messages.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🦞', style: TextStyle(fontSize: 40)),
              SizedBox(height: 12),
              Text(
                '开始一个新对话吧',
                style: TextStyle(color: Colors.white24, fontSize: 14),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        controller: logic.scrollController,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        itemCount: logic.messages.length,
        itemBuilder: (ctx, i) {
          final msg = logic.messages[i];
          return switch (msg.type) {
            RemoteMessageInfoType.user => UserBubbleView(msg: msg),
            RemoteMessageInfoType.assistant => AssistantBubbleView(msg: msg),
            RemoteMessageInfoType.tool => ToolCardView(msg: msg),
            RemoteMessageInfoType.confirm =>
              ConfirmCardView(msg: msg, logic: logic),
            RemoteMessageInfoType.log => LogLineView(msg: msg),
          };
        },
      );
    });
  }
}
