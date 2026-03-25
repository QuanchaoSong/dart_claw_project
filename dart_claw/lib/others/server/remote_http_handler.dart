import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_claw/others/model/ai_model_settings_info.dart';
import 'package:dart_claw/others/services/app_config_service.dart';
import 'package:dart_claw/others/services/scheduler_service.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:get/get.dart';

/// 桌面端 HTTP 路由处理器（从 LocalServer 抽离）。
///
/// 所有方法均为 static，通过 Get / 全局单例访问业务层。
class RemoteHttpHandler {
  RemoteHttpHandler._();

  static const _imageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'
  };
  static const _videoExtensions = {
    'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'
  };

  // ── 图片服务 (GET /image?path=...) ─────────────────────────────────────

  static Future<void> serveImage(HttpRequest request) async {
    final rawPath = request.uri.queryParameters['path'] ?? '';
    if (rawPath.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    final ext = rawPath.split('.').last.toLowerCase();
    if (!_imageExtensions.contains(ext)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..close();
      return;
    }
    final path = _expandTilde(rawPath);
    final file = File(path);
    if (!await file.exists()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => 'application/octet-stream',
    };
    final bytes = await file.readAsBytes();
    request.response
      ..headers.set('Content-Type', mime)
      ..headers.set('Access-Control-Allow-Origin', '*')
      ..add(bytes);
    await request.response.close();
  }

  // ── 视频服务 (GET /video?path=...) ─────────────────────────────────────

  static Future<void> serveVideo(HttpRequest request) async {
    final rawPath = request.uri.queryParameters['path'] ?? '';
    if (rawPath.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    final ext = rawPath.split('.').last.toLowerCase();
    if (!_videoExtensions.contains(ext)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..close();
      return;
    }
    final path = _expandTilde(rawPath);
    final file = File(path);
    if (!await file.exists()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }
    final mime = switch (ext) {
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      'm4v' => 'video/x-m4v',
      _ => 'application/octet-stream',
    };

    final fileSize = await file.length();
    final rangeHeader = request.headers.value('range');

    request.response.headers
      ..set('Content-Type', mime)
      ..set('Accept-Ranges', 'bytes')
      ..set('Access-Control-Allow-Origin', '*');

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final rangePart = rangeHeader.substring(6);
      final parts = rangePart.split('-');
      final start = int.tryParse(parts[0]) ?? 0;
      final end = (parts.length > 1 && parts[1].isNotEmpty)
          ? int.tryParse(parts[1]) ?? (fileSize - 1)
          : fileSize - 1;
      final length = end - start + 1;

      request.response
        ..statusCode = HttpStatus.partialContent
        ..headers.set('Content-Range', 'bytes $start-$end/$fileSize')
        ..headers.set('Content-Length', length.toString())
        ..add(await _readFileRange(file, start, length));
    } else {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set('Content-Length', fileSize.toString())
        ..add(await file.readAsBytes());
    }

    await request.response.close();
  }

  // ── Skill 列表 (GET /skills) ───────────────────────────────────────────

  static Future<void> serveSkills(HttpRequest request) async {
    try {
      final skills = await Get.find<HomeLogic>().loadAvailableSkills();
      final json = jsonEncode(
        skills
            .map((s) => {'name': s.name, 'description': s.description})
            .toList(),
      );
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set('Content-Type', 'application/json; charset=utf-8')
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..write(json);
    } catch (_) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set('Content-Type', 'application/json')
        ..write('[]');
    }
    await request.response.close();
  }

  // ── 配置读取 (GET /config) ─────────────────────────────────────────────

  static Future<void> serveConfig(HttpRequest request) async {
    final cfg = AppConfigService.shared.config.value;
    final activeModel = cfg.model;

    final providers = <Map<String, dynamic>>[];
    for (final p in AIProvider.values) {
      providers.add({
        'name': p.name,
        'displayName': p.displayName,
        'models': kProviderModels[p] ?? [],
      });
    }

    final json = jsonEncode({
      'ai_model': {
        'provider': activeModel.provider.name,
        'providerDisplayName': activeModel.provider.displayName,
        'modelId': activeModel.modelId,
        'temperature': activeModel.temperature,
        'maxTokens': activeModel.maxTokens,
      },
      'providers': providers,
      'session': {
        'maxRounds': cfg.session.maxRounds,
      },
    });

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set('Content-Type', 'application/json; charset=utf-8')
      ..headers.set('Access-Control-Allow-Origin', '*')
      ..write(json);
    await request.response.close();
  }

  // ── 配置修改 (POST /config) ────────────────────────────────────────────

  static Future<void> handleConfigUpdate(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final svc = AppConfigService.shared;
      final cfg = svc.config.value;

      if (data.containsKey('ai_model')) {
        final m = data['ai_model'] as Map<String, dynamic>;
        final providerName = m['provider'] as String?;
        final provider = providerName != null
            ? AIProvider.fromString(providerName)
            : cfg.model.provider;
        final existing = cfg.providerConfigs[provider] ??
            AIModelSettingsInfo(provider: provider);
        await svc.saveModelSettings(existing.copyWith(
          provider: provider,
          modelId: m['modelId'] as String? ?? existing.modelId,
          temperature: (m['temperature'] as num?)?.toDouble(),
          maxTokens: m['maxTokens'] as int?,
        ));
      }

      if (data.containsKey('session')) {
        final s = data['session'] as Map<String, dynamic>;
        await svc.saveSessionSettings(cfg.session.copyWith(
          maxRounds: s['maxRounds'] as int?,
        ));
      }

      await serveConfig(request);
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.set('Content-Type', 'application/json; charset=utf-8')
        ..write(jsonEncode({'error': '$e'}));
      await request.response.close();
    }
  }

  // ── 定时任务列表 (GET /scheduler) ──────────────────────────────────────

  static Future<void> serveScheduler(HttpRequest request) async {
    try {
      final tasks = SchedulerService.instance.tasks;
      final list = tasks.map((t) {
        const weekdayNames = [
          '', '周一', '周二', '周三', '周四', '周五', '周六', '周日'
        ];
        return {
          'id': t.id,
          'name': t.name,
          'mode': t.mode.name,
          'time':
              '${t.time.hour.toString().padLeft(2, '0')}:${t.time.minute.toString().padLeft(2, '0')}',
          'weekdays': t.weekdays.map((d) => weekdayNames[d]).toList(),
          'actionType': t.actionType.name,
          'isEnabled': t.isEnabled,
          'lastRunAt': t.lastRunAt?.toIso8601String(),
          'nextRunAt': t.nextRunAt?.toIso8601String(),
        };
      }).toList();

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set('Content-Type', 'application/json; charset=utf-8')
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..write(jsonEncode(list));
    } catch (_) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set('Content-Type', 'application/json')
        ..write('[]');
    }
    await request.response.close();
  }

  // ── 文件下载 (GET /file?path=...) ──────────────────────────────────────

  static Future<void> serveFile(HttpRequest request) async {
    final rawPath = request.uri.queryParameters['path'] ?? '';
    if (rawPath.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    final path = _expandTilde(rawPath);
    final file = File(path);
    if (!await file.exists()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }
    final name = file.uri.pathSegments.last;
    final fileSize = await file.length();
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final mime = switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'txt' => 'text/plain',
      'json' => 'application/json',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
    request.response.headers
      ..set('Content-Type', mime)
      ..set('Content-Disposition', 'attachment; filename="$name"')
      ..set('Content-Length', fileSize.toString())
      ..set('Access-Control-Allow-Origin', '*');
    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  // ── 文件上传 (POST /upload?name=...) ───────────────────────────────────

  static Future<void> handleUpload(HttpRequest request) async {
    if (request.method.toUpperCase() != 'POST') {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..close();
      return;
    }
    final rawName = request.uri.queryParameters['name'] ?? '';
    if (rawName.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    final safeName = rawName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    if (safeName.contains('..') || safeName.startsWith('.')) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }

    final requestId = request.uri.queryParameters['request_id'] ?? '';

    final rawDir = AppConfigService.shared.config.value.server.uploadSaveDir;
    final saveDir = _expandTilde(rawDir);
    await Directory(saveDir).create(recursive: true);

    final dest = File('$saveDir/$safeName');
    final sink = dest.openWrite();
    await sink.addStream(request);
    await sink.close();

    final savedPath = dest.path;

    final homeLogic = Get.find<HomeLogic>();
    if (requestId.isNotEmpty) {
      homeLogic.onFileRequestFulfilled(requestId, savedPath);
    }
    homeLogic.onFileReceived(safeName, savedPath);

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set('Content-Type', 'application/json; charset=utf-8')
      ..headers.set('Access-Control-Allow-Origin', '*')
      ..write(jsonEncode({'ok': true, 'path': savedPath, 'name': safeName}));
    await request.response.close();
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  static String _expandTilde(String path) {
    if (path.startsWith('~/')) {
      return (Platform.environment['HOME'] ?? '') + path.substring(1);
    }
    return path;
  }

  static Future<Uint8List> _readFileRange(
      File file, int start, int length) async {
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      return await raf.read(length);
    } finally {
      await raf.close();
    }
  }
}
