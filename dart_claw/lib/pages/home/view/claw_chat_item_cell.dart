import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// AI 助手消息气泡
///
/// 渲染 [ClawChatMessage.blocks] 有序列表，支持多轮 reasoning / content / tool call
/// 依次追加，互不覆盖。每个 reasoning block 独立管理展开/收起状态。
class ClawChatItemCell extends StatefulWidget {
  const ClawChatItemCell({super.key, required this.msg});

  final ClawChatMessage msg;

  @override
  State<ClawChatItemCell> createState() => _ClawChatItemCellState();
}

class _ClawChatItemCellState extends State<ClawChatItemCell> {
  /// index → 用户是否主动覆盖了展开状态（null = 跟随 block.isStreaming 默认行为）
  final Map<int, bool> _expandOverride = {};

  bool _isExpanded(int index, bool blockIsStreaming) =>
      _expandOverride[index] ?? blockIsStreaming;

  void _toggleExpand(int index, bool currentExpanded) {
    setState(() => _expandOverride[index] = !currentExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final isError = msg.status == ClawChatMessageStatus.error;
    final isStreaming = msg.status == ClawChatMessageStatus.streaming;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 显示所有 blocks（顺序渲染）
          if (msg.blocks.isEmpty && isStreaming)
            _loadingDots()
          else
            for (var i = 0; i < msg.blocks.length; i++)
              _buildBlock(msg.blocks[i], i, isError, isStreaming),
        ],
      ),
    );
  }

  Widget _buildBlock(
      ClawChatBlock block, int index, bool isError, bool msgStreaming) {
    return switch (block) {
      ClawReasoningBlock() => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _ReasoningBlock(
            reasoning: block.content,
            isStreaming: block.isStreaming,
            isExpanded: _isExpanded(index, block.isStreaming),
            onToggle: () =>
                _toggleExpand(index, _isExpanded(index, block.isStreaming)),
          ),
        ),
      ClawContentBlock() => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _ContentBubble(
            block: block,
            isError: isError,
          ),
        ),
      ClawToolCallBlock() => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _ToolCallCard(record: block.record),
        ),
    };
  }

  Widget _loadingDots() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content bubble
// ─────────────────────────────────────────────────────────────────────────────

class _ContentBubble extends StatelessWidget {
  const _ContentBubble({required this.block, required this.isError});

  final ClawContentBlock block;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    if (block.content.isEmpty && block.isStreaming) {
      // reasoning 结束但 content 还没开始时，不占空间
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: SelectionArea(
        child: block.isStreaming
            ? GptMarkdown(
                '${block.content}\u258d',
                style: TextStyle(
                  color: isError ? Colors.red[300] : Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              )
            : GptMarkdown(
                block.content,
                style: TextStyle(
                  color: isError ? Colors.red[300] : Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
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
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.reasoningAccent.withOpacity(0.25),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.psychology_outlined,
                    size: 14,
                    color: AppColors.reasoningAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isStreaming ? '思考中…' : '已思考',
                    style: const TextStyle(
                      color: AppColors.reasoningAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.reasoningAccent,
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
    // 高危操作等待确认——内嵌确认卡片
    if (record.status == ClawToolStatus.awaitingConfirmation) {
      return _ConfirmCard(record: record);
    }

    final (statusColor, statusIcon) = _statusStyle(record.status);

    final subtitle = record.args['command'] as String? ??
        record.args['path'] as String? ??
        record.args['pattern'] as String?;

    return Container(
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

// ─────────────────────────────────────────────────────────────────────────────────
// 内嵌确认卡片（高危操作等待用户确认时显示）
// ─────────────────────────────────────────────────────────────────────────────────

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({required this.record});

  final ClawToolCallRecord record;

  @override
  Widget build(BuildContext context) {
    final subtitle = record.args['command'] as String? ??
        record.args['path'] as String? ??
        record.args['pattern'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Colors.amber,
              ),
              const SizedBox(width: 6),
              Text(
                record.name,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          // 参数行
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          // Allow / Deny 按钒
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ConfirmButton(
                label: 'Allow',
                color: AppColors.confirmAllow,
                onTap: () => Get.find<HomeLogic>().confirmTool(
                  record.confirmRequestId!,
                  allow: true,
                ),
              ),
              const SizedBox(width: 8),
              _ConfirmButton(
                label: 'Deny',
                color: Colors.red.shade700,
                onTap: () => Get.find<HomeLogic>().confirmTool(
                  record.confirmRequestId!,
                  allow: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 次级入口：打开 Session Info 面板设置全局放行
          GestureDetector(
            onTap: () => Get.find<HomeLogic>().toggleInfoPanel(),
            child: const Text(
              'Always allow for this session →',
              style: TextStyle(
                fontSize: 11,
                color: Colors.amber,
                decoration: TextDecoration.underline,
                decorationColor: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
