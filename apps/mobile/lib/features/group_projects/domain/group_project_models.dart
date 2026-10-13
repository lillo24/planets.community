class ProjectGroupAttribution {
  const ProjectGroupAttribution({this.groupId, this.name, this.kind});
  final String? groupId;
  final String? name;
  final String? kind;
  bool get available => groupId != null;

  static ProjectGroupAttribution? parse(Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw const FormatException('Invalid Project attribution.');
    }
    final row = value.cast<String, dynamic>();
    if (row['state'] == 'unavailable') {
      if (row.length != 2 || row['project_id'] is! String) {
        throw const FormatException('Invalid neutral Project attribution.');
      }
      return const ProjectGroupAttribution();
    }
    if (row['state'] != 'group' ||
        row['group_id'] is! String ||
        row['name'] is! String ||
        !{'informal', 'organization'}.contains(row['group_kind'])) {
      throw const FormatException('Invalid public Project attribution.');
    }
    return ProjectGroupAttribution(
      groupId: row['group_id'] as String,
      name: row['name'] as String,
      kind: row['group_kind'] as String,
    );
  }
}

class ProjectGroupBinding {
  const ProjectGroupBinding({
    this.groupId,
    this.name,
    this.version = 0,
    this.frozen = false,
  });
  final String? groupId;
  final String? name;
  final int version;
  final bool frozen;
  factory ProjectGroupBinding.parse(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid private Project attribution.');
    }
    final row = value.cast<String, dynamic>();
    if (row['version'] is! int ||
        row['frozen'] is! bool ||
        (row['version'] as int) < 0 ||
        (row['group_id'] != null && row['group_id'] is! String) ||
        (row['group_name'] != null && row['group_name'] is! String)) {
      throw const FormatException('Invalid private Project attribution.');
    }
    return ProjectGroupBinding(
      groupId: row['group_id'] as String?,
      name: row['group_name'] as String?,
      version: row['version'] as int,
      frozen: row['frozen'] as bool,
    );
  }
}

class PublishableGroup {
  const PublishableGroup(this.id, this.name, this.kind, this.createdAt);
  final String id, name, kind;
  final DateTime createdAt;
  factory PublishableGroup.parse(Map<String, dynamic> row) {
    if (row['id'] is! String ||
        row['name'] is! String ||
        !{'informal', 'organization'}.contains(row['group_kind']) ||
        row['created_at'] is! String) {
      throw const FormatException('Invalid publishable group.');
    }
    return PublishableGroup(
      row['id'] as String,
      row['name'] as String,
      row['group_kind'] as String,
      DateTime.parse(row['created_at'] as String),
    );
  }
}

class GroupProject {
  const GroupProject(
    this.id,
    this.title,
    this.summary,
    this.recurring,
    this.idea,
    this.publishedAt,
  );
  final String id, title, summary;
  final bool recurring, idea;
  final DateTime publishedAt;
  String get route => recurring ? '/tavoli/$id' : '/proposals/$id';
  factory GroupProject.parse(Map<String, dynamic> row) {
    if (!{'one_time', 'recurring'}.contains(row['project_kind']) ||
        (row['project_kind'] == 'one_time' &&
            !{'idea', 'defined'}.contains(row['definition_phase'])) ||
        (row['project_kind'] == 'recurring' &&
            row['definition_phase'] != null)) {
      throw const FormatException('Invalid group Project kind.');
    }
    return GroupProject(
      row['project_id'] as String,
      row['title'] as String,
      row['summary'] as String,
      row['project_kind'] == 'recurring',
      row['definition_phase'] == 'idea',
      DateTime.parse(row['published_at'] as String),
    );
  }
}
