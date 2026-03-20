import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Full-screen (dialog) video player powered by media_kit.
///
/// Open via [VideoFullScreenView.show].
class VideoFullScreenView extends StatefulWidget {
  const VideoFullScreenView._({required this.source});

  /// [source] is either an absolute local file path or an http/https URL.
  final String source;

  static Future<void> show(BuildContext context, String source) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => VideoFullScreenView._(source: source),
    );
  }

  @override
  State<VideoFullScreenView> createState() => _VideoFullScreenViewState();
}

class _VideoFullScreenViewState extends State<VideoFullScreenView> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    final src = widget.source;
    final media = (src.startsWith('http://') || src.startsWith('https://'))
        ? Media(src)
        : Media('file://$src');
    _player.open(media);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.05,
        vertical: screenSize.height * 0.05,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: screenSize.width * 0.9,
        height: screenSize.height * 0.85,
        child: Column(
          children: [
            // ── Title bar ──────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline,
                      size: 16, color: Colors.white54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _displayName(widget.source),
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            // ── Video widget ───────────────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Video(
                  controller: _controller,
                  controls: MaterialDesktopVideoControls,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return source;
    }
    return source.split('/').last;
  }
}
