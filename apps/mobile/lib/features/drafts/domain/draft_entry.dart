/// Typed in-memory navigation origin; never accepts a user-supplied return URL.
enum DraftEditorOrigin { hub }

enum DraftKind { project, table, donate, exchange }

/// Presentation identity keeps IDs from different canonical domains distinct.
class DraftEntry {
  const DraftEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.updatedAt,
    this.coverObjectPath,
  });

  final DraftKind kind;
  final String id;
  final String? title;
  final DateTime updatedAt;
  final String? coverObjectPath;

  String get editPath => switch (kind) {
    DraftKind.project => '/proposals/$id/edit',
    DraftKind.table => '/tavoli/$id/edit',
    DraftKind.donate || DraftKind.exchange => '/resources/$id/edit',
  };
}

abstract final class DraftRoutes {
  static const path = '/drafts';
  static String contextual(Set<DraftKind> kinds) => Uri(
    path: path,
    queryParameters: kinds.isEmpty
        ? null
        : {'types': kinds.map((kind) => kind.name).join(',')},
  ).toString();

  static Set<DraftKind> parse(String? encoded) => {
    for (final kind in DraftKind.values)
      if ((encoded ?? '').split(',').contains(kind.name)) kind,
  };
}
