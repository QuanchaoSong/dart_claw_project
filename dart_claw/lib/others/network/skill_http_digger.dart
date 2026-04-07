import 'dart:convert';
import 'package:http/http.dart' as http;

/// 封装对 Skill Store 服务端的 HTTP 请求。
/// 所有接口均为 GET，固定携带 X-Claw-Key 鉴权 Header。
class SkillHttpDigger {
  SkillHttpDigger._();

  static final SkillHttpDigger shared = SkillHttpDigger._();

  // 切换本地调试时改这一行
  // static const String _baseUrl = 'http://127.0.0.1:37791';
  static const String _baseUrl = 'http://dartclaw-api.lushiyuye.com';

  static const String _apiKey = 'dart-claw-skill-2026';

  final http.Client _client = http.Client();

  Map<String, String> get _headers => {
        'X-Claw-Key': _apiKey,
        'Accept': 'application/json',
      };

  /// 发起 GET 请求，返回解析后的 JSON 响应。
  /// 成功时 code == 0，data 不为 null；失败时 data 为 null，message 含错误信息。
  Future<SkillHttpResponse> getJson(
    String path, {
    Map<String, String> queryParams = const {},
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final response = await _client.get(uri, headers: _headers);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final code = json['code'] as int? ?? -1;
      final msg = json['msg'] as String? ?? '';
      final data = json['data'] as Map<String, dynamic>?;
      return SkillHttpResponse(code: code, message: msg, data: data);
    } catch (e) {
      return SkillHttpResponse(code: -999, message: e.toString(), data: null);
    }
  }

  /// 发起 GET 请求，返回原始文本内容（用于下载 .md 文件）。
  /// 成功时 body 不为 null；失败时 body 为 null，message 含错误信息。
  Future<SkillRawResponse> getRaw(
    String path, {
    Map<String, String> queryParams = const {},
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        return SkillRawResponse(body: response.body, message: '');
      } else {
        return SkillRawResponse(
          body: null,
          message: 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return SkillRawResponse(body: null, message: e.toString());
    }
  }
}

class SkillHttpResponse {
  final int code;
  final String message;
  final Map<String, dynamic>? data;

  const SkillHttpResponse({
    required this.code,
    required this.message,
    required this.data,
  });

  bool get isSuccess => code == 0 && data != null;
}

class SkillRawResponse {
  final String? body;
  final String message;

  const SkillRawResponse({required this.body, required this.message});

  bool get isSuccess => body != null;
}
