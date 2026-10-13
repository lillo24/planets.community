enum ProjectWorkspacePhase { idle, loading, ready, failure }

enum ProjectWorkspaceFailureKind {
  invalidUrl,
  invalidName,
  forbidden,
  unavailable,
  conflict,
  removed,
  policyRequired,
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
    required this.createdAt,
    required this.version,
  });

  final String id;
  final String name;
  final String projectId;
  final ProjectWorkspaceUrl url;
  final DateTime updatedAt;
  final DateTime createdAt;
  final int version;
}

class ProjectWorkspaceCursor {
  const ProjectWorkspaceCursor({required this.createdAt, required this.id});
  final DateTime createdAt;
  final String id;
}

class ProjectWorkspacePage {
  const ProjectWorkspacePage({
    required this.items,
    required this.canManage,
    this.nextCursor,
  });
  final List<ProjectWorkspace> items;
  final bool canManage;
  final ProjectWorkspaceCursor? nextCursor;
}

/// Run-only drafts survive policy/route round trips. Only a submitted Add is
/// persisted before network IO, so a restart can reconcile that exact command.
class WorkspaceLinkDraft {
  const WorkspaceLinkDraft({
    required this.actorId,
    required this.projectId,
    required this.name,
    required this.input,
    this.requestId,
    this.linkId,
    this.expectedVersion,
    this.submitted = false,
  });
  final String actorId;
  final String projectId;
  final String name;
  final String input;
  final String? requestId;
  final String? linkId;
  final int? expectedVersion;
  final bool submitted;

  WorkspaceLinkDraft withInput(String name, String input, {bool? submitted}) =>
      WorkspaceLinkDraft(
        actorId: actorId,
        projectId: projectId,
        name: name,
        input: input,
        requestId: requestId,
        linkId: linkId,
        expectedVersion: expectedVersion,
        submitted: submitted ?? this.submitted,
      );
}

class WorkspaceAddReceipt {
  const WorkspaceAddReceipt({
    required this.accepted,
    this.linkId,
    this.name,
    this.url,
    this.item,
  });
  final bool accepted;
  final String? linkId;
  final String? name;
  final ProjectWorkspaceUrl? url;
  final ProjectWorkspace? item;
}

class ProjectWorkspaceState {
  const ProjectWorkspaceState({
    this.phase = ProjectWorkspacePhase.idle,
    this.expectedProfileId,
    this.projectId,
    this.links = const [],
    this.failure,
    this.mutating = false,
    this.canManage = false,
    this.nextCursor,
    this.loadingMore = false,
    this.pageFailure,
    this.pendingAdd,
  });

  final ProjectWorkspacePhase phase;
  final String? expectedProfileId;
  final String? projectId;
  final List<ProjectWorkspace> links;
  final ProjectWorkspaceFailureKind? failure;
  final bool mutating;
  final bool canManage;
  final ProjectWorkspaceCursor? nextCursor;
  final bool loadingMore;
  final ProjectWorkspaceFailureKind? pageFailure;
  final WorkspaceLinkDraft? pendingAdd;

  ProjectWorkspaceState copyWith({
    ProjectWorkspacePhase? phase,
    List<ProjectWorkspace>? links,
    bool? mutating,
    bool? canManage,
    bool? loadingMore,
    ProjectWorkspaceCursor? nextCursor,
    bool clearCursor = false,
    ProjectWorkspaceFailureKind? failure,
    bool clearFailure = false,
    ProjectWorkspaceFailureKind? pageFailure,
    bool clearPageFailure = false,
    WorkspaceLinkDraft? pendingAdd,
    bool clearPending = false,
  }) => ProjectWorkspaceState(
    phase: phase ?? this.phase,
    expectedProfileId: expectedProfileId,
    projectId: projectId,
    links: links ?? this.links,
    mutating: mutating ?? this.mutating,
    canManage: canManage ?? this.canManage,
    loadingMore: loadingMore ?? this.loadingMore,
    nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
    failure: clearFailure ? null : failure ?? this.failure,
    pageFailure: clearPageFailure ? null : pageFailure ?? this.pageFailure,
    pendingAdd: clearPending ? null : pendingAdd ?? this.pendingAdd,
  );

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
