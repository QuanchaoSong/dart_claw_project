import 'dart:io';

import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ImageCardView extends StatelessWidget {
  const ImageCardView({super.key, required this.record});

  final ClawToolCallRecord record;

  @override
  Widget build(BuildContext context) {
    final path = record.args['path'] as String? ?? '';

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
        ClawToolStatus.success => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ),
          ),
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
