import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/ask_user_info.dart';

/// LLM 通过 ask_user 工具向用户发问时弹出的输入 Dialog。
///
/// 支持三种模式：
/// - text   → 多行文本输入框
/// - number → 数字输入框
/// - choice → pill 形选项按钮（点击即提交）
///
/// 用户确认后 Navigator.of(context).pop(value)；
/// 用户取消则 pop null（调用方应将 null 视为取消）。
class AskUserDialog extends StatefulWidget {
  const AskUserDialog({super.key, required this.info});

  final AskUserInfo info;

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
    final req = widget.info;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                const Icon(Icons.question_answer_rounded,
                    color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'AI 需要您的输入',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(null),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white38, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 问题文字
            Text(
              req.question,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            // 输入区域
            _buildInput(req),
            // 非 choice 时的确认/取消按钮
            if (req.type != 'choice') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('取消',
                        style: TextStyle(color: Colors.white38)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _submit(_controller.text.trim()),
                    child: const Text('提交',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput(AskUserInfo req) {
    return switch (req.type) {
      'choice' => _buildChoiceButtons(req.options),
      'number' => _buildTextField(req, numbersOnly: true),
      _ => _buildTextField(req),
    };
  }

  Widget _buildTextField(AskUserInfo req, {bool numbersOnly = false}) {
    return TextField(
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
        hintText: req.hint ?? (numbersOnly ? '输入数字…' : '输入回答…'),
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.amber),
        ),
      ),
      onSubmitted: numbersOnly ? _submit : null,
    );
  }

  Widget _buildChoiceButtons(List<String> options) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        return GestureDetector(
          onTap: () => _submit(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Text(
              opt,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        );
      }).toList(),
    );
  }
}
