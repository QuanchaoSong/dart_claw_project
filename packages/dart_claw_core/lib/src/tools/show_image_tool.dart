import 'dart:io';

import 'package:flutter/foundation.dart';

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
              'Display an image to the user in the chat interface. '
              'Accepts either an absolute local file path or an https:// URL.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description':
                    'Absolute local path (e.g. /Users/foo/img.png) '
                    'or https:// URL of the image (jpg, jpeg, png, gif, webp, bmp).',
              },
            },
            'required': ['path'],
          },
        },
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final raw = args['path'] as String? ?? '';
    if (raw.isEmpty) return '[error] path is required';

    if (_isUrl(raw)) {
      final lower = raw.toLowerCase();
      if (!_validExtensions.any(lower.contains)) {
        return '[error] Not a supported image format: $raw';
      }
      debugPrint('ShowImageTool: displaying URL $raw');
      return '[image displayed]';
    }

    final path = _expandHome(raw);
    final lower = path.toLowerCase();
    if (!_validExtensions.any(lower.endsWith)) {
      return '[error] Not a supported image format: $path';
    }

    final file = File(path);
    if (!await file.exists()) return '[error] File not found: $path';

    debugPrint('ShowImageTool: displaying $path');
    return '[image displayed:$path]';
  }
}
