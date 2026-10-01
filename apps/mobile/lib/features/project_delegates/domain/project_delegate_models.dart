import '../../participation/domain/participation_models.dart';

enum ProjectManagementRole {
  creator('creator'),
  coCreator('co_creator'),
  coOrganizer('co_organizer'),
  none('none');

  const ProjectManagementRole(this.wireValue);
  final String wireValue;

  static ProjectManagementRole fromWire(String value) => switch (value) {
    'creator' || 'owner' => ProjectManagementRole.creator,
    'co_creator' => ProjectManagementRole.coCreator,
    'co_organizer' || 'delegate' => ProjectManagementRole.coOrganizer,
    'none' => ProjectManagementRole.none,
    _ => throw const FormatException('Unsupported Project management role.'),
  };

  bool get isManager => this != ProjectManagementRole.none;
  bool get hasStructuralAuthority =>
      this == ProjectManagementRole.creator ||
      this == ProjectManagementRole.coCreator;
  bool get isDelegated =>
      this == ProjectManagementRole.coCreator ||
      this == ProjectManagementRole.coOrganizer;
}

enum ProjectDelegatedAuthorityRole {
  coOrganizer('co_organizer'),
  coCreator('co_creator');

  const ProjectDelegatedAuthorityRole(this.wireValue);
  final String wireValue;

  static ProjectDelegatedAuthorityRole fromWire(
    String value,
  ) => switch (value) {
    'co_organizer' || 'delegate' => ProjectDelegatedAuthorityRole.coOrganizer,
    'co_creator' => ProjectDelegatedAuthorityRole.coCreator,
    _ => throw const FormatException('Unsupported delegated authority role.'),
  };
}

enum ProjectDelegateLoadPhase { idle, loading, ready, failure }

enum ProjectDelegateFailureKind {
  forbidden,
  conflict,
  capacityConflict,
  unavailable,
  ownerSelfAccept,
  alreadyDelegate,
}

class ProjectDelegate {
  const ProjectDelegate({
    required this.id,
    required this.profileId,
    required this.displayName,
    required this.delegatedAt,
    required this.grantedByProfileId,
    required this.grantedByDisplayName,
    this.authorityRole = ProjectDelegatedAuthorityRole.coOrganizer,
  });

  final String id;
  final String profileId;
  final String displayName;
  final DateTime delegatedAt;
  final String grantedByProfileId;
  final String grantedByDisplayName;
  final ProjectDelegatedAuthorityRole authorityRole;
}

class ProjectDelegateInvitation {
  const ProjectDelegateInvitation({
    required this.id,
    required this.createdAt,
    required this.expiresAt,
    required this.issuerProfileId,
    required this.issuerDisplayName,
    this.requestedAuthorityRole = ProjectDelegatedAuthorityRole.coOrganizer,
  });

  final String id;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String issuerProfileId;
  final String issuerDisplayName;
  final ProjectDelegatedAuthorityRole requestedAuthorityRole;
}

class ProjectDelegateInvitationResult {
  const ProjectDelegateInvitationResult({
    required this.id,
    required this.token,
    required this.expiresAt,
    required this.requestedAuthorityRole,
  });

  final String id;
  final String token;
  final DateTime expiresAt;
  final ProjectDelegatedAuthorityRole requestedAuthorityRole;

  String get url => 'https://planets.community/invite/project/$token';
}

class ProjectDelegateInvitePreview {
  const ProjectDelegateInvitePreview({
    required this.isAvailable,
    this.projectId,
    this.projectKind,
    this.projectTitle,
    this.ownerDisplayName,
    this.issuerDisplayName,
    this.expiresAt,
    this.requestedAuthorityRole,
  });

  final bool isAvailable;
  final String? projectId;
  final ProjectKind? projectKind;
  final String? projectTitle;
  final String? ownerDisplayName;
  final String? issuerDisplayName;
  final DateTime? expiresAt;
  final ProjectDelegatedAuthorityRole? requestedAuthorityRole;
}

class DelegatedProject {
  const DelegatedProject({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    required this.delegatedAt,
    this.authorityRole = ProjectDelegatedAuthorityRole.coOrganizer,
  });

  final String id;
  final ProjectKind kind;
  final String title;
  final String status;
  final DateTime delegatedAt;
  final ProjectDelegatedAuthorityRole authorityRole;
}

class ProjectManagementRoleState {
  const ProjectManagementRoleState({
    this.phase = ProjectDelegateLoadPhase.idle,
    this.expectedProfileId,
    this.projectId,
    this.projectKind,
    this.role,
    this.failure,
  });

  final ProjectDelegateLoadPhase phase;
  final String? expectedProfileId;
  final String? projectId;
  final ProjectKind? projectKind;
  final ProjectManagementRole? role;
  final ProjectDelegateFailureKind? failure;

  bool isFor(String profileId, String targetProjectId, ProjectKind kind) =>
      expectedProfileId == profileId &&
      projectId == targetProjectId &&
      projectKind == kind;
}

class ProjectTeamState {
  const ProjectTeamState({
    this.phase = ProjectDelegateLoadPhase.idle,
    this.expectedProfileId,
    this.projectId,
    this.projectKind,
    this.actorRole,
    this.delegates = const [],
    this.invitations = const [],
    this.failure,
    this.mutating = false,
  });

  final ProjectDelegateLoadPhase phase;
  final String? expectedProfileId;
  final String? projectId;
  final ProjectKind? projectKind;
  final ProjectManagementRole? actorRole;
  final List<ProjectDelegate> delegates;
  final List<ProjectDelegateInvitation> invitations;
  final ProjectDelegateFailureKind? failure;
  final bool mutating;

  bool isFor(String profileId, String targetProjectId, ProjectKind kind) =>
      expectedProfileId == profileId &&
      projectId == targetProjectId &&
      projectKind == kind;
}

class ProjectInviteState {
  const ProjectInviteState({
    this.phase = ProjectDelegateLoadPhase.idle,
    this.token,
    this.identityId,
    this.preview,
    this.failure,
    this.accepting = false,
  });

  final ProjectDelegateLoadPhase phase;
  final String? token;
  final String? identityId;
  final ProjectDelegateInvitePreview? preview;
  final ProjectDelegateFailureKind? failure;
  final bool accepting;

  bool isFor(String routeToken, String? currentIdentityId) =>
      token == routeToken && identityId == currentIdentityId;
}

class DelegatedProjectsState {
  const DelegatedProjectsState({
    this.phase = ProjectDelegateLoadPhase.idle,
    this.expectedProfileId,
    this.items = const [],
    this.failure,
  });

  final ProjectDelegateLoadPhase phase;
  final String? expectedProfileId;
  final List<DelegatedProject> items;
  final ProjectDelegateFailureKind? failure;

  bool get isBusy => phase == ProjectDelegateLoadPhase.loading;
}

class ProjectDelegateIdentityChangedException implements Exception {
  const ProjectDelegateIdentityChangedException();
}
