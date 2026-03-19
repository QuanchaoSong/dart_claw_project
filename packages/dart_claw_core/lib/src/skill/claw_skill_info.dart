/// Skill 的单个参数定义
class ClawSkillParameter {
  final String name;
  final String description;
  final bool required;

  const ClawSkillParameter({
    required this.name,
    required this.description,
    this.required = true,
  });
}

/// Skill 的单个步骤定义
class ClawSkillStep {
  /// 步骤标题（### Step N: <title> 中的 title）
  final String title;

  /// 该步骤预期调用的工具名列表（如 ['run_command']）
  final List<String> expectedTools;

  /// 步骤说明（传给 LLM 的执行描述）
  final String description;

  /// 判断步骤成功的条件说明
  final String successCondition;

  /// 该步骤失败时展示给用户的报告文案
  final String failureReport;

  const ClawSkillStep({
    required this.title,
    required this.expectedTools,
    required this.description,
    required this.successCondition,
    required this.failureReport,
  });
}

/// 一个完整的 Skill 定义，对应一个 SKILL.md 文件
class ClawSkillInfo {
  /// 唯一标识（frontmatter name 字段）
  final String name;

  /// 供 LLM 匹配判断用的描述（frontmatter description 字段）
  final String description;

  final int version;

  /// 可选参数列表（frontmatter parameters 字段）
  final List<ClawSkillParameter> parameters;

  /// 执行原则（## 执行原则 区块的全文，注入到 system prompt）
  final String executionPrinciples;

  /// 步骤列表
  final List<ClawSkillStep> steps;

  const ClawSkillInfo({
    required this.name,
    required this.description,
    this.version = 1,
    this.parameters = const [],
    this.executionPrinciples = '',
    required this.steps,
  });

  /// 将参数占位符 `{paramName}` 替换为实际值，返回注入后的 Skill 全文（用于 system prompt）
  String resolveAndFormat(Map<String, String> paramValues) {
    String replace(String text) {
      var result = text;
      for (final entry in paramValues.entries) {
        result = result.replaceAll('{${entry.key}}', entry.value);
      }
      return result;
    }

    final buf = StringBuffer();
    buf.writeln('## Skill: $name');
    buf.writeln();
    if (executionPrinciples.isNotEmpty) {
      buf.writeln(replace(executionPrinciples));
      buf.writeln();
    }
    buf.writeln('## 步骤');
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      buf.writeln();
      buf.writeln('### Step ${i + 1}: ${replace(step.title)}');
      if (step.expectedTools.isNotEmpty) {
        buf.writeln('- **预期工具**: ${step.expectedTools.join(', ')}');
      }
      buf.writeln('- **说明**: ${replace(step.description)}');
      buf.writeln('- **成功条件**: ${replace(step.successCondition)}');
      buf.writeln('- **失败报告**: ${replace(step.failureReport)}');
    }
    return buf.toString();
  }

  /// 生成供 SkillMatcher 使用的摘要（name + description + parameters）
  ///
  /// 包含参数定义，让 LLM 知道准确的参数名称，避免 key 不匹配导致校验失败。
  String get matcherSummary {
    final sb = StringBuffer('- name: $name\n  description: $description');
    if (parameters.isNotEmpty) {
      sb.write('\n  parameters:');
      for (final p in parameters) {
        final reqLabel = p.required ? ' (required)' : ' (optional)';
        sb.write('\n    - ${p.name}: ${p.description}$reqLabel');
      }
    }
    return sb.toString();
  }
}
