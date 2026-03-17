import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/material.dart';

/// AI 助手消息气泡，包含：
/// - 可折叠的 reasoning（思考）区块
/// - 正文内容
/// - 工具调用卡片列表
class ClawChatItemCell extends StatefulWidget {
  const ClawChatItemCell({super.key, required this.msg});

  final ClawChatMessage msg;

  @override
  State<ClawChatItemCell> createState() => _ClawChatItemCellState();
}

class _ClawChatItemCellState extends State<ClawChatItemCell> {
  bool _reasoningExpanded = true;
  bool _userToggledReasoning = false;

  @override
  void didUpdateWidget(ClawChatItemCell old) {
    super.didUpdateWidget(old);
    // 流式结束后自动折叠，除非用户主动点击过
    if (!_userToggledReasoning) {
      final nowStreaming =
          widget.msg.status == ClawChatMessageStatus.streaming;
      if (_reasoningExpanded != nowStreaming) {
        setState(() => _reasoningExpanded = nowStreaming);
      }
    }
  }

  void _toggleReasoning() {
    setState(() {
      _userToggledReasoning = true;
      _reasoningExpanded = !_reasoningExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
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
                // ── Reasoning 折叠块 ──────────────────────────────────────
                if (msg.reasoningContent.isNotEmpty)
                  _ReasoningBlock(
                    reasoning: msg.reasoningContent,
                    isStreaming: isStreaming,
                    isExpanded: _reasoningExpanded,
                    onToggle: _toggleReasoning,
                  ),

                // ── 正文气泡 ──────────────────────────────────────────────
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
                  child: _buildMainContent(msg, isStreaming, isError),
                ),

                // ── 工具调用卡片 ──────────────────────────────────────────
                if (msg.toolCalls.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final tc in msg.toolCalls) _ToolCallCard(record: tc),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
      ClawChatMessage msg, bool isStreaming, bool isError) {
    // 只有在完全没有任何内容时才显示三点 loading
    if (isStreaming &&
        msg.content.isEmpty &&
        msg.reasoningContent.isEmpty) {
      return Row(
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
      );
    }
    // reasoning 流式阶段 content 还是空 → 不占空间
    if (msg.content.isEmpty && isStreaming) {
      return const SizedBox.shrink();
    }
    return Text(
      isStreaming ? '${msg.content}▍' : msg.content,
      style: TextStyle(
        color: isError ? Colors.red[300] : Colors.white,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 可折叠 Reasoning 区块
// ─────────────────────────────────────────────────────────────────────────────

class _ReasoningBlock extends StatelessWidget {
  const _ReasoningBlock({
    required this.reasoning,
    required this.isStreaming,
    required this.isExpanded,
    required this.onToggle,
  });

  final String reasoning;
  final bool isStreaming;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行（始终可见）
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.psychology_outlined,
                    size: 14,
                    color: Color(0xFF818CF8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isStreaming ? '思考中…' : '已思考',
                    style: const TextStyle(
                      color: Color(0xFF818CF8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: const Color(0xFF818CF8),
                  ),
                ],
              ),
            ),
          ),
          // 动画展开/收起内容
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  reasoning,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.55,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 工具调用状态卡片
// ─────────────────────────────────────────────────────────────────────────────

class _ToolCallCard extends StatelessWidget {
  const _ToolCallCard({required this.record});

  final ClawToolCallRecord record;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon) = _statusStyle(record.status);

    final subtitle = record.args['command'] as String? ??
        record.args['path'] as String? ??
        record.args['pattern'] as String?;

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
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static (Color, IconData) _statusStyle(ClawToolStatus status) =>
      switch (status) {
        ClawToolStatus.success => (Colors.green, Icons.check_circle_outline),
        ClawToolStatus.error => (Colors.red, Icons.error_outline),
        ClawToolStatus.running => (Colors.orange, Icons.sync),
        ClawToolStatus.awaitingConfirmation =>
          (Colors.amber, Icons.warning_amber_outlined),
        ClawToolStatus.pending => (Colors.white54, Icons.schedule),
      };
}
