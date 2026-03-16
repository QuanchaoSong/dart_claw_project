import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:dart_claw/pages/settings/settings_page.dart';
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
            colors: [Color(0xFF0A0E27), Color(0xFF1A1F3A), Color(0xFF0F1729)],
          ),
        ),
        child: Row(
          children: [
            // 左侧边栏
            _buildSidebar(context),

            // 中间聊天区
            Expanded(child: _buildChatArea()),

            // 右侧信息面板
            Obx(
              () => logic.showInfoPanel.value
                  ? _buildInfoPanel()
                  : SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      margin: EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              // 顶部标题区域
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🦞 dart Claw',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'AI Assistant',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),

              Divider(color: Colors.white12),

              // 会话列表区域（占位）
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: index == 0
                            ? Colors.white.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Session ${index + 1}',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  },
                ),
              ),

              Divider(color: Colors.white12),

              // 底部按钮区域
              Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.add,
                        label: 'New',
                        onTap: () {},
                      ),
                    ),
                    SizedBox(width: 8),
                    _buildIconButton(
                      icon: Icons.settings,
                      onTap: () => openSettings(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                    Text(
                      'Current Session',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.info_outline, color: Colors.white54),
                      onPressed: () => logic.toggleInfoPanel(),
                    ),
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
                                ? const [Color(0xFF2D2D4E), Color(0xFF2D2D4E)]
                                : const [
                                    Color(0xFF6366F1),
                                    Color(0xFF8B5CF6)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            running ? Icons.hourglass_empty : Icons.send,
                            color:
                                running ? Colors.white38 : Colors.white,
                          ),
                          onPressed: running ? null : logic.submitInput,
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

  Widget _buildInfoPanel() {
    return Container(
      width: 280,
      margin: EdgeInsets.only(right: 16, top: 16, bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Info',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => logic.toggleInfoPanel(),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoItem('Model', logic.currentModelId),
                    _buildInfoItem('Tokens', '—'),
                    _buildInfoItem(
                      'Status',
                      logic.isRunning.value ? 'Thinking…' : 'Ready',
                    ),
                  ],
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white54)),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            SizedBox(width: 6),
            Text(label, style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Icon(icon, size: 18, color: Colors.white70),
      ),
    );
  }

  // ─── 消息气泡 ──────────────────────────────────────────────────────────────

  Widget _buildMessageBubble(ClawChatMessage msg) {
    return msg.role == ClawChatMessageRole.user
        ? _buildUserBubble(msg)
        : _buildAssistantBubble(msg);
  }

  Widget _buildUserBubble(ClawChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                msg.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(ClawChatMessage msg) {
    final isStreaming = msg.status == ClawChatMessageStatus.streaming;
    final isError = msg.status == ClawChatMessageStatus.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 60),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('🦞', style: TextStyle(fontSize: 16)),
            ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isError
                        ? Colors.red.withOpacity(0.12)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(
                      color: isError
                          ? Colors.red.withOpacity(0.3)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: isStreaming && msg.content.isEmpty
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            3,
                            (_) => Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: const BoxDecoration(
                                color: Colors.white38,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          isStreaming ? '${msg.content}▍' : msg.content,
                          style: TextStyle(
                            color: isError ? Colors.red[300] : Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                ),
                if (msg.toolCalls.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final tc in msg.toolCalls) _buildToolCallCard(tc),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCallCard(ClawToolCallRecord record) {
    final Color statusColor;
    final IconData statusIcon;
    switch (record.status) {
      case ClawToolStatus.success:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
      case ClawToolStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
      case ClawToolStatus.running:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
      case ClawToolStatus.awaitingConfirmation:
        statusColor = Colors.amber;
        statusIcon = Icons.warning_amber_outlined;
      case ClawToolStatus.pending:
        statusColor = Colors.white54;
        statusIcon = Icons.schedule;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: statusColor.withOpacity(0.9)),
          const SizedBox(width: 8),
          Text(
            record.name,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
