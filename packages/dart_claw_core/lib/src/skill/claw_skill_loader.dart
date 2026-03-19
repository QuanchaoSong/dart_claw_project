import 'dart:io';

import 'package:flutter/foundation.dart';

import 'claw_skill_info.dart';

/// 从 `~/.dart_claw/skills/` 目录加载所有 SKILL.md 文件
///
/// 文件格式：
/// ```
/// ---
/// name: browse-and-show-image
/// description: "..."
/// version: 1
/// parameters:
///   - name: query
///     description: "搜索关键词"
///     required: true
/// ---
///
/// ## 执行原则
/// ...
///
/// ## 步骤
///
/// ### Step 1: 步骤标题
/// - **预期工具**: `run_command`
/// - **说明**: ...
/// - **成功条件**: ...
/// - **失败报告**: ...
/// ```
class ClawSkillLoader {
  static const _skillsRelativePath = '.dart_claw/skills';

  /// 返回 skills 目录的绝对路径
  static String get skillsDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/$_skillsRelativePath';
  }

  /// 加载所有可用的 skill。
  ///
  /// 解析失败的文件会被跳过并打印警告，不会让整个加载中断。
  static Future<List<ClawSkillInfo>> loadAll() async {
    final dir = Directory(skillsDir);
    if (!await dir.exists()) return [];

    final skills = <ClawSkillInfo>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!path.endsWith('.md')) continue;

      try {
        final content = await entity.readAsString();
        final skill = _parse(content, path);
        if (skill != null) skills.add(skill);
      } catch (e) {
        debugPrint('[ClawSkillLoader] Failed to load $path: $e');
      }
    }
    return skills;
  }

  // ─── 解析 ────────────────────────────────────────────────────────────────

  static ClawSkillInfo? _parse(String content, String path) {
    // 分离 frontmatter 和 body
    final (frontmatter, body) = _splitFrontmatter(content);
    if (frontmatter == null) {
      debugPrint('[ClawSkillLoader] No frontmatter found in $path, skipping.');
      return null;
    }

    final fm = _parseFrontmatter(frontmatter);
    final name = fm['name'] as String?;
    final description = fm['description'] as String?;
    if (name == null || name.isEmpty) {
      debugPrint('[ClawSkillLoader] Missing "name" in $path, skipping.');
      return null;
    }
    if (description == null || description.isEmpty) {
      debugPrint('[ClawSkillLoader] Missing "description" in $path, skipping.');
      return null;
    }

    final version = int.tryParse(fm['version']?.toString() ?? '') ?? 1;
    final parameters = _parseParameters(fm['parameters']);
    final (principles, steps) = _parseBody(body);

    return ClawSkillInfo(
      name: name,
      description: description,
      version: version,
      parameters: parameters,
      executionPrinciples: principles,
      steps: steps,
    );
  }

  /// 返回 (frontmatter文本, body文本)，frontmatter 不存在时返回 (null, 原始内容)
  static (String?, String) _splitFrontmatter(String content) {
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith('---')) return (null, content);

    final firstEnd = trimmed.indexOf('\n---', 3);
    if (firstEnd == -1) return (null, content);

    final fm = trimmed.substring(3, firstEnd).trim();
    final body = trimmed.substring(firstEnd + 4).trimLeft();
    return (fm, body);
  }

  /// 极简 YAML 解析：只处理顶层 key: value 和顶层列表 key: [objects]
  ///
  /// 返回 Map<String, dynamic>，其中列表字段返回 List<Map<String, String>>。
  static Map<String, dynamic> _parseFrontmatter(String text) {
    final result = <String, dynamic>{};
    final lines = text.split('\n');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // 跳过空行和注释
      if (line.trim().isEmpty || line.trim().startsWith('#')) {
        i++;
        continue;
      }

      // 顶层 key: value
      final colonIdx = line.indexOf(':');
      if (colonIdx == -1) {
        i++;
        continue;
      }

      final key = line.substring(0, colonIdx).trim();
      final rawValue = line.substring(colonIdx + 1).trim();

      // 没有值 → 可能是列表型字段（下面缩进的 - 行）
      if (rawValue.isEmpty) {
        i++;
        final items = <Map<String, String>>[];
        while (i < lines.length) {
          final itemLine = lines[i];
          // 下一个顶层 key 出现，退出列表解析
          if (itemLine.isNotEmpty &&
              !itemLine.startsWith(' ') &&
              !itemLine.startsWith('\t')) {
            break;
          }
          final trimmedItem = itemLine.trim();
          if (trimmedItem.startsWith('- ')) {
            // 新的 list item 开始
            final firstField = trimmedItem.substring(2).trim();
            final obj = <String, String>{};
            _parseYamlField(firstField, obj);
            i++;
            // 继续读同一对象的续行（以空格缩进）
            while (i < lines.length) {
              final subLine = lines[i];
              final subTrimmed = subLine.trim();
              if (subTrimmed.isEmpty) break;
              if (subTrimmed.startsWith('- ')) break;
              if (!subLine.startsWith(' ') && !subLine.startsWith('\t')) break;
              _parseYamlField(subTrimmed, obj);
              i++;
            }
            items.add(obj);
          } else {
            i++;
          }
        }
        result[key] = items;
        continue;
      }

      // 有值 → 去掉引号
      result[key] = _unquote(rawValue);
      i++;
    }

    return result;
  }

  /// 把 "key: value" 写入 map
  static void _parseYamlField(String text, Map<String, String> map) {
    final idx = text.indexOf(':');
    if (idx == -1) return;
    final k = text.substring(0, idx).trim();
    final v = _unquote(text.substring(idx + 1).trim());
    map[k] = v;
  }

  /// 去掉首尾的单引号或双引号
  static String _unquote(String s) {
    if (s.length >= 2 &&
        ((s.startsWith('"') && s.endsWith('"')) ||
            (s.startsWith("'") && s.endsWith("'")))) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  /// 把 frontmatter 里的 parameters 列表解析成 [ClawSkillParameter]
  static List<ClawSkillParameter> _parseParameters(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((item) {
      if (item is! Map) return null;
      final name = item['name'] as String? ?? '';
      if (name.isEmpty) return null;
      return ClawSkillParameter(
        name: name,
        description: item['description'] as String? ?? '',
        required: (item['required'] as String? ?? 'true').toLowerCase() != 'false',
      );
    }).whereType<ClawSkillParameter>().toList();
  }

  // ─── Body 解析 ──────────────────────────────────────────────────────────

  /// 解析 body，返回 (执行原则文本, 步骤列表)
  static (String, List<ClawSkillStep>) _parseBody(String body) {
    // 把 body 按 "### " 分割成步骤块
    // 第一段（在第一个 "### " 之前）包含执行原则等说明区块
    final stepPattern = RegExp(r'^### ', multiLine: true);
    final stepMatches = stepPattern.allMatches(body).toList();

    if (stepMatches.isEmpty) {
      return (_extractPrinciples(body), []);
    }

    final preSteps = body.substring(0, stepMatches.first.start);
    final principles = _extractPrinciples(preSteps);

    final steps = <ClawSkillStep>[];
    for (var i = 0; i < stepMatches.length; i++) {
      final start = stepMatches[i].start;
      final end = i + 1 < stepMatches.length ? stepMatches[i + 1].start : body.length;
      final stepText = body.substring(start, end).trim();
      final step = _parseStep(stepText);
      if (step != null) steps.add(step);
    }

    return (principles, steps);
  }

  /// 从 body 头部提取 "## 执行原则" 区块内容
  static String _extractPrinciples(String text) {
    // 匹配 "## 执行原则" 到下一个 "## " 之间的内容
    final match = RegExp(
      r'##\s*执行原则\s*\n([\s\S]*?)(?=\n##\s|\Z)',
      multiLine: true,
    ).firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }

  /// 解析单个步骤块
  ///
  /// 格式：
  /// ```
  /// ### Step N: 步骤标题
  /// - **预期工具**: `run_command`
  /// - **说明**: 描述文字
  /// - **成功条件**: 条件文字
  /// - **失败报告**: 报告文字
  /// ```
  static ClawSkillStep? _parseStep(String text) {
    final lines = text.split('\n');
    if (lines.isEmpty) return null;

    // 第一行是标题：### Step N: title
    final titleMatch = RegExp(r'^###\s+(?:Step\s+\d+\s*[：:]\s*)?(.+)$')
        .firstMatch(lines.first.trim());
    final title = titleMatch?.group(1)?.trim() ?? lines.first.trim();

    String tools = '';
    String description = '';
    String successCondition = '';
    String failureReport = '';

    for (final line in lines.skip(1)) {
      final t = line.trim();
      if (t.startsWith('- **预期工具**:') || t.startsWith('- **预期工具**：')) {
        tools = t.replaceFirst(RegExp(r'^-\s*\*\*预期工具\*\*[：:]\s*'), '').trim();
      } else if (t.startsWith('- **说明**:') || t.startsWith('- **说明**：')) {
        description = t.replaceFirst(RegExp(r'^-\s*\*\*说明\*\*[：:]\s*'), '').trim();
      } else if (t.startsWith('- **成功条件**:') || t.startsWith('- **成功条件**：')) {
        successCondition = t.replaceFirst(RegExp(r'^-\s*\*\*成功条件\*\*[：:]\s*'), '').trim();
      } else if (t.startsWith('- **失败报告**:') || t.startsWith('- **失败报告**：')) {
        failureReport = t.replaceFirst(RegExp(r'^-\s*\*\*失败报告\*\*[：:]\s*'), '').trim();
      }
    }

    // 解析工具名列表：`run_command`, `write_file` → ['run_command', 'write_file']
    final expectedTools = _parseToolNames(tools);

    return ClawSkillStep(
      title: title,
      expectedTools: expectedTools,
      description: description,
      successCondition: successCondition,
      failureReport: failureReport,
    );
  }

  /// 从 "预期工具" 字段解析工具名列表
  /// 支持反引号包裹的名称，逗号或顿号分隔
  static List<String> _parseToolNames(String raw) {
    if (raw.isEmpty) return [];
    // 提取反引号内的内容
    final matches = RegExp(r'`([^`]+)`').allMatches(raw);
    if (matches.isNotEmpty) {
      return matches.map((m) => m.group(1)!.trim()).toList();
    }
    // 没有反引号，直接按逗号分割
    return raw.split(RegExp(r'[,，、]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
}
