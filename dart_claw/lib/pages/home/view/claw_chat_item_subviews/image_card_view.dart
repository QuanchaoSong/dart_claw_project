import 'dart:io';

import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ImageCardView extends StatelessWidget {
  const ImageCardView({super.key, required this.record});

  final ClawToolCallRecord record;

  Widget _buildImage(String path) {
    final isUrl = path.startsWith('http://') || path.startsWith('https://');
    final image = isUrl
        ? Image.network(
            path,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _errorWidget('Failed to load image'),
          )
        : Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _errorWidget('Failed to load image'),
          );
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: image);
  }

  Widget _errorWidget(String msg) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 12)),
      );

  @override
  Widget build(BuildContext context) {
    // When the tool returns '[image displayed:/resolved/path]', extract the
    // resolved path (home-expanded) from the result so Image.file works even
    // when the original arg contained `~`.
    String resolvedPath() {
      final result = record.result ?? '';
      const prefix = '[image displayed:';
      if (result.startsWith(prefix) && result.endsWith(']')) {
        return result.substring(prefix.length, result.length - 1);
      }
      // URL case: result is just '[image displayed]' — fall back to arg.
      return record.args['path'] as String? ?? '';
    }

    final path = record.status == ClawToolStatus.success
        ? resolvedPath()
        : record.args['path'] as String? ?? '';

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
                Text(
                  'Loading image…',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ClawToolStatus.success => _buildImage(path),
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
                      fontFamily: 'monospace',
                    ),
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
}
