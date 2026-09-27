import '../../participation/domain/participation_models.dart';

enum ProjectManagementRole {
  owner('owner'),
  delegate('delegate'),
  none('none');

  const ProjectManagementRole(this.wireValue);
  final String wireValue;

  static ProjectManagementRole fromWire(String value) => switch (value) {
    'owner' => ProjectManagementRole.owner,
    'delegate' => ProjectManagementRole.delegate,
    'none' => ProjectManagementRole.none,
    _ => throw const FormatException('Unsupported Project management role.'),
  };

  bool get isManager => this != ProjectManagementRole.none;
}

enum ProjectDelegateLoadPhase { idle, loading, ready, failure }

enum ProjectDelegateFailureKind {
  forbidden,
  conflict,
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
  });

  final String id;
  final String profileId;
  final String displayName;
  final DateTime delegatedAt;
}

class ProjectDelegateInvitation {
  const ProjectDelegateInvitation({
    required this.id,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime expiresAt;
}

class ProjectDelegateInvitationResult {
  const ProjectDelegateInvitationResult({
    required this.id,
    required this.token,
    required this.expiresAt,
  });

  final String id;
  final String token;
  final DateTime expiresAt;

  String get url => 'https://planets.community/invite/project/$token';
}

class ProjectDelegateInvitePreview {
  const ProjectDelegateInvitePreview({
    required this.isAvailable,
    this.projectId,
    this.projectKind,
    this.projectTitle,
    this.ownerDisplayName,
    this.expiresAt,
  });

  final bool isAvailable;
  final String? projectId;
  final ProjectKind? projectKind;
  final String? projectTitle;
  final String? ownerDisplayName;
  final DateTime? expiresAt;
}

class DelegatedProject {
  const DelegatedProject({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    required this.delegatedAt,
  });

  final String id;
  final ProjectKind kind;
  final String title;
  final String status;
  final DateTime delegatedAt;
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

class ProjectCoorganizersState {
  const ProjectCoorganizersState({
    this.phase = ProjectDelegateLoadPhase.idle,
    this.expectedOwnerId,
    this.projectId,
    this.projectKind,
    this.delegates = const [],
    this.invitations = const [],
    this.failure,
    this.mutating = false,
  });

  final ProjectDelegateLoadPhase phase;
  final String? expectedOwnerId;
  final String? projectId;
  final ProjectKind? projectKind;
  final List<ProjectDelegate> delegates;
  final List<ProjectDelegateInvitation> invitations;
  final ProjectDelegateFailureKind? failure;
  final bool mutating;

  bool isFor(String ownerId, String targetProjectId, ProjectKind kind) =>
      expectedOwnerId == ownerId &&
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
