import 'dart:convert';

enum GroupKind {
  informal,
  organization;

  static GroupKind parse(Object? value) => switch (value) {
    'informal' => informal,
    'organization' => organization,
    _ => throw const FormatException('Unknown group kind.'),
  };
}

enum GroupPublication {
  draft,
  published,
  archived;

  static GroupPublication parse(Object? value) => switch (value) {
    'draft' => draft,
    'published' => published,
    'archived' => archived,
    _ => throw const FormatException('Unknown group publication state.'),
  };
}

/// POSIX space at the canonical SQL boundary; count Unicode scalars, not UTF-16.
String groupTrim(String text) => text.replaceAll(
  RegExp(
    r'^[\x09-\x0d\x20\x85\xa0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]+|[\x09-\x0d\x20\x85\xa0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]+$',
  ),
  '',
);
int groupLength(String text) => text.runes.length;
String groupUuid(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    throw const FormatException('Malformed group UUID.');
  }
  return value;
}

int groupVersion(Object? value) {
  if (value is! int || value < 1) {
    throw const FormatException('Malformed group version.');
  }
  return value;
}

Map<String, dynamic> groupRow(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Malformed group row.');
  }
  return value;
}

String groupText(Object? value, int max) {
  if (value is! String ||
      groupLength(value) > max ||
      groupTrim(value) != value) {
    throw const FormatException('Malformed group text.');
  }
  return value;
}

bool groupBool(Object? value) {
  if (value is! bool) throw const FormatException('Malformed group boolean.');
  return value;
}

DateTime groupDate(Object? value) {
  if (value is! String || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw const FormatException('Malformed group date.');
  }
  final date = DateTime.tryParse(value);
  if (date == null) throw const FormatException('Malformed group date.');
  return date;
}

class GroupContent {
  const GroupContent({
    this.name = '',
    this.description = '',
    this.kind = GroupKind.informal,
    this.locality,
    this.volunteering = false,
  });
  final String name, description;
  final GroupKind kind;
  final String? locality;
  final bool volunteering;
  factory GroupContent.parse(Map<String, dynamic> row) {
    if (!row.containsKey('locality')) {
      throw const FormatException('Missing group locality field.');
    }
    return GroupContent(
      name: groupText(row['name'], 120),
      description: groupText(row['description'], 4000),
      kind: GroupKind.parse(row['group_kind']),
      locality: row['locality'] == null
          ? null
          : groupText(row['locality'], 120),
      volunteering: groupBool(row['volunteering_focus']),
    );
  }
  GroupContent get normalized => GroupContent(
    name: groupTrim(name),
    description: groupTrim(description),
    kind: kind,
    locality: groupTrim(locality ?? '').isEmpty ? null : groupTrim(locality!),
    volunteering: volunteering,
  );
  bool get valid =>
      groupLength(normalized.name) <= 120 &&
      groupLength(normalized.description) <= 4000 &&
      groupLength(normalized.locality ?? '') <= 120;
  bool get publishable =>
      valid &&
      groupLength(normalized.name) >= 2 &&
      groupLength(normalized.description) >= 20;
  Map<String, dynamic> toJson() {
    final n = normalized;
    return {
      'name': n.name,
      'description': n.description,
      'group_kind': kind.name,
      'locality': n.locality,
      'volunteering_focus': volunteering,
    };
  }

  bool same(GroupContent other) =>
      jsonEncode(toJson()) == jsonEncode(other.toJson());
}

class GroupCursor {
  const GroupCursor(this.createdAt, this.id);
  final DateTime createdAt;
  final String id;
  Map<String, dynamic> get params => {
    'p_before_created_at': createdAt.toUtc().toIso8601String(),
    'p_before_id': id,
  };
}

class PublicGroup {
  PublicGroup(Map<String, dynamic> row)
    : id = groupUuid(row['group_id']),
      content = GroupContent.parse(row),
      version = groupVersion(row['version']),
      createdAt = groupDate(row['created_at']),
      updatedAt = groupDate(row['updated_at']);
  final String id;
  final GroupContent content;
  final int version;
  final DateTime createdAt, updatedAt;
  GroupCursor get cursor => GroupCursor(createdAt, id);
}

/// Separate projection: public rows can never manufacture manager authority.
class OwnGroup extends PublicGroup {
  OwnGroup(super.row)
    : publication = GroupPublication.parse(row['publication_state']),
      suppressed = groupBool(row['directory_suppressed']);
  final GroupPublication publication;
  final bool suppressed;
}

class GroupFilters {
  const GroupFilters({
    this.search = '',
    this.kind,
    this.volunteering = false,
    this.locality = '',
  });
  final String search, locality;
  final GroupKind? kind;
  final bool volunteering;
  Map<String, dynamic> get params => {
    'p_search': groupTrim(search),
    'p_group_kind': kind?.name,
    'p_volunteering_focus': volunteering ? true : null,
    'p_locality': groupTrim(locality).isEmpty ? null : groupTrim(locality),
  };
}

class GroupReceipt {
  GroupReceipt(Map<String, dynamic> row)
    : id = groupUuid(row['group_id']),
      version = groupVersion(row['accepted_version']);
  final String id;
  final int version;
}
