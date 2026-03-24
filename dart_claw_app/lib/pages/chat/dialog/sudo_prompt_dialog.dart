import 'package:flutter/material.dart';

/// 桌面端请求 sudo 密码时弹出的密码输入 Dialog（移动端）。
///
/// 密码通过 Navigator.pop(password) 返回；
/// 取消则 pop null。
class SudoPromptDialog extends StatefulWidget {
  const SudoPromptDialog({super.key, required this.promptText});

  /// 桌面端传来的系统提示文字（如 "Password for user@host:"）
  final String promptText;

  @override
  State<SudoPromptDialog> createState() => _SudoPromptDialogState();
}

class _SudoPromptDialogState extends State<SudoPromptDialog> {
  final _controller = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final pwd = _controller.text;
    if (pwd.isEmpty) return;
    Navigator.of(context).pop(pwd);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
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
                const Icon(Icons.lock_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'sudo 密码请求',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 桌面端传来的提示文字
            if (widget.promptText.isNotEmpty)
              Text(
                widget.promptText,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12, height: 1.4),
              ),
            const SizedBox(height: 16),
            // 密码输入框
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '输入密码…',
                hintStyle:
                    const TextStyle(color: Colors.white30, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.amber),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white38,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
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
                  onPressed: _submit,
                  child: const Text('发送',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
