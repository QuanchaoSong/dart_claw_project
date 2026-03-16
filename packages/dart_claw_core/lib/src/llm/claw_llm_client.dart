import 'dart:convert';
import 'dart:io';

import '../model/tool_call_record.dart';
import 'claw_llm_delta.dart';

/// OpenAI 兼容协议的 LLM HTTP 客户端（SSE 流式输出）
///
/// 支持所有兼容 OpenAI `/v1/chat/completions` 接口的服务：
/// OpenAI、Anthropic（兼容层）、DeepSeek、本地 Ollama/LM Studio 等。
class ClawLlmClient {
  final String baseUrl;
  final String apiKey;
  final String modelId;
  final double temperature;
  final int maxTokens;

  ClawLlmClient({
    required this.baseUrl,
    required this.apiKey,
    required this.modelId,
    this.temperature = 0.7,
    this.maxTokens = 4096,
  });

  /// 流式调用 chat completions，逐步 yield [ClawLlmDelta]
  ///
  /// [messages] 符合 OpenAI messages 格式
  /// [tools]    符合 OpenAI tools 格式（可选）
  Stream<ClawLlmDelta> streamChat({
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
  }) async* {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);

    try {
      final request = await httpClient.postUrl(
        Uri.parse('$baseUrl/chat/completions'),
      );
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
        ..set(HttpHeaders.acceptHeader, 'text/event-stream');

      final body = <String, dynamic>{
        'model': modelId,
        'messages': messages,
        'stream': true,
        'temperature': temperature,
        'max_tokens': maxTokens,
      };
      if (tools != null && tools.isNotEmpty) body['tools'] = tools;

      request.write(jsonEncode(body));
      final response = await request.close();

      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        throw ClawLlmException(
          statusCode: response.statusCode,
          message: _extractErrorMessage(errorBody),
        );
      }

      // SSE 行缓冲（HTTP chunk 可能在行中间切断）
      final lineBuffer = StringBuffer();
      // tool_call 分片按 index 累积
      final toolAccumulator = <int, _ToolCallAcc>{};

      await for (final chunk in response.transform(utf8.decoder)) {
        lineBuffer.write(chunk);
        final text = lineBuffer.toString();
        final lines = text.split('\n');

        // 末尾不完整的行放回 buffer
        lineBuffer.clear();
        if (!text.endsWith('\n')) {
          lineBuffer.write(lines.removeLast());
        } else {
          lines.removeLast(); // 移除 split 后末尾的空串
        }

        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();

          if (data == '[DONE]') {
            // 流结束：输出完整 tool_calls（如有）
            if (toolAccumulator.isNotEmpty) {
              final records = toolAccumulator.entries
                  .toList()
                ..sort((a, b) => a.key.compareTo(b.key));
              yield ClawLlmToolCallsDelta(
                records.map((e) => e.value.toRecord()).toList(),
              );
            }
            yield const ClawLlmFinishDelta('stop');
            return;
          }

          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final choices = json['choices'] as List?;
            if (choices == null || choices.isEmpty) continue;

            final choice = choices[0] as Map<String, dynamic>;
            final delta = choice['delta'] as Map<String, dynamic>?;
            if (delta == null) continue;

            final finishReason = choice['finish_reason'] as String?;

            // 文本 chunk
            final content = delta['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield ClawLlmTextDelta(content);
            }

            // tool_calls chunk（累积各 index 的片段）
            final rawTcs = delta['tool_calls'] as List?;
            if (rawTcs != null) {
              for (final tc in rawTcs.cast<Map<String, dynamic>>()) {
                final idx = (tc['index'] as num).toInt();
                toolAccumulator.putIfAbsent(idx, _ToolCallAcc.new);
                toolAccumulator[idx]!.accumulate(tc);
              }
            }

            // 某些 provider 在 finish_reason == 'tool_calls' 时不再发 [DONE]
            if (finishReason == 'tool_calls' && toolAccumulator.isNotEmpty) {
              final records = toolAccumulator.entries
                  .toList()
                ..sort((a, b) => a.key.compareTo(b.key));
              yield ClawLlmToolCallsDelta(
                records.map((e) => e.value.toRecord()).toList(),
              );
              yield const ClawLlmFinishDelta('tool_calls');
              return;
            }
          } catch (_) {
            // 忽略格式异常的 chunk（partial JSON、ping 事件等）
          }
        }
      }
    } finally {
      httpClient.close();
    }
  }

  static String _extractErrorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      return error?['message'] as String? ?? body;
    } catch (_) {
      return body.length > 300 ? '${body.substring(0, 300)}…' : body;
    }
  }
}

/// tool_call 分片累积器（内部使用）
class _ToolCallAcc {
  String id = '';
  String name = '';
  final _args = StringBuffer();

  void accumulate(Map<String, dynamic> tc) {
    if (tc['id'] is String) id = tc['id'] as String;
    final fn = tc['function'] as Map<String, dynamic>?;
    if (fn != null) {
      if (fn['name'] is String) name = fn['name'] as String;
      if (fn['arguments'] is String) _args.write(fn['arguments'] as String);
    }
  }

  ClawToolCallRecord toRecord() {
    Map<String, dynamic> parsedArgs = {};
    try {
      parsedArgs = jsonDecode(_args.toString()) as Map<String, dynamic>;
    } catch (_) {}
    return ClawToolCallRecord(
      id: id.isEmpty ? _genId() : id,
      name: name,
      args: parsedArgs,
    );
  }
}

/// 调用 LLM 时发生的可识别错误
class ClawLlmException implements Exception {
  final int statusCode;
  final String message;

  const ClawLlmException({required this.statusCode, required this.message});

  @override
  String toString() => 'ClawLlmException($statusCode): $message';
}

String _genId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  return (now ^ (now >> 16)).toRadixString(36);
}
