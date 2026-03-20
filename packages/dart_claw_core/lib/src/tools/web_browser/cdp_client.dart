import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 基于 dart:io WebSocket 的 Chrome DevTools Protocol（CDP）低层客户端。
///
/// CDP 消息格式：
/// - 命令：{ "id": N, "method": "Domain.method", "params": {...} }
/// - 响应：{ "id": N, "result": {...} }  或  { "id": N, "error": {...} }
/// - 事件：{ "method": "Domain.event", "params": {...} }（无 id 字段）
class CdpClient {
  final WebSocket _ws;
  int _nextId = 1;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  final _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  CdpClient._(this._ws) {
    _ws.listen(_onMessage, onError: _onError, onDone: _onDone);
  }

  /// 连接到指定 CDP WebSocket URL（页面级或浏览器级目标均可）。
  static Future<CdpClient> connect(String wsUrl) async {
    final ws = await WebSocket.connect(wsUrl);
    return CdpClient._(ws);
  }

  /// CDP 事件流（无 id 字段的消息，如 Page.loadEventFired）。
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  /// 发送 CDP 命令，返回其 result 字段。超时 30 秒。
  Future<Map<String, dynamic>> send(
    String method, {
    Map<String, dynamic>? params,
  }) {
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _ws.add(jsonEncode({
      'id': id,
      'method': method,
      'params': params ?? {},
    }));
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException(
          'CDP "$method" timed out after 30 s',
          const Duration(seconds: 30),
        );
      },
    );
  }

  Future<void> close() async {
    await _ws.close();
    if (!_eventController.isClosed) await _eventController.close();
  }

  // ── 内部消息处理 ──────────────────────────────────────────────────────────

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return; // 格式异常，忽略
    }

    if (msg.containsKey('id')) {
      final id = msg['id'] as int;
      final completer = _pending.remove(id);
      if (completer == null) return;
      if (msg.containsKey('error')) {
        completer.completeError(
          Exception('CDP error (id=$id): ${msg['error']}'),
        );
      } else {
        completer.complete(
          (msg['result'] as Map<String, dynamic>?) ?? {},
        );
      }
    } else if (!_eventController.isClosed) {
      _eventController.add(msg);
    }
  }

  void _onError(Object error) {
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(error);
    }
    _pending.clear();
  }

  void _onDone() {
    _onError(const SocketException('CDP WebSocket closed unexpectedly'));
    if (!_eventController.isClosed) _eventController.close();
  }
}
