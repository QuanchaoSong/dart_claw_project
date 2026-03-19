import 'dart:io';

import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ImageCardView extends StatelessWidget {
  const ImageCardView({super.key, required this.record});

  final ClawToolCallRecord record;

  // ── Result parsing ──────────────────────────────────────────────────────

  /// Extracts resolved paths from the tool result string.
  /// Single local  → '[image displayed:/path]'
  /// Single URL    → '[image displayed]' (fall back to args)
  /// Multi         → '[images displayed:/p1|https://url|/p2]'
  List<String> _resolvedPaths() {
    final result = record.result ?? '';

    const multiPrefix = '[images displayed:';
    if (result.startsWith(multiPrefix) && result.endsWith(']')) {
      final inner = result.substring(multiPrefix.length, result.length - 1);
      return inner.split('|').where((s) => s.isNotEmpty).toList();
    }

    const singlePrefix = '[image displayed:';
    if (result.startsWith(singlePrefix) && result.endsWith(']')) {
      final path = result.substring(singlePrefix.length, result.length - 1);
      return [path];
    }

    // URL case (result = '[image displayed]') or legacy: fall back to args.
    final pathsArg = record.args['paths'];
    if (pathsArg is List && pathsArg.isNotEmpty) {
      return pathsArg.cast<String>();
    }
    final single = record.args['path'] as String? ?? '';
    return single.isEmpty ? [] : [single];
  }

  // ── Image builder ───────────────────────────────────────────────────────

  Widget _buildSingleImage(String path) {
    final isUrl = path.startsWith('http://') || path.startsWith('https://');
    final img = isUrl
        ? Image.network(path, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _errorText('Failed to load image'))
        : Image.file(File(path), fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _errorText('Failed to load image'));
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: img);
  }

  Widget _errorText(String msg) => Padding(
        padding: const EdgeInsets.all(12),
        child:
            Text(msg, style: const TextStyle(color: Colors.red, fontSize: 12)),
      );

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: switch (record.status) {
        ClawToolStatus.pending || ClawToolStatus.running => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(radius: 7),
                SizedBox(width: 8),
                Text('Loading image…',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ClawToolStatus.success => _buildSuccess(),
        _ => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_outlined,
                    size: 14, color: Colors.red),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    record.result ?? 'Failed to load image',
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontFamily: 'monospace'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      },
    );
  }

  Widget _buildSuccess() {
    final paths = _resolvedPaths();
    if (paths.isEmpty) return _errorText('No image path');
    if (paths.length == 1) return _buildSingleImage(paths.first);
    return _Carousel(paths: paths);
  }
}

// ── Carousel（多图轮播）─────────────────────────────────────────────────────

class _Carousel extends StatefulWidget {
  const _Carousel({required this.paths});
  final List<String> paths;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  late final PageController _controller;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_current + delta).clamp(0, widget.paths.length - 1);
    _controller.animateToPage(next,
        duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  Widget _buildImage(String path) {
    final isUrl = path.startsWith('http://') || path.startsWith('https://');
    return isUrl
        ? Image.network(path, fit: BoxFit.contain)
        : Image.file(File(path), fit: BoxFit.contain);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.paths.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 图片页 ──
          SizedBox(
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: count,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (_, i) => _buildImage(widget.paths[i]),
                ),
                // 左箭头
                if (_current > 0)
                  Positioned(
                    left: 8,
                    child: _ArrowButton(
                        icon: Icons.chevron_left, onTap: () => _go(-1)),
                  ),
                // 右箭头
                if (_current < count - 1)
                  Positioned(
                    right: 8,
                    child: _ArrowButton(
                        icon: Icons.chevron_right, onTap: () => _go(1)),
                  ),
              ],
            ),
          ),
          // ── 指示点 + 计数 ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...List.generate(
                  count,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _current ? 14 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _current
                          ? Colors.white70
                          : Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_current + 1} / $count',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }
}

