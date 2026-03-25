import 'package:flutter/material.dart';

import '../../model/remote_message_info.dart';
import 'chart_card_view.dart';
import 'file_info_view.dart';
import 'video_card_view.dart';

class ToolCardView extends StatelessWidget {
  const ToolCardView({super.key, required this.msg});
  final RemoteMessageInfo msg;

  @override
  Widget build(BuildContext context) {
    final isActive =
        msg.toolStatus == 'running' || msg.toolStatus == 'pending';
    final (icon, iconColor) = switch (msg.toolStatus) {
      'success' => (Icons.check_circle_outline, Colors.greenAccent),
      'error' => (Icons.error_outline, Colors.redAccent),
      'awaitingConfirmation' => (Icons.help_outline, Colors.orangeAccent),
      _ => (Icons.settings_outlined, Colors.white38),
    };

    final showImages = msg.toolName == 'show_image' &&
        msg.toolStatus == 'success' &&
        msg.imagePaths.isNotEmpty;

    final showVideo = msg.toolName == 'show_video' &&
        msg.toolStatus == 'success' &&
        msg.videoUrl != null;

    final showChart = msg.toolName == 'show_chart' &&
        msg.toolStatus == 'success' &&
        msg.chartData != null;

    final showFile = msg.toolName == 'show_file' &&
        msg.toolStatus == 'success' &&
        msg.fileInfo != null;

    // relay 模式下大文件被延迟传输
    final showDeferred = msg.toolStatus == 'success' && msg.isRelayDeferred;

    final hasSubview =
        showImages || showVideo || showChart || showFile || showDeferred;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 工具状态行 ──────────────────────────────────
        Container(
          margin: EdgeInsets.only(bottom: hasSubview ? 0 : 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(10),
              bottom: hasSubview ? Radius.zero : const Radius.circular(10),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isActive
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white38),
                      ))
                  : Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(msg.toolName ?? '',
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontFamily: 'monospace')),
              if (msg.content.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(msg.content,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
        ),
        // ── 图片轮播（仅 show_image 成功时）────────────
        if (showImages)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10)),
              border: Border(
                left: BorderSide(color: Colors.white.withOpacity(0.07)),
                right: BorderSide(color: Colors.white.withOpacity(0.07)),
                bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
              ),
            ),
        child: msg.imagePaths.length == 1
                ? _RemoteImage(url: msg.imagePaths.first)
                : _ImageCarousel(paths: msg.imagePaths),
          ),        // ── 视频播放卡片（仅 show_video 成功时）───────────────────────
        if (showVideo)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10)),
              border: Border(
                left: BorderSide(color: Colors.white.withOpacity(0.07)),
                right: BorderSide(color: Colors.white.withOpacity(0.07)),
                bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
              ),
            ),
            child: VideoCardView(url: msg.videoUrl!),
          ),
        // ── 图表卡片（仅 show_chart 成功时）──────────────────────────────────
        if (showChart)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10)),
              border: Border(
                left: BorderSide(color: Colors.white.withOpacity(0.07)),
                right: BorderSide(color: Colors.white.withOpacity(0.07)),
                bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
              ),
            ),
            child: ChartCardView(data: msg.chartData!),
          ),
        // ── 文件下载卡片（仅 show_file 成功时）────────────────────────────────
        if (showFile)
          Builder(builder: (_) {
            final info = msg.fileInfo!;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10)),
                border: Border(
                  left: BorderSide(color: Colors.white.withOpacity(0.07)),
                  right: BorderSide(color: Colors.white.withOpacity(0.07)),
                  bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
                ),
              ),
              child: FileInfoView(
                url: info['url'] as String,
                name: info['name'] as String,
                size: info['size'] as int,
                description: info['description'] as String?,
              ),
            );
          }),
        // ── 中继延迟文件卡片 ─────────────────────────────────────────────
        if (showDeferred && !showImages && !showVideo && !showFile)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border(
                left: BorderSide(color: Colors.white.withOpacity(0.07)),
                right: BorderSide(color: Colors.white.withOpacity(0.07)),
                bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 20, color: Colors.orangeAccent.withOpacity(0.7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (msg.deferredFileName.isNotEmpty)
                        Text(
                          msg.deferredFileName,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        '文件较大，回到同一网络后可查看',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── 单张图片 ──────────────────────────────────────────────────────────────────

class _RemoteImage extends StatelessWidget {
  const _RemoteImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const SizedBox(
                height: 120,
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 1.5))),
        errorBuilder: (_, __, ___) => const Padding(
          padding: EdgeInsets.all(12),
          child: Text('图片加载失败',
              style: TextStyle(color: Colors.red, fontSize: 12)),
        ),
      ),
    );
  }
}

// ── 多图轮播 ──────────────────────────────────────────────────────────────────

class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({required this.paths});
  final List<String> paths;
  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  late final PageController _ctrl = PageController();
  int _current = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.paths.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 260,
          child: Stack(
            children: [
              PageView.builder(
                controller: _ctrl,
                itemCount: total,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: i == total - 1
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(10))
                      : BorderRadius.zero,
                  child: Image.network(
                    widget.paths[i],
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5)),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('加载失败',
                          style:
                              TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ),
                ),
              ),
              // 左右切换箭头
              if (_current > 0)
                Positioned(
                  left: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _Arrow(left: true, onTap: () {
                    _ctrl.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut);
                  })),
                ),
              if (_current < total - 1)
                Positioned(
                  right: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _Arrow(left: false, onTap: () {
                    _ctrl.nextPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut);
                  })),
                ),
            ],
          ),
        ),
        // 指示点 + 计数
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _current ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _current
                        ? Colors.white
                        : Colors.white30,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 10),
              Text('${_current + 1} / $total',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.left, required this.onTap});
  final bool left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          left ? Icons.chevron_left : Icons.chevron_right,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

