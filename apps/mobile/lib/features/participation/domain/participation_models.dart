const participationRequestMessageMaxLength = 500;
const participationSkillSelectionMax = 50;
const participationResourceNeedSelectionMax = 50;

enum ContributionOptionKind { skill, resource }

class ContributionOption {
  const ContributionOption({
    required this.id,
    required this.kind,
    required this.label,
  });

  final String id;
  final ContributionOptionKind kind;
  final String label;
}

enum ProjectKind {
  oneTime('one_time'),
  recurring('recurring');

  const ProjectKind(this.wireValue);

  final String wireValue;

  static ProjectKind fromWire(String value) => switch (value) {
    'one_time' => ProjectKind.oneTime,
    'recurring' => ProjectKind.recurring,
    _ => throw const FormatException('Unsupported project kind.'),
  };
}

enum JoinRequestStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected'),
  withdrawn('withdrawn');

  const JoinRequestStatus(this.wireValue);

  final String wireValue;

  static JoinRequestStatus fromWire(String value) => switch (value) {
    'pending' => JoinRequestStatus.pending,
    'accepted' => JoinRequestStatus.accepted,
    'rejected' => JoinRequestStatus.rejected,
    'withdrawn' => JoinRequestStatus.withdrawn,
    _ => throw const FormatException('Unsupported join-request status.'),
  };
}

enum MembershipStatus {
  current('current'),
  left('left'),
  removed('removed');

  const MembershipStatus(this.wireValue);

  final String wireValue;

  static MembershipStatus fromWire(String value) => switch (value) {
    'current' => MembershipStatus.current,
    'left' => MembershipStatus.left,
    'removed' => MembershipStatus.removed,
    _ => throw const FormatException('Unsupported membership status.'),
  };
}

class OwnProjectJoinRequest {
  const OwnProjectJoinRequest({
    required this.id,
    required this.projectId,
    required this.projectKind,
    required this.status,
    required this.message,
    required this.createdAt,
    required this.resolvedAt,
  });

  final String id;
  final String projectId;
  final ProjectKind projectKind;
  final JoinRequestStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime? resolvedAt;
}

class OwnProjectMembership {
  const OwnProjectMembership({
    required this.id,
    required this.projectId,
    required this.projectKind,
    required this.originatingRequestId,
    required this.status,
    required this.joinedAt,
    required this.leftAt,
    required this.removedAt,
  });

  final String id;
  final String projectId;
  final ProjectKind projectKind;
  final String originatingRequestId;
  final MembershipStatus status;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final DateTime? removedAt;

  bool get isCurrent => status == MembershipStatus.current;
}

class ManagerProjectJoinRequest {
  const ManagerProjectJoinRequest({
    required this.id,
    required this.requesterProfileId,
    required this.requesterDisplayName,
    required this.status,
    required this.message,
    required this.createdAt,
    required this.resolvedAt,
    required this.resolvedByProfileId,
  });

  final String id;
  final String requesterProfileId;
  final String requesterDisplayName;
  final JoinRequestStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedByProfileId;

  bool get isPending => status == JoinRequestStatus.pending;
}

class ManagerProjectMember {
  const ManagerProjectMember({
    required this.id,
    required this.participantProfileId,
    required this.participantDisplayName,
    required this.originatingRequestId,
    required this.status,
    required this.joinedAt,
    required this.leftAt,
    required this.removedAt,
    required this.removedByProfileId,
  });

  final String id;
  final String participantProfileId;
  final String participantDisplayName;
  final String originatingRequestId;
  final MembershipStatus status;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final DateTime? removedAt;
  final String? removedByProfileId;

  bool get isCurrent => status == MembershipStatus.current;
}

class ParticipantMeetingDetails {
  const ParticipantMeetingDetails({
    required this.projectId,
    required this.projectKind,
    required this.exactMeetingText,
    required this.exactLocation,
  });

  final String projectId;
  final ProjectKind projectKind;
  final String exactMeetingText;
  final Object? exactLocation;
}

class ProjectParticipationSnapshot {
  const ProjectParticipationSnapshot({
    required this.latestRequest,
    required this.pendingRequest,
    required this.latestMembership,
    required this.currentMembership,
  });

  final OwnProjectJoinRequest? latestRequest;
  final OwnProjectJoinRequest? pendingRequest;
  final OwnProjectMembership? latestMembership;
  final OwnProjectMembership? currentMembership;

  bool get canRequest => pendingRequest == null && currentMembership == null;
}

ProjectParticipationSnapshot resolveProjectParticipation({
  required String projectId,
  required ProjectKind projectKind,
  required Iterable<OwnProjectJoinRequest> requests,
  required Iterable<OwnProjectMembership> memberships,
}) {
  final projectRequests =
      requests
          .where(
            (request) =>
                request.projectId == projectId &&
                request.projectKind == projectKind,
          )
          .toList()
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  final projectMemberships =
      memberships
          .where(
            (membership) =>
                membership.projectId == projectId &&
                membership.projectKind == projectKind,
          )
          .toList()
        ..sort((left, right) => right.joinedAt.compareTo(left.joinedAt));

  return ProjectParticipationSnapshot(
    latestRequest: projectRequests.firstOrNull,
    pendingRequest: projectRequests
        .where((request) => request.status == JoinRequestStatus.pending)
        .firstOrNull,
    latestMembership: projectMemberships.firstOrNull,
    currentMembership: projectMemberships
        .where((membership) => membership.isCurrent)
        .firstOrNull,
  );
}
