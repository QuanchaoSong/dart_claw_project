import 'package:flutter/foundation.dart';

import '../llm/claw_llm_client.dart';
import 'claw_skill_info.dart';
import 'claw_skill_loader.dart';
import 'claw_skill_matcher.dart';

/// [ClawSkillResolver.resolve] 的返回值：匹配结果 + 可直接使用的运行上下文。
class ClawSkillResolved {
  const ClawSkillResolved({
    required this.systemPrompt,
    required this.skillSteps,
    this.match,
    this.resolvedSkillContent,
  });

  /// 完整 system prompt（基础 prompt + 可选 Skill 注入），可直接传给 LLM。
  final String systemPrompt;

  /// 当前 Skill 的步骤列表，用于 Agent loop 内的偏离检测（无匹配时为空）。
  final List<ClawSkillStep> skillSteps;

  /// 命中的 Skill 匹配结果，null 表示无匹配。
  final ClawSkillMatch? match;

  /// 注入到 system prompt 的 Skill 展开内容，供 UI 事件（SkillActivated）使用。
  final String? resolvedSkillContent;

  bool get hasSkill => match != null;
}

/// Skill 解析器：加载、匹配并构建完整 system prompt。
///
/// 将 [ClawSkillLoader] + [ClawSkillMatcher] + prompt 组装封装为单一调用，
/// 供 [ClawAgentRunner] 使用，使 Runner 完全不感知 Skill 注入细节。
///
/// 所有异常内部捕获并打印日志，不向外抛出——匹配失败不应中断 Agent 任务。
class ClawSkillResolver {
  const ClawSkillResolver({required this.client});

  final ClawLlmClient client;

  // Skill 模式下追加到 basePrompt 末尾的指令头（resolvedContent 紧随其后）
  static const _skillHeaderSuffix = '''

---

You are currently executing a SKILL. Follow the rules below WITHOUT EXCEPTION:
1. Execute ONLY the steps defined in the skill, in order. Do NOT introduce tools or methods not listed in a step\'s "Expected tools".
2. If any step fails (non-zero exit code or error output), you MUST stop immediately. Do NOT try alternative approaches.
3. Report failures exactly as specified in the step\'s "Failure report" field.

''';

  /// 为 [userText] 解析 Skill 并构建完整 system prompt。
  ///
  /// - [basePrompt]：Agent 的基础 system prompt，由调用方（Runner）持有。
  /// - [explicitSkillName]：非 null 时跳过自动匹配，直接定位目标 Skill。
  /// - 返回的 [ClawSkillResolved.systemPrompt] 可直接用于首轮 LLM API 调用。
  Future<ClawSkillResolved> resolve({
    required String userText,
    required String basePrompt,
    String? explicitSkillName,
  }) async {
    ClawSkillMatch? match;
    try {
      final availableSkills = await ClawSkillLoader.loadAll();
      if (availableSkills.isNotEmpty) {
        final matcher = ClawSkillMatcher(client: client);
        if (explicitSkillName != null) {
          final candidates =
              availableSkills.where((s) => s.name == explicitSkillName).toList();
          if (candidates.isNotEmpty) {
            match = await matcher.match(
                userTask: userText, availableSkills: candidates);
          }
        } else {
          match =
              await matcher.match(userTask: userText, availableSkills: availableSkills);
        }
      }
    } catch (e) {
      debugPrint('[ClawSkillResolver] resolve failed: $e');
    }

    if (match == null) {
      return ClawSkillResolved(systemPrompt: basePrompt, skillSteps: const []);
    }

    final resolvedContent = match.skill.resolveAndFormat(match.params);
    return ClawSkillResolved(
      systemPrompt: '$basePrompt$_skillHeaderSuffix$resolvedContent',
      skillSteps: match.skill.steps,
      match: match,
      resolvedSkillContent: resolvedContent,
    );
  }
}
