import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:dart_claw/pages/home/view/claw_chat_item_cell.dart';
import 'package:dart_claw/pages/home/view/user_chat_item_cell.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatAreaView extends StatelessWidget {
  const ChatAreaView({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<HomeLogic>();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
              _TopBar(logic: logic),
              const Divider(color: Colors.white12, height: 1),
              _MessageList(logic: logic),
              const Divider(color: Colors.white12, height: 1),
              _InputArea(logic: logic),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 顶部标题栏 ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.logic});

  final HomeLogic logic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
          ),
          // Pending skill chip（已选但未发送，虚线风格）
          Obx(() {
            final pending = logic.pendingSkillName.value;
            if (pending == null) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () => logic.setPendingSkill(null),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border(
                    top: BorderSide(color: Colors.orange.withOpacity(0.45), width: 1),
                    bottom: BorderSide(color: Colors.orange.withOpacity(0.45), width: 1),
                    left: BorderSide(color: Colors.orange.withOpacity(0.45), width: 1),
                    right: BorderSide(color: Colors.orange.withOpacity(0.45), width: 1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 11, color: Colors.orange),
                    const SizedBox(width: 3),
                    Text(
                      pending,
                      style: TextStyle(
                        color: Colors.orange.withOpacity(0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.close_rounded, size: 10, color: Colors.orange.withOpacity(0.7)),
                  ],
                ),
              ),
            );
          }),
          // Active skill badge（执行中，实线风格）
          Obx(() {
            final skill = logic.activeSkillName.value;
            if (skill == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.orange.withOpacity(0.6), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_fix_high_rounded,
                      size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    skill,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(width: 5),
          Obx(() {
            final hasAllowAll = logic.allowAllTools.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    color: hasAllowAll ? Colors.amber : Colors.white54,
                  ),
                  onPressed: logic.toggleInfoPanel,
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
    );
  }
}

// ─── 消息列表 ─────────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({required this.logic});

  final HomeLogic logic;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Obx(() {
        if (logic.messages.isEmpty) {
          return const Center(
            child: Text('No messages yet',
                style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.builder(
          controller: logic.scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: logic.messages.length,
          itemBuilder: (_, i) => _buildBubble(logic.messages[i]),
        );
      }),
    );
  }

  Widget _buildBubble(ClawChatMessage msg) {
    return msg.role == ClawChatMessageRole.user
        ? UserChatItemCell(key: ValueKey(msg.id), msg: msg)
        : ClawChatItemCell(key: ValueKey(msg.id), msg: msg);
  }
}

// ─── 输入区域 ─────────────────────────────────────────────────────────────────

class _InputArea extends StatelessWidget {
  const _InputArea({required this.logic});

  final HomeLogic logic;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final running = logic.isRunning.value;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 输入框
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            Colors.white.withOpacity(running ? 0.05 : 0.1),
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
                // 发送/停止按钮
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: running
                          ? const [
                              AppColors.stopBgStart,
                              AppColors.stopBgEnd
                            ]
                          : AppColors.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      running ? Icons.stop_rounded : Icons.send,
                      color:
                          running ? Colors.red.shade300 : Colors.white,
                    ),
                    onPressed:
                        running ? logic.stopAgent : logic.submitInput,
                    tooltip: running ? 'Stop' : 'Send',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
