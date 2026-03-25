import 'dart:convert';

import 'package:dart_claw_app/others/services/connection_service.dart';
import 'package:http/http.dart' as http;

/// HTTP 请求封装，所有服务层调用桌面端 HTTP 接口时均通过此类。
///
/// 使用方式：`HttpDigger().getAsync('/config')`
class HttpDigger {
  static final HttpDigger _instance = HttpDigger._();
  HttpDigger._();
  factory HttpDigger() => _instance;

  static const Duration _timeout = Duration(seconds: 5);

  final _client = http.Client();

  String get _baseUrl {
    final conn = ConnectionService();
    return 'http://${conn.serverHost.value}:${conn.serverPort.value}';
  }

  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };

  /// GET 请求，返回解码后的 JSON 对象。
  Future<dynamic> getAsync(String path) async {
    final url = Uri.parse('$_baseUrl$path');
    final res = await _client.get(url, headers: _defaultHeaders).timeout(_timeout);
    return jsonDecode(res.body);
  }

  /// POST 请求，body 为 JSON 可序列化对象，返回解码后的 JSON 对象。
  Future<dynamic> postAsync(String path, Object body) async {
    final url = Uri.parse('$_baseUrl$path');
    final res = await _client
        .post(url, headers: _defaultHeaders, body: jsonEncode(body))
        .timeout(_timeout);
    return jsonDecode(res.body);
  }
}
