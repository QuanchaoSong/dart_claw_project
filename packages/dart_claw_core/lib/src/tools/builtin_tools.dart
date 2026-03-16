import 'dart:io';
import 'package:path/path.dart' as p;
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
  Future<String> execute(Map<String, dynamic> args) async {
    final command = args['command'] as String;
    final workingDir = args['working_dir'] as String?;

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
    return buf.toString();
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
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final startLine = args['start_line'] as int?;
    final endLine = args['end_line'] as int?;

    final file = File(path);
    if (!await file.exists()) {
      return '[error] File not found: $path';
    }

    if (startLine == null && endLine == null) {
      final content = await file.readAsString();
      // 超过 500 行时截断，避免爆 context
      final lines = content.split('\n');
      if (lines.length > 500) {
        return '${lines.take(500).join('\n')}\n[truncated: showing first 500 of ${lines.length} lines]';
      }
      return content;
    }

    final lines = await file.readAsLines();
    final from = (startLine ?? 1) - 1;
    final to = (endLine ?? lines.length) - 1;
    final slice = lines.sublist(
      from.clamp(0, lines.length),
      (to + 1).clamp(0, lines.length),
    );
    return slice.join('\n');
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
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final content = args['content'] as String;

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return 'Written ${content.length} characters to $path';
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
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final dir = Directory(path);
    if (!await dir.exists()) {
      return '[error] Directory not found: $path';
    }

    final entries = <String>[];
    await for (final entity in dir.list()) {
      final name = p.basename(entity.path);
      entries.add(entity is Directory ? '$name/' : name);
    }
    entries.sort();
    return entries.join('\n');
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
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final pattern = args['pattern'] as String;
    final isRegex = (args['is_regex'] as bool?) ?? false;

    final file = File(path);
    if (!await file.exists()) {
      return '[error] File not found: $path';
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

    if (results.isEmpty) return '[no matches found]';
    if (results.length > 100) {
      return '${results.take(100).join('\n')}\n[truncated: showing first 100 of ${results.length} matches]';
    }
    return results.join('\n');
  }
}
