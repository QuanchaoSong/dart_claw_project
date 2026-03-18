import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:dart_claw/pages/home/view/claw_chat_item_cell.dart';
import 'package:dart_claw/pages/home/view/session_info_and_settings_view.dart';
import 'package:dart_claw/pages/home/view/session_sidebar_view.dart';
import 'package:dart_claw/pages/home/view/user_chat_item_cell.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final logic = Get.put(HomeLogic());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(          
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bgDeep, AppColors.bgMid, AppColors.bgSurface],
          ),
        ),
        child: Row(
          children: [
            // 左侧边栏
            const SessionSidebarView(),

            // 中间聊天区
            Expanded(child: _buildChatArea()),

            // 右侧信息面板
            Obx(
              () => logic.showInfoPanel.value
                  ? const SessionInfoAndSettingsView()
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: [
              // 顶部栏
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Obx(() => Text(
                        logic.currentSessionTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ),
                    const SizedBox(width: 5),
                    Obx(() {
                      final hasAllowAll = logic.allowAllTools.value;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.info_outline,
                              color: hasAllowAll
                                  ? Colors.amber
                                  : Colors.white54,
                            ),
                            onPressed: () => logic.toggleInfoPanel(),
                          ),
                          if (hasAllowAll)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              Divider(color: Colors.white12, height: 1),

              // 消息列表
              Expanded(
                child: Obx(() {
                  if (logic.messages.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.white38),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: logic.scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: logic.messages.length,
                    itemBuilder: (_, i) =>
                        _buildMessageBubble(logic.messages[i]),
                  );
                }),
              ),

              Divider(color: Colors.white12, height: 1),

              // 输入框区域
              Obx(() {
                final running = logic.isRunning.value;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white
                                  .withOpacity(running ? 0.05 : 0.1),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: logic.inputController,
                            focusNode: logic.inputFocusNode,
                            style: const TextStyle(color: Colors.white),                            
                            decoration: InputDecoration(
                              hintText: running
                                  ? 'Thinking...'
                                  : 'Type your message...',
                              hintStyle:
                                  const TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            maxLines: null,
                            enabled: !running,
                            onSubmitted: (_) => logic.submitInput(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: running
                                ? const [AppColors.stopBgStart, AppColors.stopBgEnd]
                                : AppColors.primaryGradient,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            running ? Icons.stop_rounded : Icons.send,
                            color: running
                                ? Colors.red.shade300
                                : Colors.white,
                          ),
                          onPressed:
                              running ? logic.stopAgent : logic.submitInput,
                          tooltip: running ? 'Stop' : 'Send',
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 消息气泡 ──────────────────────────────────────────────────────────────

  Widget _buildMessageBubble(ClawChatMessage msg) {
    return msg.role == ClawChatMessageRole.user
        ? UserChatItemCell(key: ValueKey(msg.id), msg: msg)
        : ClawChatItemCell(key: ValueKey(msg.id), msg: msg);
  }
}
