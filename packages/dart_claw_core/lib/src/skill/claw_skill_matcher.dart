import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../llm/claw_llm_client.dart';
import '../llm/claw_llm_delta.dart';
import 'claw_skill_info.dart';

/// 单次匹配结果：命中的 skill + 已从用户消息中提取的参数值
class ClawSkillMatch {
  final ClawSkillInfo skill;

  /// 占位符参数的实际值，key 对应 [ClawSkillParameter.name]
  final Map<String, String> params;

  const ClawSkillMatch({required this.skill, required this.params});
}

/// 轻量 LLM 调用：判断用户任务是否匹配某个 skill，并提取参数值
///
/// 单次单轮调用，不携带工具定义，只要求模型返回一段 JSON。
class ClawSkillMatcher {
  final ClawLlmClient client;

  const ClawSkillMatcher({required this.client});

  /// 从 [availableSkills] 中为 [userTask] 挑选最匹配的 skill。
  ///
  /// 返回 null 表示没有合适的 skill，agent 按普通流程执行。
  Future<ClawSkillMatch?> match({
    required String userTask,
    required List<ClawSkillInfo> availableSkills,
  }) async {
    if (availableSkills.isEmpty) return null;

    final systemPrompt = _buildSystemPrompt(availableSkills);
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userTask},
    ];

    // 收集完整响应文本（不需要流式，但 streamChat 是唯一接口）
    final buf = StringBuffer();
    try {
      await for (final delta in client.streamChat(messages: messages)) {
        if (delta is ClawLlmTextDelta) buf.write(delta.text);
        // 忽略 reasoning / tool_calls / finish
      }
    } catch (e) {
      debugPrint('[ClawSkillMatcher] LLM call failed: $e');
      return null;
    }

    return _parseResponse(buf.toString(), availableSkills);
  }

  // ─── 内部实现 ────────────────────────────────────────────────────────────

  String _buildSystemPrompt(List<ClawSkillInfo> skills) {
    final skillList = skills.map((s) => s.matcherSummary).join('\n');
    return '''
You are a skill-matching assistant. Your ONLY job is to decide whether the user's task matches one of the available skills below, and if so, extract the required parameter values.

## Available Skills

$skillList

## Response Format

Respond with ONLY a single JSON object on one line. No explanation, no markdown, no code block.

If the task matches a skill:
{"skill": "<name>", "params": {"<param1>": "<value1>"}}

If no skill matches:
{"skill": null}

Rules:
- Only match if you are confident the user's task aligns with the skill description.
- Extract parameter values exactly as mentioned by the user (preserve original language).
- If a required parameter cannot be inferred from the task, respond with {"skill": null}.
- Do not invent parameters not listed in the skill.
''';
  }

  ClawSkillMatch? _parseResponse(
      String raw, List<ClawSkillInfo> availableSkills) {
    // 找到第一个完整 JSON 对象
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(raw.trim());
    if (jsonMatch == null) {
      debugPrint('[ClawSkillMatcher] No JSON found in response: $raw');
      return null;
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ClawSkillMatcher] JSON parse error: $e\nRaw: $raw');
      return null;
    }

    final skillName = json['skill'];
    if (skillName == null) return null; // 明确表示没有匹配

    if (skillName is! String) {
      debugPrint('[ClawSkillMatcher] Unexpected skill type: $skillName');
      return null;
    }

    final skill = availableSkills.firstWhere(
      (s) => s.name == skillName,
      orElse: () => throw StateError('Unknown skill: $skillName'),
    );

    final rawParams = json['params'];
    final params = <String, String>{};
    if (rawParams is Map) {
      for (final entry in rawParams.entries) {
        params[entry.key.toString()] = entry.value.toString();
      }
    }

    // 校验必填参数是否都存在
    for (final param in skill.parameters) {
      if (param.required && !params.containsKey(param.name)) {
        debugPrint(
            '[ClawSkillMatcher] Required param "${param.name}" missing for skill "$skillName"');
        return null;
      }
    }

    debugPrint('[ClawSkillMatcher] Matched skill: $skillName, params: $params');
    return ClawSkillMatch(skill: skill, params: params);
  }
}
