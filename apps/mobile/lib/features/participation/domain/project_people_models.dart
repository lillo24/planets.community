import '../../project_delegates/domain/project_delegate_models.dart';

class ProjectPerson {
  const ProjectPerson({
    required this.profileId,
    required this.displayName,
    required this.isCreator,
    required this.roleRank,
    this.authorityRole,
    this.delegateId,
    this.membershipId,
    this.joinedAt,
  });
  final String profileId;
  final String displayName;
  final bool isCreator;
  final int roleRank;
  final ProjectDelegatedAuthorityRole? authorityRole;
  final String? delegateId;
  final String? membershipId;
  final DateTime? joinedAt;
  bool get isParticipant => membershipId != null;
  bool get isManager => isCreator || authorityRole != null;
  factory ProjectPerson.fromJson(Map<String, dynamic> row) => ProjectPerson(
    profileId: row['profile_id'] as String,
    displayName: row['display_name'] as String,
    isCreator: row['is_creator'] as bool,
    roleRank: row['role_rank'] as int,
    authorityRole: row['authority_role'] == null
        ? null
        : ProjectDelegatedAuthorityRole.fromWire(
            row['authority_role'] as String,
          ),
    delegateId: row['delegate_id'] as String?,
    membershipId: row['current_membership_id'] as String?,
    joinedAt: row['joined_at'] == null
        ? null
        : DateTime.parse(row['joined_at'] as String),
  );
}

class ProjectRoleOffer {
  const ProjectRoleOffer({
    required this.id,
    required this.targetProfileId,
    required this.targetDisplayName,
    required this.issuerProfileId,
    required this.issuerDisplayName,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
    required this.membershipId,
  });
  final String id;
  final String targetProfileId;
  final String targetDisplayName;
  final String issuerProfileId;
  final String issuerDisplayName;
  final ProjectDelegatedAuthorityRole role;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String membershipId;
  factory ProjectRoleOffer.fromJson(Map<String, dynamic> row) =>
      ProjectRoleOffer(
        id: row['offer_id'] as String,
        targetProfileId: row['target_profile_id'] as String,
        targetDisplayName: row['target_display_name'] as String,
        issuerProfileId: row['issuer_profile_id'] as String,
        issuerDisplayName: row['issuer_display_name'] as String,
        role: ProjectDelegatedAuthorityRole.fromWire(
          row['requested_authority_role'] as String,
        ),
        createdAt: DateTime.parse(row['created_at'] as String),
        expiresAt: DateTime.parse(row['expires_at'] as String),
        membershipId: row['target_membership_id'] as String,
      );
}

enum PeopleSection { people, requests, history, offers }

enum PeopleFailure { forbidden, capacity, conflict, unavailable }

class PeoplePage<T> {
  const PeoplePage({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.failure,
    this.cursor,
  });
  final List<T> items;
  final bool loading;
  final bool hasMore;
  final PeopleFailure? failure;
  final T? cursor;
}

enum PeopleAction {
  commitments,
  actualContributions,
  removeParticipant,
  inviteCoOrganizer,
  inviteCoCreator,
  makeCoOrganizer,
  makeCoCreator,
  revokeAuthority,
  stepDown,
}

Set<PeopleAction> projectPersonActions(
  ProjectPerson person,
  ProjectManagementRole viewer,
  String viewerId,
) {
  final self = person.profileId == viewerId;
  return {
    if (person.isParticipant && (self || viewer.isManager))
      PeopleAction.commitments,
    if (person.isParticipant && (self || viewer.isManager))
      PeopleAction.actualContributions,
    if (person.isParticipant && !self && viewer.isManager)
      PeopleAction.removeParticipant,
    if (self && person.authorityRole != null) PeopleAction.stepDown,
    if (!self && !person.isCreator && viewer.hasStructuralAuthority) ...{
      if (person.authorityRole == null && person.isParticipant) ...{
        PeopleAction.inviteCoOrganizer,
        PeopleAction.inviteCoCreator,
      },
      if (person.authorityRole == ProjectDelegatedAuthorityRole.coOrganizer)
        PeopleAction.makeCoCreator,
      if (person.authorityRole == ProjectDelegatedAuthorityRole.coCreator)
        PeopleAction.makeCoOrganizer,
      if (person.authorityRole != null) PeopleAction.revokeAuthority,
    },
  };
}
