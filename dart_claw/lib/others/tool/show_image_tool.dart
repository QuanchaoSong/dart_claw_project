import 'dart:io';

import 'package:dart_claw_core/dart_claw_core.dart';

class ShowImageTool implements ClawTool {
  static const _validExtensions = {
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp',
  };

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
          'Display a local image file to the user in the chat interface. '
          'Use this when you want to show an image from the local file system.',
      'parameters': {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description':
                'Absolute path to the image file (jpg, jpeg, png, gif, webp, bmp).',
          },
        },
        'required': ['path'],
      },
    },
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String? ?? '';
    if (path.isEmpty) return '[error] path is required';

    final file = File(path);
    if (!await file.exists()) return '[error] File not found: $path';

    final lower = path.toLowerCase();
    if (!_validExtensions.any(lower.endsWith)) {
      return '[error] Not a supported image format: $path';
    }

    return '[image displayed]';
  }
}
