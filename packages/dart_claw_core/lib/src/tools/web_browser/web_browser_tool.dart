import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../claw_tool.dart';
import '../../model/tool_result.dart';
import 'web_browser_launcher.dart';
import 'cdp_client.dart';

// ──────────────────────────────────────────────────────────────────────────────
// WebBrowserManager — 单例，管理浏览器进程与页面级 CDP 连接
// ──────────────────────────────────────────────────────────────────────────────

/// 管理浏览器进程生命周期与当前活动页面的 CDP 连接。
///
/// 所有浏览器工具共享同一个 [WebBrowserManager.instance]。浏览器在首次使用时
/// 惰性启动，可通过 [browser_close] 工具或直接调用 [close()] 关闭。
class WebBrowserManager {
  /// [profileDir]：浏览器数据目录。
  ///   - 传入固定路径 → Cookie/登录态跨重启保留。
  ///   - 传入 null → 每次启动都是干净的浏览器（使用临时目录）。
  WebBrowserManager({this.profileDir});

  static final WebBrowserManager instance = WebBrowserManager();

  final String? profileDir;
  Process? _process;
  CdpClient? _page;
  final int _port = 9222;

  bool get isRunning => _process != null && _page != null;

  /// 获取页面级 CDP 客户端，若浏览器尚未启动则自动启动。
  Future<CdpClient> get page async {
    if (_process != null && _page != null) return _page!;
    final result = await WebBrowserLauncher.launch(port: _port, profileDir: profileDir);
    _process = result.process;
    final wsUrl = await WebBrowserLauncher.firstPageWsUrl(_port);
    _page = await CdpClient.connect(wsUrl);
    // 启用 Page 和 Runtime 域，以便接收页面事件并执行 JS。
    await _page!.send('Page.enable');
    await _page!.send('Runtime.enable');
    // 把我们控制的标签页拉到前台，用户可以直接看到。
    await _page!.send('Page.bringToFront');
    return _page!;
  }

  /// 导航到指定 URL，等待 loadEventFired（最多 30 秒）。
  Future<void> navigate(String url) async {
    final cdp = await page;
    final loadFired = Completer<void>();
    late StreamSubscription<Map<String, dynamic>> sub;
    sub = cdp.events.listen((event) {
      if (event['method'] == 'Page.loadEventFired') {
        if (!loadFired.isCompleted) loadFired.complete();
        sub.cancel();
      }
    });
    final navResult = await cdp.send('Page.navigate', params: {'url': url});
    final errorText = navResult['errorText'] as String?;
    if (errorText != null && errorText.isNotEmpty) {
      sub.cancel();
      throw Exception('Navigation failed: $errorText');
    }
    await loadFired.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        sub.cancel();
        // 部分页面不触发 loadEventFired（如 SPA hash 路由），超时后继续即可。
      },
    );
  }

  /// 关闭浏览器进程，重置所有状态。
  Future<void> close() async {
    await _page?.close();
    _page = null;
    _process?.kill();
    _process = null;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 工具集入口
// ──────────────────────────────────────────────────────────────────────────────

/// 返回所有浏览器工具，共享同一个 [WebBrowserManager] 实例。
///
/// [profileDir]：浏览器数据目录路径，null 表示每次使用临时目录（不保留登录）。
List<ClawTool> getWebBrowserTools([String? profileDir]) {
  final m = WebBrowserManager(profileDir: profileDir);
  return [
    _WebBrowserNavigateTool(m),
    _WebBrowserGetContentTool(m),
    _WebBrowserScreenshotTool(m),
    _WebBrowserClickTool(m),
    _WebBrowserTypeTool(m),
    _WebBrowserEvaluateTool(m),
    _WebBrowserCloseTool(m),
  ];
}

// ──────────────────────────────────────────────────────────────────────────────
// browser_navigate
// ──────────────────────────────────────────────────────────────────────────────

class _WebBrowserNavigateTool implements ClawTool {
  final WebBrowserManager _m;
  _WebBrowserNavigateTool(this._m);

  @override
  String get name => 'browser_navigate';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Open a URL in the browser and wait for the page to finish loading. '
              'Launches the browser automatically if it is not already running.',
          'parameters': {
            'type': 'object',
            'properties': {
              'url': {
                'type': 'string',
                'description': 'The URL to navigate to (must include scheme, e.g. https://).',
              },
            },
            'required': ['url'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final url = args['url'] as String;
    try {
      await _m.navigate(url);
      return ToolResult.success('Navigated to $url');
    } catch (e) {
      return ToolResult.failure('[browser_navigate error] $e');
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// browser_get_content
// ──────────────────────────────────────────────────────────────────────────────

class _WebBrowserGetContentTool implements ClawTool {
  final WebBrowserManager _m;
  _WebBrowserGetContentTool(this._m);

  @override
  String get name => 'browser_get_content';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Get the current page content. Use format="text" (default) for the '
              'visible text, or format="html" for the full HTML source.',
          'parameters': {
            'type': 'object',
            'properties': {
              'format': {
                'type': 'string',
                'enum': ['text', 'html'],
                'description': 'Output format. Defaults to "text".',
              },
              'max_chars': {
                'type': 'integer',
                'description':
                    'Maximum characters to return. Defaults to 20000.',
              },
            },
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final format = (args['format'] as String?) ?? 'text';
    final maxChars = (args['max_chars'] as int?) ?? 20000;
    final expression = format == 'html'
        ? 'document.documentElement.outerHTML'
        : 'document.body?.innerText ?? document.documentElement.innerText';
    try {
      final cdp = await _m.page;
      final result = await cdp.send('Runtime.evaluate', params: {
        'expression': expression,
        'returnByValue': true,
      });
      final value = result['result']?['value'] as String? ?? '';
      final truncated =
          value.length > maxChars ? value.substring(0, maxChars) : value;
      final suffix =
          value.length > maxChars ? '\n[truncated at $maxChars chars]' : '';
      return ToolResult.success('$truncated$suffix');
    } catch (e) {
      return ToolResult.failure('[browser_get_content error] $e');
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// browser_screenshot
// ──────────────────────────────────────────────────────────────────────────────

class _WebBrowserScreenshotTool implements ClawTool {
  final WebBrowserManager _m;
  _WebBrowserScreenshotTool(this._m);

  @override
  String get name => 'browser_screenshot';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Capture a PNG screenshot of the current browser page and save it '
              'to a file. Returns the absolute path to the saved file.',
          'parameters': {
            'type': 'object',
            'properties': {
              'save_path': {
                'type': 'string',
                'description':
                    'Absolute path where the PNG will be saved. '
                    'Defaults to a temp file.',
              },
            },
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final savePath = (args['save_path'] as String?) ??
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
            'dart_claw_screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
    try {
      final cdp = await _m.page;
      final result = await cdp.send('Page.captureScreenshot', params: {
        'format': 'png',
        'fromSurface': true,
      });
      final base64Data = result['data'] as String?;
      if (base64Data == null) {
        return ToolResult.failure('[browser_screenshot error] No data returned.');
      }
      final bytes = base64Decode(base64Data);
      await File(savePath).writeAsBytes(bytes);
      return ToolResult.success('Screenshot saved to $savePath (${bytes.length} bytes)');
    } catch (e) {
      return ToolResult.failure('[browser_screenshot error] $e');
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// browser_click
// ──────────────────────────────────────────────────────────────────────────────

class _WebBrowserClickTool implements ClawTool {
  final WebBrowserManager _m;
  _WebBrowserClickTool(this._m);

  @override
  String get name => 'browser_click';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Click an element on the current page using a CSS selector.',
          'parameters': {
            'type': 'object',
            'properties': {
              'selector': {
                'type': 'string',
                'description': 'CSS selector of the element to click.',
              },
            },
            'required': ['selector'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final selector = (args['selector'] as String).replaceAll("'", r"\'");
    final expression =
        "(function(sel){var el=document.querySelector(sel);if(!el)return 'ERROR: element not found for selector: '+sel;el.click();return 'clicked';})('$selector')";
    try {
      final cdp = await _m.page;
      final result = await cdp.send('Runtime.evaluate', params: {
        'expression': expression,
        'returnByValue': true,
      });
      final value = result['result']?['value'] as String? ?? '';
      if (value.startsWith('ERROR:')) {
        return ToolResult.failure('[browser_click] $value');
      }
      return ToolResult.success('Clicked "$selector"');
    } catch (e) {
      return ToolResult.failure('[browser_click error] $e');
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// browser_type
// ──────────────────────────────────────────────────────────────────────────────

class _WebBrowserTypeTool implements ClawTool {
  final WebBrowserManager _m;
  _WebBrowserTypeTool(this._m);

  @override
  String get name => 'browser_type';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Focus an input element and type text into it. '
              'Triggers native input/change events so React/Vue forms respond correctly.',
          'parameters': {
            'type': 'object',
            'properties': {
              'selector': {
                'type': 'string',
                'description': 'CSS selector of the input / textarea element.',
              },
              'text': {
                'type': 'string',
                'description': 'Text to type into the element.',
              },
              'clear_first': {
                'type': 'boolean',
                'description':
                    'Whether to clear the existing value before typing. Defaults to true.',
              },
            },
            'required': ['selector', 'text'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final selector = args['selector'] as String;
    final text = args['text'] as String;
    final clearFirst = (args['clear_first'] as bool?) ?? true;

    // Build the JS expression using jsonEncode for safe escaping.
    final jsArgs = jsonEncode({
      'selector': selector,
      'text': text,
      'clear': clearFirst,
    });

    final expression = '''
(function(a){
  var el = document.querySelector(a.selector);
  if (!el) return 'ERROR: element not found for selector: ' + a.selector;
  el.focus();
  if (a.clear) { el.value = ''; }
  el.value = el.value + a.text;
  el.dispatchEvent(new Event('input', {bubbles: true}));
  el.dispatchEvent(new Event('change', {bubbles: true}));
  return 'typed';
})($jsArgs)''';

    try {
      final cdp = await _m.page;
      final result = await cdp.send('Runtime.evaluate', params: {
        'expression': expression,
        'returnByValue': true,
      });
      final value = result['result']?['value'] as String? ?? '';
      if (value.startsWith('ERROR:')) {
        return ToolResult.failure('[browser_type] $value');
      }
      return ToolResult.success('Typed into "$selector"');
    } catch (e) {
      return ToolResult.failure('[browser_type error] $e');
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// browser_evaluate
// ──────────────────────────────────────────────────────────────────────────────

class _WebBrowserEvaluateTool implements ClawTool {
  final WebBrowserManager _m;
  _WebBrowserEvaluateTool(this._m);

  @override
  String get name => 'browser_evaluate';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Evaluate a JavaScript expression in the current page context '
              'and return the result as a string.',
          'parameters': {
            'type': 'object',
            'properties': {
              'expression': {
                'type': 'string',
                'description':
                    'A JavaScript expression to evaluate in the page. '
                    'The return value must be JSON-serializable.',
              },
            },
            'required': ['expression'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final expression = args['expression'] as String;
    try {
      final cdp = await _m.page;
      final result = await cdp.send('Runtime.evaluate', params: {
        'expression': expression,
        'returnByValue': true,
        'awaitPromise': true,
      });
      final res = result['result'] as Map<String, dynamic>?;
      if (res == null) return ToolResult.success('null');
      if (res['type'] == 'undefined') return ToolResult.success('undefined');
      final value = res['value'];
      return ToolResult.success(
        value is String ? value : jsonEncode(value),
      );
    } catch (e) {
      return ToolResult.failure('[browser_evaluate error] $e');
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// browser_close
// ──────────────────────────────────────────────────────────────────────────────

class _WebBrowserCloseTool implements ClawTool {
  final WebBrowserManager _m;
  _WebBrowserCloseTool(this._m);

  @override
  String get name => 'browser_close';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Close the browser and release all resources. '
              'The next browser_navigate call will launch a fresh browser.',
          'parameters': {
            'type': 'object',
            'properties': {},
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    if (!_m.isRunning) {
      return ToolResult.success('Browser is not running.');
    }
    await _m.close();
    return ToolResult.success('Browser closed.');
  }
}
