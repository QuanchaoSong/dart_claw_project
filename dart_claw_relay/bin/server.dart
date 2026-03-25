import 'dart:io';
import 'package:args/args.dart';
import 'package:dart_claw_relay/relay_server.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: '37789',
      help: 'Port to listen on',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  late final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln(parser.usage);
    exit(1);
  }

  if (results['help'] as bool) {
    print('dart_claw_relay — WebSocket relay server\n');
    print('Usage: dart run bin/server.dart [options]\n');
    print(parser.usage);
    exit(0);
  }

  final port = int.tryParse(results['port'] as String);
  if (port == null || port < 1 || port > 65535) {
    stderr.writeln('Error: --port must be a valid port number (1-65535)');
    exit(1);
  }

  final server = RelayServer();
  await server.start(port: port);

  // 捕获 SIGINT / SIGTERM，优雅退出
  final signals = [ProcessSignal.sigint, ProcessSignal.sigterm];
  for (final sig in signals) {
    sig.watch().listen((_) async {
      print('\nShutting down...');
      await server.stop();
      exit(0);
    });
  }
}
