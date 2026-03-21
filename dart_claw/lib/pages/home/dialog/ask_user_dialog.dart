import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dart_claw_core/dart_claw_core.dart';

/// LLM 调用 ask_user 工具时弹出的通用输入对话框。
///
/// 根据 [AskUserRequest.type] 渲染不同控件：
/// - [AskUserType.text]   → 自由文本输入框
/// - [AskUserType.choice] → 选项按钮列表
/// - [AskUserType.number] → 数字输入框
///
/// 用户确认后 pop 返回输入字符串；取消则 pop null。
class AskUserDialog extends StatefulWidget {
  const AskUserDialog({super.key, required this.request});

  final AskUserRequest request;

  @override
  State<AskUserDialog> createState() => _AskUserDialogState();
}

class _AskUserDialogState extends State<AskUserDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) => Navigator.of(context).pop(value);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 标题栏 ──
            Row(
              children: [
                const Icon(Icons.help_outline_rounded,
                    size: 15, color: Color(0xFF64D2FF)),
                const SizedBox(width: 8),
                const Text(
                  'Input Required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── 问题文本 ──
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.request.question,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── 输入区域（根据 type 切换）──
            _buildInputArea(),
            const SizedBox(height: 20),
            // ── 按钮行（choice 类型时不显示，选项按钮自带确认语义）──
            if (widget.request.type != AskUserType.choice) _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return switch (widget.request.type) {
      AskUserType.choice => _buildChoiceArea(),
      AskUserType.number => _buildTextField(numbersOnly: true),
      AskUserType.text => _buildTextField(),
    };
  }

  Widget _buildTextField({bool numbersOnly = false}) {
    return TextField(
      controller: _controller,
      autofocus: true,
      keyboardType:
          numbersOnly ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: numbersOnly
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]'))]
          : null,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      maxLines: widget.request.type == AskUserType.text ? 4 : 1,
      minLines: 1,
      decoration: InputDecoration(
        hintText: widget.request.hint ??
            (numbersOnly ? 'Enter a number…' : 'Type your answer…'),
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: const Color(0xFF64D2FF).withOpacity(0.55)),
        ),
      ),
      onSubmitted: (v) {
        if (v.trim().isNotEmpty) _submit(v.trim());
      },
    );
  }

  Widget _buildChoiceArea() {
    final options = widget.request.options;
    if (options.isEmpty) {
      return const Text(
        '(No options provided)',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.indexed
          .map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                  bottom: entry.$1 < options.length - 1 ? 8 : 0),
              child: _ChoiceButton(
                label: entry.$2,
                onTap: () => _submit(entry.$2),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white38),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF64D2FF).withOpacity(0.12),
            foregroundColor: const Color(0xFF64D2FF),
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                  color: const Color(0xFF64D2FF).withOpacity(0.3)),
            ),
          ),
          onPressed: () {
            final v = _controller.text.trim();
            if (v.isNotEmpty) _submit(v);
          },
          child: const Text('Submit', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatefulWidget {
  const _ChoiceButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<_ChoiceButton> {
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
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF64D2FF).withOpacity(0.1)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFF64D2FF).withOpacity(0.4)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? const Color(0xFF64D2FF) : Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
