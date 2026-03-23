import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 手机端内联视频播放卡片，使用 media_kit 播放网络(HTTP)视频。
class VideoCardView extends StatefulWidget {
  const VideoCardView({super.key, required this.url});

  /// 视频 URL（由桌面端 /video HTTP 路由提供）
  final String url;

  @override
  State<VideoCardView> createState() => _VideoCardViewState();
}

class _VideoCardViewState extends State<VideoCardView> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.url), play: false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Video(
          controller: _controller,
          controls: AdaptiveVideoControls,
        ),
      ),
    );
  }
}
