import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../model/tool_result.dart';
import 'claw_tool.dart';

// ──────────────────────────────────────────────────────────────────────────────
// run_command
// ──────────────────────────────────────────────────────────────────────────────

class RunCommandTool implements ClawTool {
  @override
  final String name = 'run_command';

  @override
  bool get isDangerous => true;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Run a shell command on the local machine and return its stdout + stderr. '
              'Use this to inspect files, query system info, run scripts, etc.',
          'parameters': {
            'type': 'object',
            'properties': {
              'command': {
                'type': 'string',
                'description': 'The shell command to execute.',
              },
              'working_dir': {
                'type': 'string',
                'description':
                    'Optional working directory (absolute path). Defaults to the user home directory.',
              },
            },
            'required': ['command'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final command = args['command'] as String;
    final workingDir = args['working_dir'] as String?;

    debugPrint('Executing command: $command (working dir: ${workingDir ?? "home"})');

    final result = await Process.run(
      'bash',
      ['-c', command],
      workingDirectory: workingDir,
      runInShell: false,
    );

    final stdout = result.stdout.toString().trim();
    final stderr = result.stderr.toString().trim();
    final exitCode = result.exitCode;

    final buf = StringBuffer();
    if (stdout.isNotEmpty) buf.writeln(stdout);
    if (stderr.isNotEmpty) buf.writeln('[stderr]\n$stderr');
    buf.write('[exit: $exitCode]');
    return ToolResult(
      isSuccess: exitCode == 0,
      output: buf.toString(),
      exitCode: exitCode,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// read_file
// ──────────────────────────────────────────────────────────────────────────────

class ReadFileTool implements ClawTool {
  @override
  final String name = 'read_file';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description': 'Read the text content of a file on the local machine.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Absolute path to the file.',
              },
              'start_line': {
                'type': 'integer',
                'description':
                    'Optional 1-based line number to start reading from.',
              },
              'end_line': {
                'type': 'integer',
                'description':
                    'Optional 1-based line number to stop reading at (inclusive).',
              },
            },
            'required': ['path'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final startLine = args['start_line'] as int?;
    final endLine = args['end_line'] as int?;

    final file = File(path);
    if (!await file.exists()) {
      return ToolResult.failure('[error] File not found: $path');
    }

    if (startLine == null && endLine == null) {
      final content = await file.readAsString();
      // 超过 500 行时截断，避免爆 context
      final lines = content.split('\n');
      if (lines.length > 500) {
        return ToolResult.success(
          '${lines.take(500).join('\n')}\n[truncated: showing first 500 of ${lines.length} lines]',
        );
      }
      return ToolResult.success(content);
    }

    final lines = await file.readAsLines();
    final from = (startLine ?? 1) - 1;
    final to = (endLine ?? lines.length) - 1;
    final slice = lines.sublist(
      from.clamp(0, lines.length),
      (to + 1).clamp(0, lines.length),
    );
    return ToolResult.success(slice.join('\n'));
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// write_file
// ──────────────────────────────────────────────────────────────────────────────

class WriteFileTool implements ClawTool {
  @override
  final String name = 'write_file';

  @override
  bool get isDangerous => true;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Write (overwrite) or create a text file on the local machine.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Absolute path to the file.',
              },
              'content': {
                'type': 'string',
                'description': 'The full text content to write.',
              },
            },
            'required': ['path', 'content'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final content = args['content'] as String;

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return ToolResult.success('Written ${content.length} characters to $path');
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// list_dir
// ──────────────────────────────────────────────────────────────────────────────

class ListDirTool implements ClawTool {
  @override
  final String name = 'list_dir';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'List files and subdirectories inside a directory. '
              'Directories are marked with a trailing /.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Absolute path to the directory.',
              },
            },
            'required': ['path'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final dir = Directory(path);
    if (!await dir.exists()) {
      return ToolResult.failure('[error] Directory not found: $path');
    }

    final entries = <String>[];
    await for (final entity in dir.list()) {
      final name = p.basename(entity.path);
      entries.add(entity is Directory ? '$name/' : name);
    }
    entries.sort();
    return ToolResult.success(entries.join('\n'));
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// search_in_file
// ──────────────────────────────────────────────────────────────────────────────

class SearchInFileTool implements ClawTool {
  @override
  final String name = 'search_in_file';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Search for a string or regex pattern in a file. '
              'Returns matching lines with their line numbers.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Absolute path to the file.',
              },
              'pattern': {
                'type': 'string',
                'description': 'The string or regex pattern to search for.',
              },
              'is_regex': {
                'type': 'boolean',
                'description':
                    'Whether pattern is a regular expression. Default false.',
              },
            },
            'required': ['path', 'pattern'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final pattern = args['pattern'] as String;
    final isRegex = (args['is_regex'] as bool?) ?? false;

    final file = File(path);
    if (!await file.exists()) {
      return ToolResult.failure('[error] File not found: $path');
    }

    final lines = await file.readAsLines();
    final results = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final matches = isRegex
          ? RegExp(pattern).hasMatch(line)
          : line.contains(pattern);
      if (matches) {
        results.add('${i + 1}: $line');
      }
    }

    if (results.isEmpty) return ToolResult.success('[no matches found]');
    if (results.length > 100) {
      return ToolResult.success(
        '${results.take(100).join('\n')}\n[truncated: showing first 100 of ${results.length} matches]',
      );
    }
    return ToolResult.success(results.join('\n'));
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// vision_read_image
// ──────────────────────────────────────────────────────────────────────────────

/// 读取本地图片并把 base64 注入到下一轮 LLM 调用，使模型能够“看到”图像内容。
///
/// 适用场景：截图分析、本地图片提问、视觉验证等。
/// 不需要看的图片请不要调用此工具——base64 会显著十大上下文。
class VisionReadImageTool implements ClawTool {
  static const _supportedExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

  @override
  String get name => 'vision_read_image';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Load a local image file and inject it into the conversation so '
              'you can visually inspect its content. '
              'Call this when you need to see a screenshot, photo, or any other '
              'image (e.g. after browser_screenshot, or when the user asks about '
              'a specific local image). '
              'Do NOT call this for every image path you encounter—only call it '
              'when visual understanding is required for the current task.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description':
                    'Absolute path to the image file '
                    '(jpg, jpeg, png, gif, webp, bmp).',
              },
            },
            'required': ['path'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final rawPath = args['path'] as String;
    final path = rawPath.startsWith('~')
        ? rawPath.replaceFirst('~', Platform.environment['HOME'] ?? '')
        : rawPath;
    final ext = path.split('.').last.toLowerCase();
    if (!_supportedExts.contains(ext)) {
      return ToolResult.failure(
          '[vision_read_image] Unsupported format: $ext. '
          'Supported: ${_supportedExts.join(', ')}');
    }
    final file = File(path);
    if (!await file.exists()) {
      return ToolResult.failure('[vision_read_image] File not found: $path');
    }
    debugPrint('[vision_read_image] queued for vision injection: $path');
    return ToolResult.vision(
      output: 'Image ready: $path — visual content will be injected into the next message.',
      imagePath: path,
    );
  }
}
