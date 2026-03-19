import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/tool_result.dart';
import 'claw_tool.dart';

class ShowImageTool implements ClawTool {
  static const _validExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
  };

  static bool _isUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  /// Expand leading `~` to the platform home directory.
  static String _expandHome(String path) {
    if (!path.startsWith('~')) return path;
    final home = Platform.environment['HOME'] ?? '';
    return home + path.substring(1);
  }

  @override
  String get name => 'show_image';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Display one or more images to the user in the chat interface. '
              'Accepts absolute local file paths (with ~ for home), https:// URLs, or a mix. '
              'Use `paths` to show multiple images as a carousel.',
          'parameters': {
            'type': 'object',
            'properties': {
              'paths': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    'List of image paths or URLs (jpg, jpeg, png, gif, webp, bmp). '
                    'Accepts absolute local paths (including ~/...) and https:// URLs. '
                    'For a single image, still use a one-element array.',
                'minItems': 1,
              },
            },
            'required': ['paths'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    // Support both `paths` (array, primary) and legacy `path` (string).
    final rawList = <String>[];
    final pathsArg = args['paths'];
    if (pathsArg is List && pathsArg.isNotEmpty) {
      rawList.addAll(pathsArg.cast<String>());
    } else {
      final single = args['path'] as String? ?? '';
      if (single.isNotEmpty) rawList.add(single);
    }

    if (rawList.isEmpty) return ToolResult.failure('[error] paths is required');

    final resolved = <String>[];
    for (final raw in rawList) {
      if (raw.isEmpty) continue;
      final lower = raw.toLowerCase();
      if (!_validExtensions.any(lower.contains)) {
        return ToolResult.failure('[error] Not a supported image format: $raw');
      }
      if (_isUrl(raw)) {
        resolved.add(raw);
      } else {
        final path = _expandHome(raw);
        final file = File(path);
        if (!await file.exists()) {
          return ToolResult.failure('[error] File not found: $path');
        }
        resolved.add(path);
      }
    }

    debugPrint('ShowImageTool: displaying ${resolved.length} image(s)');

    if (resolved.length == 1) {
      final p = resolved.first;
      return _isUrl(p)
          ? ToolResult.success('[image displayed]')
          : ToolResult.success('[image displayed:$p]');
    }

    // Multi: pipe-separated resolved paths (URLs kept as-is, local paths are
    // already home-expanded so Image.file will work).
    return ToolResult.success('[images displayed:${resolved.join('|')}]');
  }
}
