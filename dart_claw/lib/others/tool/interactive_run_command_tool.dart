import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dart_claw_core/dart_claw_core.dart';

/// A drop-in replacement for [RunCommandTool] that handles interactive
/// password prompts (sudo, ssh passphrase, etc.) by delegating credential
/// collection to [onPasswordRequired].
///
/// Uses [Process.start] so we can stream stderr in real-time and detect
/// prompts before the process hangs.
class InteractiveRunCommandTool implements ClawTool {
  const InteractiveRunCommandTool({required this.onPasswordRequired});

  /// Called when a password/passphrase prompt is detected in stderr.
  ///
  /// [prompt] is the raw prompt text from the process (e.g. "[sudo] password
  /// for chint: " or "Sorry, try again.\n[sudo] password for chint: ").
  /// Return the password string, or null to cancel the operation.
  final Future<String?> Function(String prompt) onPasswordRequired;

  // Matches partial lines that look like password/passphrase prompts:
  //   "[sudo] password for chint:"
  //   "Password:"
  //   "Enter passphrase for key '...':"
  //   "Password for user@host:"
  static final _passwordPromptPattern = RegExp(
    r'(?:password|passphrase)\b[^:\n]*[:\：]\s*$',
    caseSensitive: false,
  );

  /// Fix common problematic sudo patterns that the LLM tends to generate:
  ///
  /// 1. `echo "" | sudo -S cmd` — the pipe hijacks our stdin, so sudo never
  ///    sees our password injection. Strip the `echo ... |` prefix.
  ///
  /// 2. `sudo cmd` (no -S) — sudo opens /dev/tty instead of reading from
  ///    stdin, completely bypassing our pipe. Inject `-S`.
  static String _preprocessForSudo(String command) {
    var cmd = command;
    // Strip `echo ... | ` immediately before a sudo invocation.
    cmd = cmd.replaceAll(
      RegExp(r'''echo\s+(?:"[^"]*"|'[^']*'|\S*)\s*\|\s*(?=sudo\b)'''),
      '',
    );
    // Ensure every `sudo` uses -S (reads password from stdin).
    // The regex skips sudo invocations that already have -S in their flags.
    cmd = cmd.replaceAll(
      RegExp(r'\bsudo (?!-\S*S)'),
      'sudo -S ',
    );
    return cmd.trim();
  }

  @override
  String get name => 'run_command';

  @override
  bool get isDangerous => true;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Run a shell command on the local machine and return its stdout + stderr. '
              'Use this to inspect files, query system info, run scripts, etc.\n'
              'SUDO RULES (must follow exactly):\n'
              '• Always use `sudo -S` — this makes sudo read the password from stdin '
              '  so the tool can securely supply it on your behalf.\n'
              '• NEVER pipe stdin to sudo (e.g., do NOT write `echo "" | sudo -S cmd`). '
              '  Just write `sudo -S cmd args` directly.\n'
              '• Do NOT use `sudo -n` (non-interactive); use `sudo -S` instead.',
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
    final rawCommand = args['command'] as String;
    final workingDir = args['working_dir'] as String?;

    // Auto-fix common LLM sudo mistakes before running.
    final command = _preprocessForSudo(rawCommand);
    if (command != rawCommand) {
      debugPrint('InteractiveRunCommandTool: rewritten command: $command');
    }

    debugPrint(
        'InteractiveRunCommandTool: $command (cwd: ${workingDir ?? "home"})');

    final process = await Process.start(
      'bash',
      ['-c', command],
      workingDirectory: workingDir,
      runInShell: false,
    );

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();

    // Merge stdout + stderr into a single tagged stream so password prompts
    // are detected regardless of whether the caller used `2>&1`.
    // (With `2>&1`, sudo's prompt lands in stdout, not stderr.)
    final merged = StreamController<(bool isStderr, String chunk)>();
    int _doneCount = 0;
    void _onStreamDone() {
      if (++_doneCount == 2) merged.close();
    }

    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          (chunk) => merged.add((false, chunk)),
          onDone: _onStreamDone,
          onError: (_) => _onStreamDone(),
          cancelOnError: false,
        );

    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          (chunk) => merged.add((true, chunk)),
          onDone: _onStreamDone,
          onError: (_) => _onStreamDone(),
          cancelOnError: false,
        );

    // Track the trailing partial line for each stream separately.
    // Password prompts never end with \n, so we only check the partial tail.
    String partialOut = '';
    String partialErr = '';

    await for (final (isStderr, chunk) in merged.stream) {
      if (isStderr) {
        stderrBuf.write(chunk);
        partialErr += chunk;
        if (partialErr.contains('\n')) {
          partialErr = partialErr.substring(partialErr.lastIndexOf('\n') + 1);
        }
        if (_passwordPromptPattern.hasMatch(partialErr)) {
          final prompt = partialErr.trim();
          partialErr = '';
          final password = await onPasswordRequired(prompt);
          if (password == null) {
            process.kill();
            await process.exitCode;
            return '[cancelled: user declined to provide password]';
          }
          process.stdin.writeln(password);
        }
      } else {
        stdoutBuf.write(chunk);
        partialOut += chunk;
        if (partialOut.contains('\n')) {
          partialOut = partialOut.substring(partialOut.lastIndexOf('\n') + 1);
        }
        if (_passwordPromptPattern.hasMatch(partialOut)) {
          final prompt = partialOut.trim();
          partialOut = '';
          final password = await onPasswordRequired(prompt);
          if (password == null) {
            process.kill();
            await process.exitCode;
            return '[cancelled: user declined to provide password]';
          }
          process.stdin.writeln(password);
        }
      }
    }

    final exitCode = await process.exitCode;

    final stdout = stdoutBuf.toString().trim();
    final stderr = stderrBuf.toString().trim();

    final buf = StringBuffer();
    if (stdout.isNotEmpty) buf.writeln(stdout);
    if (stderr.isNotEmpty) buf.writeln('[stderr]\n$stderr');
    buf.write('[exit: $exitCode]');
    return buf.toString();
  }
}
