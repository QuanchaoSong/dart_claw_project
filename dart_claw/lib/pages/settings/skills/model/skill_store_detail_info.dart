class SkillStoreParameterInfo {
  final String name;
  final String description;
  final bool required;

  const SkillStoreParameterInfo({
    required this.name,
    required this.description,
    required this.required,
  });

  factory SkillStoreParameterInfo.fromJson(Map<String, dynamic> json) {
    return SkillStoreParameterInfo(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      // API 返回的是字符串 "true"/"false"
      required: json['required']?.toString() == 'true',
    );
  }
}

class SkillStoreDetailInfo {
  final String id;
  final String name;
  final String description;
  final String version;
  final List<String> tags;
  final List<SkillStoreParameterInfo> parameters;
  final String content;
  final int downloads;
  final String authorName;
  final String updated;
  final String created;

  const SkillStoreDetailInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.tags,
    required this.parameters,
    required this.content,
    required this.downloads,
    required this.authorName,
    required this.updated,
    required this.created,
  });

  factory SkillStoreDetailInfo.fromJson(Map<String, dynamic> json) {
    final rawParams = json['parameters'] as List<dynamic>? ?? [];
    return SkillStoreDetailInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      version: json['version']?.toString() ?? '1',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      parameters: rawParams
          .map((p) =>
              SkillStoreParameterInfo.fromJson(p as Map<String, dynamic>))
          .toList(),
      content: json['content'] as String? ?? '',
      downloads: json['downloads'] as int? ?? 0,
      authorName: json['author_name'] as String? ?? '',
      updated: json['updated'] as String? ?? '',
      created: json['created'] as String? ?? '',
    );
  }
}
