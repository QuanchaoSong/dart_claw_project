import 'dart:async';

import '../services/connection_service.dart';

/// 通过现有 WebSocket 通道向桌面端发起 RPC 调用（relay 模式下替代 HTTP）。
///
/// 使用方式：
/// ```dart
/// final data = await WsRpc().call('get_config');
/// final updated = await WsRpc().call('set_config', {'ai_model': {'provider': 'openai'}});
/// ```
class WsRpc {
  static final WsRpc _instance = WsRpc._();

  WsRpc._() {
    ConnectionService().incomingMessages.listen(_onMessage);
  }

  factory WsRpc() => _instance;

  var _nextId = 0;
  final _pending = <String, Completer<dynamic>>{};

  void _onMessage(Map<String, dynamic> msg) {
    if (msg['type'] != 'rpc_response') return;
    final id = msg['request_id'] as String?;
    if (id == null) return;
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;
    final error = msg['error'] as String?;
    if (error != null) {
      completer.completeError(Exception('WsRpc error [$id]: $error'));
    } else {
      completer.complete(msg['data']);
    }
  }

  /// 向桌面端发起一次 RPC 调用，返回响应中的 `data` 字段。
  ///
  /// [method] 对应桌面端已注册的方法名称（如 `get_config`、`set_config`、`get_scheduler`）。
  /// [params] 传递给桌面端的参数，默认为空 Map。
  ///
  /// 8 秒内无响应时抛出 [TimeoutException]。
  Future<dynamic> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) {
    final id = '${++_nextId}';
    final completer = Completer<dynamic>();
    _pending[id] = completer;

    ConnectionService().send({
      'type': 'rpc_call',
      'request_id': id,
      'method': method,
      'params': params,
    });

    Timer(const Duration(seconds: 8), () {
      final c = _pending.remove(id);
      if (c != null && !c.isCompleted) {
        c.completeError(TimeoutException('WsRpc timeout: $method', const Duration(seconds: 8)));
      }
    });

    return completer.future;
  }
}
