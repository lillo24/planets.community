enum ProjectWorkspacePhase { idle, loading, ready, failure }

enum ProjectWorkspaceFailureKind {
  invalidUrl,
  invalidName,
  forbidden,
  unavailable,
}

enum ProjectWorkspaceUrlFailure { empty, tooLong, notHttps, invalid }

class ProjectWorkspaceUrlException implements Exception {
  const ProjectWorkspaceUrlException(this.failure);

  final ProjectWorkspaceUrlFailure failure;
}

class ProjectWorkspaceUrl {
  const ProjectWorkspaceUrl._(this.value, this.uri);

  static const maxLength = 2048;

  final String value;
  final Uri uri;

  String get hostname => uri.host;

  static ProjectWorkspaceUrl parse(String input) {
    final normalized = input.trim().replaceFirst(
      RegExp(r'^https://', caseSensitive: false),
      'https://',
    );
    if (normalized.isEmpty) {
      throw const ProjectWorkspaceUrlException(
        ProjectWorkspaceUrlFailure.empty,
      );
    }
    if (normalized.length > maxLength) {
      throw const ProjectWorkspaceUrlException(
        ProjectWorkspaceUrlFailure.tooLong,
      );
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.scheme.isEmpty) {
      throw const ProjectWorkspaceUrlException(
        ProjectWorkspaceUrlFailure.invalid,
      );
    }
    if (uri.scheme.toLowerCase() != 'https') {
      throw const ProjectWorkspaceUrlException(
        ProjectWorkspaceUrlFailure.notHttps,
      );
    }
    final containsUnsafeWhitespace = normalized.runes.any(
      (rune) => rune <= 0x20 || rune == 0x7f,
    );
    if (uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        containsUnsafeWhitespace) {
      throw const ProjectWorkspaceUrlException(
        ProjectWorkspaceUrlFailure.invalid,
      );
    }
    return ProjectWorkspaceUrl._(normalized, uri);
  }
}

class ProjectWorkspace {
  const ProjectWorkspace({
    required this.id,
    required this.name,
    required this.projectId,
    required this.url,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String projectId;
  final ProjectWorkspaceUrl url;
  final DateTime updatedAt;
}

class ProjectWorkspaceState {
  const ProjectWorkspaceState({
    this.phase = ProjectWorkspacePhase.idle,
    this.expectedProfileId,
    this.projectId,
    this.links = const [],
    this.failure,
    this.mutating = false,
  });

  final ProjectWorkspacePhase phase;
  final String? expectedProfileId;
  final String? projectId;
  final List<ProjectWorkspace> links;
  final ProjectWorkspaceFailureKind? failure;
  final bool mutating;

  bool isFor(String profileId, String targetProjectId) =>
      expectedProfileId == profileId && projectId == targetProjectId;
}

class ProjectWorkspaceNameException implements Exception {
  const ProjectWorkspaceNameException();
}

String validateProjectWorkspaceName(String input) {
  final name = input.trim();
  if (name.isEmpty ||
      name.runes.length > 120 ||
      name.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
    throw const ProjectWorkspaceNameException();
  }
  return name;
}

enum ProjectWorkspaceIconType { document, spreadsheet, video, drive, link }

// Whole words avoid treating "callback", "doctor" or "teamster" as tool names.
// Specific sheet terms precede doc terms ("Google Docs budget sheet").
ProjectWorkspaceIconType classifyProjectWorkspace(String name, Uri uri) {
  final words = name.toLowerCase().split(RegExp(r'[^a-z0-9]+')).toSet();
  for (final entry in {
    ProjectWorkspaceIconType.spreadsheet: {
      'sheet',
      'sheets',
      'spreadsheet',
      'foglio',
      'excel',
      'tabella',
    },
    ProjectWorkspaceIconType.document: {
      'documento',
      'document',
      'doc',
      'docs',
      'testo',
    },
    ProjectWorkspaceIconType.video: {
      'meeting',
      'call',
      'riunione',
      'chiamata',
      'meet',
      'zoom',
      'teams',
    },
    ProjectWorkspaceIconType.drive: {'drive', 'cartella', 'folder'},
  }.entries) {
    if (words.intersection(entry.value).isNotEmpty) return entry.key;
  }
  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.map((s) => s.toLowerCase()).toList();
  if (host == 'docs.google.com' && segments.isNotEmpty) {
    if (segments.first == 'spreadsheets') {
      return ProjectWorkspaceIconType.spreadsheet;
    }
    if (segments.first == 'document') return ProjectWorkspaceIconType.document;
  }
  if (host == 'meet.google.com' ||
      host == 'teams.microsoft.com' ||
      host == 'zoom.us' ||
      host.endsWith('.zoom.us')) {
    return ProjectWorkspaceIconType.video;
  }
  if (host == 'drive.google.com') return ProjectWorkspaceIconType.drive;
  return ProjectWorkspaceIconType.link;
}
