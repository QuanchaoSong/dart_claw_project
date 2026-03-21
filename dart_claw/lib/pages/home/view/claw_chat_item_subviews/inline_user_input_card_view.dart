import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// LLM 调用 ask_user 工具时渲染在聊天区域下方的内联输入卡片（Plan B）。
///
/// 根据 [AskUserRequest.type] 渲染不同控件：
/// - [AskUserType.text]   → 多行文本输入框 + Submit 按钮
/// - [AskUserType.number] → 数字输入框 + Submit 按钮
/// - [AskUserType.choice] → pill 形选项按钮（点击即提交）
class InlineUserInputCardView extends StatefulWidget {
  const InlineUserInputCardView({
    super.key,
    required this.logic,
    required this.pending,
  });

  final HomeLogic logic;
  final PendingUserInput pending;

  @override
  State<InlineUserInputCardView> createState() =>
      _InlineUserInputCardViewState();
}

class _InlineUserInputCardViewState extends State<InlineUserInputCardView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) =>
      widget.logic.respondUserInput(widget.pending.requestId, value);

  void _cancel() =>
      widget.logic.cancelUserInput(widget.pending.requestId);

  @override
  Widget build(BuildContext context) {
    final req = widget.pending.request;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF64D2FF).withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border(
          top: BorderSide(color: const Color(0xFF64D2FF).withOpacity(0.25)),
          left: BorderSide(color: const Color(0xFF64D2FF).withOpacity(0.25)),
          right: BorderSide(color: const Color(0xFF64D2FF).withOpacity(0.25)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 标题行 ──
          Row(
            children: [
              const Icon(Icons.help_outline_rounded,
                  size: 13, color: Color(0xFF64D2FF)),
              const SizedBox(width: 6),
              const Text(
                'Input Required',
                style: TextStyle(
                  color: Color(0xFF64D2FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _cancel,
                child: const Icon(Icons.close, size: 14, color: Colors.white30),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── 问题文本 ──
          Text(
            req.question,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          // ── 输入区域（根据 type 切换）──
          _buildInput(req),
        ],
      ),
    );
  }

  Widget _buildInput(AskUserRequest req) => switch (req.type) {
        AskUserType.choice => _buildChoiceButtons(req.options),
        AskUserType.number => _buildTextField(req, numbersOnly: true),
        AskUserType.text => _buildTextField(req),
      };

  Widget _buildTextField(AskUserRequest req, {bool numbersOnly = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: numbersOnly
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.multiline,
            inputFormatters: numbersOnly
                ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]'))]
                : null,
            maxLines: numbersOnly ? 1 : 4,
            minLines: 1,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: req.hint ??
                  (numbersOnly ? 'Enter a number…' : 'Type your answer…'),
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(
                    color: const Color(0xFF64D2FF).withOpacity(0.5)),
              ),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) _submit(v.trim());
            },
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF64D2FF).withOpacity(0.12),
            foregroundColor: const Color(0xFF64D2FF),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
              side:
                  BorderSide(color: const Color(0xFF64D2FF).withOpacity(0.3)),
            ),
          ),
          onPressed: () {
            final v = _controller.text.trim();
            if (v.isNotEmpty) _submit(v);
          },
          child: const Text('Submit', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildChoiceButtons(List<String> options) {
    if (options.isEmpty) {
      return const Text(
        '(No options provided)',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: options
          .map((opt) => _ChoiceChip(label: opt, onTap: () => _submit(opt)))
          .toList(),
    );
  }
}

// ─── 选项 chip ──────────────────────────────────────────────────────────────

class _ChoiceChip extends StatefulWidget {
  const _ChoiceChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_ChoiceChip> createState() => _ChoiceChipState();
}

class _ChoiceChipState extends State<_ChoiceChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF64D2FF).withOpacity(0.12)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFF64D2FF).withOpacity(0.5)
                  : Colors.white.withOpacity(0.12),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? const Color(0xFF64D2FF) : Colors.white60,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
