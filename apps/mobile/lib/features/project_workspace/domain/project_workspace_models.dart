enum ProjectWorkspacePhase { idle, loading, ready, failure }

enum ProjectWorkspaceFailureKind { invalidUrl, forbidden, unavailable }

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
    final normalized = input.trim();
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
    required this.projectId,
    required this.url,
    required this.updatedAt,
  });

  final String projectId;
  final ProjectWorkspaceUrl url;
  final DateTime updatedAt;
}

class ProjectWorkspaceState {
  const ProjectWorkspaceState({
    this.phase = ProjectWorkspacePhase.idle,
    this.expectedProfileId,
    this.projectId,
    this.workspace,
    this.failure,
    this.mutating = false,
  });

  final ProjectWorkspacePhase phase;
  final String? expectedProfileId;
  final String? projectId;
  final ProjectWorkspace? workspace;
  final ProjectWorkspaceFailureKind? failure;
  final bool mutating;

  bool isFor(String profileId, String targetProjectId) =>
      expectedProfileId == profileId && projectId == targetProjectId;
}
