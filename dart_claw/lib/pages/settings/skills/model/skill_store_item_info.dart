class SkillStoreItemInfo {
  final String id;
  final String name;
  final String description;
  final String version;
  final List<String> tags;
  final int downloads;
  final String authorName;
  final String updated;

  const SkillStoreItemInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.tags,
    required this.downloads,
    required this.authorName,
    required this.updated,
  });

  factory SkillStoreItemInfo.fromJson(Map<String, dynamic> json) {
    return SkillStoreItemInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      version: json['version']?.toString() ?? '1',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      downloads: json['downloads'] as int? ?? 0,
      authorName: json['author_name'] as String? ?? '',
      updated: json['updated'] as String? ?? '',
    );
  }
}
