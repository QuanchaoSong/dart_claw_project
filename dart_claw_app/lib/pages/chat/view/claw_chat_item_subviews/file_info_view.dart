import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 文件信息卡片 — show_file 工具成功时渲染。
///
/// 显示文件图标、名称、大小；
/// 下载按钮使用弧形进度指示（从 0° 扫至 360° 即满圆）；
/// 下载完成后变为"分享/存储"按钮（系统分享栏：iOS 可选存储到文件，Android 可选任意应用）。
class FileInfoView extends StatefulWidget {
  const FileInfoView({
    super.key,
    required this.url,
    required this.name,
    required this.size,
    this.description,
  });

  final String url;
  final String name;

  /// 文件大小（字节），用于计算下载进度。0 表示未知。
  final int size;

  /// 可选说明文字（来自 show_file 工具的 description 参数）
  final String? description;

  @override
  State<FileInfoView> createState() => _FileInfoViewState();
}

class _FileInfoViewState extends State<FileInfoView> {
  double _progress = 0; // 0.0 ~ 1.0
  bool _downloading = false;
  bool _downloaded = false;
  String? _localPath;
  String? _errorMsg;

  // ── 辅助计算 ────────────────────────────────────────────────────────────────

  String get _sizeLabel {
    final s = widget.size;
    if (s <= 0) return '';
    if (s < 1024) return '$s B';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(1)} KB';
    if (s < 1024 * 1024 * 1024) {
      return '${(s / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(s / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String get _ext =>
      widget.name.contains('.') ? widget.name.split('.').last.toLowerCase() : '';

  IconData get _fileIcon => switch (_ext) {
        'pdf' => Icons.picture_as_pdf_rounded,
        'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'bmp' =>
          Icons.image_rounded,
        'mp4' || 'mov' || 'avi' || 'mkv' || 'webm' || 'm4v' =>
          Icons.video_file_rounded,
        'mp3' || 'wav' || 'aac' || 'flac' || 'm4a' =>
          Icons.audio_file_rounded,
        'zip' || 'tar' || 'gz' || 'rar' || '7z' => Icons.folder_zip_rounded,
        'doc' || 'docx' => Icons.description_rounded,
        'xls' || 'xlsx' => Icons.table_chart_rounded,
        'ppt' || 'pptx' => Icons.slideshow_rounded,
        'txt' || 'md' || 'log' => Icons.article_rounded,
        'dart' ||
        'py' ||
        'js' ||
        'ts' ||
        'java' ||
        'swift' ||
        'kt' ||
        'c' ||
        'cpp' ||
        'h' =>
          Icons.code_rounded,
        _ => Icons.insert_drive_file_rounded,
      };

  // ── 下载逻辑 ────────────────────────────────────────────────────────────────

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _errorMsg = null;
    });
    try {
      // 确保 downloads 目录存在
      final docDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${docDir.path}/downloads');
      await downloadsDir.create(recursive: true);
      final dest = File('${downloadsDir.path}/${widget.name}');

      // 发起 HTTP 下载，流式写入，实时更新进度
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(Uri.parse(widget.url));
      final res = await req.close();

      // 优先用响应头的 Content-Length，回退到 tool args 里的 size
      final total = res.contentLength > 0
          ? res.contentLength
          : (widget.size > 0 ? widget.size : 0);

      int received = 0;
      final sink = dest.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _progress = (received / total).clamp(0.0, 1.0));
        }
      }
      await sink.close();
      client.close();

      if (mounted) {
        setState(() {
          _downloading = false;
          _downloaded = true;
          _progress = 1.0;
          _localPath = dest.path;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _errorMsg = '下载失败，请重试';
        });
      }
    }
  }

  Future<void> _share() async {
    if (_localPath == null) return;
    await Share.shareXFiles(
      [XFile(_localPath!)],
      subject: widget.name,
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          // 文件类型图标
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_fileIcon, size: 22, color: Colors.white54),
          ),
          const SizedBox(width: 12),

          // 文件名 + 说明 + 大小
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    widget.description!,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (_sizeLabel.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    _sizeLabel,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
                if (_errorMsg != null)
                  Text(
                    _errorMsg!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 11),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // 操作按钮
          if (_downloaded)
            // 已下载 — 分享/存储按钮
            GestureDetector(
              onTap: _share,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.share_rounded,
                  size: 18,
                  color: Colors.greenAccent,
                ),
              ),
            )
          else
            // 下载按钮（弧形进度）
            GestureDetector(
              onTap: _downloading ? null : _download,
              child: SizedBox(
                width: 38,
                height: 38,
                child: CustomPaint(
                  painter: _ArcProgressPainter(
                    progress: _progress,
                    downloading: _downloading,
                  ),
                  child: Center(
                    child: _downloading
                        ? const SizedBox.shrink() // 下载中：只显示弧
                        : Icon(
                            _errorMsg != null
                                ? Icons.refresh_rounded
                                : Icons.download_rounded,
                            size: 16,
                            color: Colors.white54,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 弧形进度 CustomPainter ────────────────────────────────────────────────────

class _ArcProgressPainter extends CustomPainter {
  const _ArcProgressPainter({
    required this.progress,
    required this.downloading,
  });

  final double progress; // 0.0 ~ 1.0
  final bool downloading;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // 底层轨道圆
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 进度弧（从顶部 -90° 顺时针扫）
    if (progress > 0) {
      final isComplete = progress >= 1.0;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = isComplete ? Colors.greenAccent : Colors.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcProgressPainter old) =>
      old.progress != progress || old.downloading != downloading;
}
