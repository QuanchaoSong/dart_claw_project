import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:dart_claw/pages/home/view/claw_chat_item_cell.dart';
import 'package:dart_claw/pages/home/view/claw_chat_item_subviews/inline_user_input_card_view.dart';
import 'package:dart_claw/pages/home/view/claw_chat_item_subviews/log_line_view.dart';
import 'package:dart_claw/pages/home/view/user_chat_item_cell.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

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
              // ── LLM ask_user 内联输入卡片（Plan B）──
              Obx(() {
                final pending = logic.pendingUserInput.value;
                if (pending == null) return const SizedBox.shrink();
                return InlineUserInputCardView(
                  key: ValueKey(pending.requestId),
                  logic: logic,
                  pending: pending,
                );
              }),
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
          // Compressing badge（上下文压缩进行中）
          Obx(() {
            if (!logic.isCompressing.value) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.teal.withOpacity(0.5), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.teal.shade300,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Compressing…',
                    style: TextStyle(
                      color: Colors.teal.shade300,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
    if (msg.type == ClawChatMessageType.divider) {
      return _ContextDivider(key: ValueKey(msg.id));
    }
    if (msg.type == ClawChatMessageType.log) {
      return LogLineView(key: ValueKey(msg.id), content: msg.content);
    }
    return msg.role == ClawChatMessageRole.user
        ? UserChatItemCell(key: ValueKey(msg.id), msg: msg)
        : ClawChatItemCell(key: ValueKey(msg.id), msg: msg);
  }
}

/// 上下文压缩完成后插入的视觉分隔行
class _ContextDivider extends StatelessWidget {
  const _ContextDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.teal.withOpacity(0.25),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Context compressed',
              style: TextStyle(
                fontSize: 10,
                color: Colors.teal.withOpacity(0.55),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.teal.withOpacity(0.25),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
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
            // ── Attachment chips ──
            Obx(() {
              if (logic.attachedPaths.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: logic.attachedPaths.map((path) {
                    return Tooltip(
                      message: path,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_file,
                                size: 11, color: Colors.white38),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 200),
                              child: Text(
                                p.basename(path),
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () =>
                                  logic.removeAttachedPath(path),
                              child: const Icon(Icons.close,
                                  size: 11, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
            Row(
              children: [
                // ── 附件按钮 ──
                Obx(() {
                  if (logic.isRunning.value) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: '附加文件',
                      child: GestureDetector(
                        onTap: logic.pickFiles,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Icon(Icons.attach_file,
                              size: 16, color: Colors.white38),
                        ),
                      ),
                    ),
                  );
                }),
                // ── 输入框 ──
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
                      minLines: 1,
                      maxLines: 6,
                      enabled: !running,
                      onSubmitted: (_) => logic.submitInput(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // ── 发送/停止按钮 ──
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
