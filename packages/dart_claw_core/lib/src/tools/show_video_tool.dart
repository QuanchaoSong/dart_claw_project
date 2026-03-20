import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/tool_result.dart';
import 'claw_tool.dart';

/// Tells the UI to render a video player card in the chat interface.
///
/// Accepts a single local file path (absolute, with ~ for home) or an
/// http/https URL to a video.
///
/// On success the result is:
///   `[video displayed:/absolute/path.mp4]`   — local file
///   `[video displayed:https://url/video.mp4]` — remote URL
///
/// The UI layer (`VideoCardView`) is responsible for:
///   - Generating a thumbnail (via fc_native_video_thumbnail for local files)
///   - Providing reveal-in-Finder / open-in-browser button
///   - Providing inline fullscreen playback via media_kit
class ShowVideoTool implements ClawTool {
  static const _validExtensions = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.webm',
    '.m4v',
    '.flv',
    '.wmv',
    '.ts',
    '.m2ts',
  };

  static bool _isUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  static String _expandHome(String path) {
    if (!path.startsWith('~')) return path;
    final home = Platform.environment['HOME'] ?? '';
    return home + path.substring(1);
  }

  @override
  String get name => 'show_video';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Display a video player in the chat interface. '
              'Accepts an absolute local file path (with ~ for home) or an https:// URL. '
              'Supported formats: mp4, mov, avi, mkv, webm, m4v, flv, wmv, ts, m2ts. '
              'Use this when the user asks to play, preview, or show a video.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description':
                    'Absolute local file path to the video (e.g. /Users/foo/video.mp4 or ~/Downloads/clip.mov), '
                    'or an https:// URL pointing to a video stream or file.',
              },
            },
            'required': ['path'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final raw = args['path'] as String? ?? '';
    if (raw.isEmpty) {
      return ToolResult.failure('[error] path is required');
    }

    if (_isUrl(raw)) {
      // Basic validation: must look like a video URL or at least be https.
      debugPrint('ShowVideoTool: displaying URL $raw');
      return ToolResult.success('[video displayed:$raw]');
    }

    // Local file path.
    final path = _expandHome(raw);
    final lower = path.toLowerCase();
    if (!_validExtensions.any((ext) => lower.endsWith(ext))) {
      return ToolResult.failure(
          '[error] Unsupported video format. Supported: ${_validExtensions.join(', ')}');
    }

    final file = File(path);
    if (!await file.exists()) {
      return ToolResult.failure('[error] File not found: $path');
    }

    debugPrint('ShowVideoTool: displaying local video $path');
    return ToolResult.success('[video displayed:$path]');
  }
}
