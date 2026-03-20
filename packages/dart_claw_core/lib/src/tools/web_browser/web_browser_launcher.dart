import 'dart:convert';
import 'dart:io';

/// Chrome 进程启动结果
class WebBrowserLaunchResult {
  final Process process;
  final int port;

  WebBrowserLaunchResult({required this.process, required this.port});
}

/// 负责在本机查找并启动 Chrome/Chromium，开启 CDP 远程调试端口。
class WebBrowserLauncher {
  static const _defaultPort = 9222;

  // ── 查找浏览器可执行文件 ────────────────────────────────────────────────────

  static String? findChromePath() {
    if (Platform.isMacOS) {
      for (final path in [
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        '/Applications/Chromium.app/Contents/MacOS/Chromium',
        '/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary',
        '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
      ]) {
        if (File(path).existsSync()) return path;
      }
    } else if (Platform.isLinux) {
      for (final name in [
        'google-chrome',
        'google-chrome-stable',
        'chromium-browser',
        'chromium',
      ]) {
        final r = Process.runSync('which', [name]);
        if (r.exitCode == 0) return (r.stdout as String).trim();
      }
    } else if (Platform.isWindows) {
      for (final path in [
        r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
        r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
      ]) {
        if (File(path).existsSync()) return path;
      }
    }
    return null;
  }

  // ── 启动浏览器 ────────────────────────────────────────────────────────────

  /// 以 CDP 调试模式启动浏览器。
  ///
  /// [port] CDP 监听端口，默认 9222。
  /// [headless] 是否无头模式（适合服务器环境）。
  /// [profileDir] 浏览器 user-data-dir 路径。
  ///   - 传入固定路径（如 ~/.dart_claw/browser_profile）：Cookie / 登录态跨重启保留。
  ///   - 传入 null：使用系统临时目录，每次重启都是干净的浏览器。
  ///
  /// 返回 [WebBrowserLaunchResult]，内含进程句柄和端口号。
  static Future<WebBrowserLaunchResult> launch({
    int port = _defaultPort,
    bool headless = false,
    String? profileDir,
  }) async {
    final chromePath = findChromePath();
    if (chromePath == null) {
      throw StateError(
        'No Chrome / Chromium / Edge found on this machine. '
        'Install Google Chrome and try again.',
      );
    }

    // profileDir 为 null 时使用临时目录（每次重启干净），否则使用调用方指定的持久化路径。
    final userDataDir = profileDir ??
        '${Directory.systemTemp.path}${Platform.pathSeparator}dart_claw_chrome_$port';

    final process = await Process.start(chromePath, [
      '--remote-debugging-port=$port',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-default-apps',
      '--disable-popup-blocking',
      '--user-data-dir=$userDataDir',
      if (headless) '--headless=new',
      'about:blank',
    ]);

    // 轮询直到 CDP HTTP 端点就绪（最多 9 秒）。
    final httpClient = HttpClient();
    try {
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        try {
          final req = await httpClient
              .getUrl(Uri.parse('http://localhost:$port/json/version'));
          final res = await req.close();
          await res.drain<void>();
          if (res.statusCode == 200) {
            return WebBrowserLaunchResult(process: process, port: port);
          }
        } catch (_) {
          // 未就绪，继续等待
        }
      }
    } finally {
      httpClient.close();
    }

    process.kill();
    throw StateError('Chrome did not become ready within 9 s on port $port.');
  }

  // ── 获取第一个可见标签页的 WebSocket URL ────────────────────────────────

  /// 返回浏览器中第一个可见标签页（type == "page"）的 CDP WebSocket URL。
  ///
  /// 使用已存在的标签页而非新建，确保导航发生在用户能看到的标签页上。
  static Future<String> firstPageWsUrl(int port) async {
    final httpClient = HttpClient();
    try {
      final req =
          await httpClient.getUrl(Uri.parse('http://localhost:$port/json'));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final targets = jsonDecode(body) as List<dynamic>;
      final page = targets
          .cast<Map<String, dynamic>>()
          .firstWhere((t) => t['type'] == 'page', orElse: () => {});
      final wsUrl = page['webSocketDebuggerUrl'] as String?;
      if (wsUrl == null) {
        throw StateError('No visible page target found. Targets: $body');
      }
      return wsUrl;
    } finally {
      httpClient.close();
    }
  }
}
