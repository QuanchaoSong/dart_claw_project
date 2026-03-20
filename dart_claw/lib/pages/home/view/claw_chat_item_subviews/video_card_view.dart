import 'dart:io';

import 'package:dart_claw/pages/home/view/claw_chat_item_subviews/video_full_screen_view.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoCardView extends StatefulWidget {
  const VideoCardView({super.key, required this.record});

  final ClawToolCallRecord record;

  @override
  State<VideoCardView> createState() => _VideoCardViewState();
}

class _VideoCardViewState extends State<VideoCardView> {
  // ── Source parsing ─────────────────────────────────────────────────────

  String get _source {
    final result = widget.record.result ?? '';
    const prefix = '[video displayed:';
    if (result.startsWith(prefix) && result.endsWith(']')) {
      return result.substring(prefix.length, result.length - 1);
    }
    // Fallback to args.
    return widget.record.args['path'] as String? ?? '';
  }

  bool get _isUrl {
    final s = _source;
    return s.startsWith('http://') || s.startsWith('https://');
  }

  // ── Thumbnail ──────────────────────────────────────────────────────────

  String? _thumbPath;
  bool _thumbLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.record.status == ClawToolStatus.success) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    final src = _source;
    if (src.isEmpty || _isUrl || !Platform.isMacOS) return;

    setState(() => _thumbLoading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final hash = src.hashCode.abs();
      final thumbDirPath = p.join(tempDir.path, 'dc_vid_$hash');
      await Directory(thumbDirPath).create(recursive: true);

      // qlmanage -t generates a Quick Look thumbnail.
      // Output: <thumbDirPath>/<basename>.png
      await Process.run(
        'qlmanage',
        ['-t', '-s', '640', '-o', thumbDirPath, src],
      );

      final thumbFile = File(p.join(thumbDirPath, '${p.basename(src)}.png'));
      final exists = await thumbFile.exists();
      if (mounted) {
        setState(() {
          _thumbPath = exists ? thumbFile.path : null;
          _thumbLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _thumbLoading = false);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────

  void _openOrReveal() {
    final src = _source;
    if (src.isEmpty) return;
    if (_isUrl) {
      launchUrl(Uri.parse(src));
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', src]);
    } else if (Platform.isWindows) {
      Process.run('explorer', ['/select,', src]);
    } else {
      launchUrl(Uri.file(src));
    }
  }

  void _openFullScreen() {
    final src = _source;
    if (src.isEmpty) return;
    VideoFullScreenView.show(context, src);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: switch (widget.record.status) {
        ClawToolStatus.pending || ClawToolStatus.running => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(radius: 7),
                SizedBox(width: 8),
                Text('Loading video…',
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
                const Icon(Icons.videocam_off_outlined,
                    size: 14, color: Colors.red),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.record.result ?? 'Failed to load video',
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
    final src = _source;
    final fileName = _isUrl ? src : p.basename(src);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Thumbnail area ───────────────────────────────────────────
        GestureDetector(
          onTap: _openFullScreen,
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnailContent(),
                  // Semi-transparent play overlay
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white38, width: 1.5),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 34),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // ── Bottom bar: filename + action buttons ────────────────────
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.movie_outlined,
                  size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              // Reveal / open-in-browser button
              Tooltip(
                message: _isUrl ? '在浏览器中打开' : '在 Finder 中显示',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _openOrReveal,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _isUrl ? Icons.open_in_browser : Icons.folder_open,
                      size: 16,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Fullscreen play button
              Tooltip(
                message: '全屏播放',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _openFullScreen,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.open_in_full,
                        size: 16, color: Colors.white38),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailContent() {
    // URL source — no thumbnail, show placeholder.
    if (_isUrl) return _placeholder(Icons.language);

    if (_thumbLoading) {
      return Container(
        color: Colors.black,
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_thumbPath != null) {
      return Image.file(
        File(_thumbPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(Icons.videocam_outlined),
      );
    }

    return _placeholder(Icons.videocam_outlined);
  }

  Widget _placeholder(IconData icon) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Icon(icon, size: 40, color: Colors.white24),
      ),
    );
  }
}
