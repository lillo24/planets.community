import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';

class FakeParticipationGateway implements ParticipationGateway {
  List<OwnProjectJoinRequest> ownRequests = [];
  List<OwnProjectMembership> ownMemberships = [];
  List<ManagerProjectJoinRequest> creatorRequests = [];
  List<ManagerProjectMember> creatorMembers = [];
  ParticipantMeetingDetails? meetingDetails;
  Object? error;
  Future<void>? mutationDelay;
  Future<void>? ownLoadDelay;
  Future<void>? creatorLoadDelay;
  Future<void>? meetingDelay;
  final List<String> calls = [];
  String? lastExpectedIdentity;
  String? lastProjectId;
  String? lastMessage;
  Set<String> lastSkillIds = const {};
  Set<String> lastResourceNeedIds = const {};

  @override
  Future<List<OwnProjectJoinRequest>> listOwnJoinRequests(
    String expectedRequesterProfileId,
  ) async {
    calls.add('list-own-requests');
    lastExpectedIdentity = expectedRequesterProfileId;
    if (ownLoadDelay case final delay?) await delay;
    _throwIfNeeded();
    return List.unmodifiable(ownRequests);
  }

  @override
  Future<List<OwnProjectMembership>> listOwnMemberships(
    String expectedParticipantProfileId,
  ) async {
    calls.add('list-own-memberships');
    lastExpectedIdentity = expectedParticipantProfileId;
    if (ownLoadDelay case final delay?) await delay;
    _throwIfNeeded();
    return List.unmodifiable(ownMemberships);
  }

  @override
  Future<String> requestToJoin({
    required String expectedRequesterProfileId,
    required String projectId,
    String? message,
    Set<String> skillIds = const {},
    Set<String> resourceNeedIds = const {},
  }) async {
    calls.add('request:$projectId');
    lastExpectedIdentity = expectedRequesterProfileId;
    lastProjectId = projectId;
    lastMessage = message;
    lastSkillIds = Set.unmodifiable(skillIds);
    lastResourceNeedIds = Set.unmodifiable(resourceNeedIds);
    if (mutationDelay case final delay?) await delay;
    _throwIfNeeded();
    final request = ownJoinRequestFixture(
      id: 'request-${ownRequests.length + 1}',
      projectId: projectId,
      projectKind: _kind(projectId),
      status: JoinRequestStatus.pending,
      message: message,
    );
    ownRequests = [request, ...ownRequests];
    creatorRequests = [
      creatorJoinRequestFixture(
        id: request.id,
        status: JoinRequestStatus.pending,
        message: message,
      ),
      ...creatorRequests,
    ];
    return request.id;
  }

  @override
  Future<void> withdrawRequest({
    required String expectedRequesterProfileId,
    required String requestId,
  }) async {
    calls.add('withdraw:$requestId');
    lastExpectedIdentity = expectedRequesterProfileId;
    if (mutationDelay case final delay?) await delay;
    _throwIfNeeded();
    ownRequests = [
      for (final request in ownRequests)
        if (request.id == requestId)
          ownJoinRequestFixture(
            id: request.id,
            projectId: request.projectId,
            projectKind: request.projectKind,
            status: JoinRequestStatus.withdrawn,
            message: request.message,
          )
        else
          request,
    ];
  }

  @override
  Future<List<ManagerProjectJoinRequest>> listProjectJoinRequests({
    required String expectedManagerProfileId,
    required String projectId,
  }) async {
    calls.add('list-creator-requests:$projectId');
    lastExpectedIdentity = expectedManagerProfileId;
    lastProjectId = projectId;
    if (creatorLoadDelay case final delay?) await delay;
    _throwIfNeeded();
    return List.unmodifiable(creatorRequests);
  }

  @override
  Future<List<ManagerProjectMember>> listProjectMembers({
    required String expectedManagerProfileId,
    required String projectId,
  }) async {
    calls.add('list-creator-members:$projectId');
    lastExpectedIdentity = expectedManagerProfileId;
    lastProjectId = projectId;
    if (creatorLoadDelay case final delay?) await delay;
    _throwIfNeeded();
    return List.unmodifiable(creatorMembers);
  }

  @override
  Future<void> rejectRequest({
    required String expectedManagerProfileId,
    required String requestId,
  }) async {
    calls.add('reject:$requestId');
    lastExpectedIdentity = expectedManagerProfileId;
    if (mutationDelay case final delay?) await delay;
    _throwIfNeeded();
    creatorRequests = [
      for (final item in creatorRequests)
        if (item.id == requestId)
          creatorJoinRequestFixture(
            id: item.id,
            requesterProfileId: item.requesterProfileId,
            requesterDisplayName: item.requesterDisplayName,
            status: JoinRequestStatus.rejected,
            message: item.message,
          )
        else
          item,
    ];
  }

  @override
  Future<void> leaveProject({
    required String expectedParticipantProfileId,
    required String membershipId,
  }) async {
    calls.add('leave:$membershipId');
    lastExpectedIdentity = expectedParticipantProfileId;
    if (mutationDelay case final delay?) await delay;
    _throwIfNeeded();
    ownMemberships = [
      for (final membership in ownMemberships)
        if (membership.id == membershipId)
          ownMembershipFixture(
            id: membership.id,
            projectId: membership.projectId,
            projectKind: membership.projectKind,
            originatingRequestId: membership.originatingRequestId,
            status: MembershipStatus.left,
          )
        else
          membership,
    ];
  }

  @override
  Future<void> removeMember({
    required String expectedManagerProfileId,
    required String membershipId,
  }) async {
    calls.add('remove:$membershipId');
    lastExpectedIdentity = expectedManagerProfileId;
    if (mutationDelay case final delay?) await delay;
    _throwIfNeeded();
    creatorMembers = [
      for (final member in creatorMembers)
        if (member.id == membershipId)
          creatorMemberFixture(
            id: member.id,
            participantProfileId: member.participantProfileId,
            participantDisplayName: member.participantDisplayName,
            originatingRequestId: member.originatingRequestId,
            status: MembershipStatus.removed,
          )
        else
          member,
    ];
  }

  @override
  Future<ParticipantMeetingDetails?> getParticipantMeetingDetails({
    required String expectedProfileId,
    required String projectId,
  }) async {
    calls.add('meeting:$projectId');
    lastExpectedIdentity = expectedProfileId;
    lastProjectId = projectId;
    if (meetingDelay case final delay?) await delay;
    _throwIfNeeded();
    return meetingDetails;
  }

  void _throwIfNeeded() {
    if (error case final failure?) throw failure;
  }

  ProjectKind _kind(String projectId) => projectId.startsWith('tavolo')
      ? ProjectKind.recurring
      : ProjectKind.oneTime;
}

OwnProjectJoinRequest ownJoinRequestFixture({
  String id = 'request-1',
  String projectId = 'proposal-1',
  ProjectKind projectKind = ProjectKind.oneTime,
  JoinRequestStatus status = JoinRequestStatus.pending,
  String? message = 'I would like to help.',
  DateTime? createdAt,
}) => OwnProjectJoinRequest(
  id: id,
  projectId: projectId,
  projectKind: projectKind,
  status: status,
  message: message,
  createdAt: createdAt ?? DateTime.utc(2026, 9, 8, 10),
  resolvedAt: status == JoinRequestStatus.pending
      ? null
      : DateTime.utc(2026, 9, 8, 11),
);

OwnProjectMembership ownMembershipFixture({
  String id = 'membership-1',
  String projectId = 'proposal-1',
  ProjectKind projectKind = ProjectKind.oneTime,
  String originatingRequestId = 'request-1',
  MembershipStatus status = MembershipStatus.current,
  DateTime? joinedAt,
}) => OwnProjectMembership(
  id: id,
  projectId: projectId,
  projectKind: projectKind,
  originatingRequestId: originatingRequestId,
  status: status,
  joinedAt: joinedAt ?? DateTime.utc(2026, 9, 8, 11),
  leftAt: status == MembershipStatus.left ? DateTime.utc(2026, 9, 8, 12) : null,
  removedAt: status == MembershipStatus.removed
      ? DateTime.utc(2026, 9, 8, 12)
      : null,
);

ManagerProjectJoinRequest creatorJoinRequestFixture({
  String id = 'request-1',
  String requesterProfileId = 'user-2',
  String requesterDisplayName = 'Jordan',
  JoinRequestStatus status = JoinRequestStatus.pending,
  String? message = 'I can bring paint brushes.',
  DateTime? createdAt,
}) => ManagerProjectJoinRequest(
  id: id,
  requesterProfileId: requesterProfileId,
  requesterDisplayName: requesterDisplayName,
  status: status,
  message: message,
  createdAt: createdAt ?? DateTime.utc(2026, 9, 8, 10),
  resolvedAt: status == JoinRequestStatus.pending
      ? null
      : DateTime.utc(2026, 9, 8, 11),
  resolvedByProfileId: status == JoinRequestStatus.pending ? null : 'user-1',
);

ManagerProjectMember creatorMemberFixture({
  String id = 'membership-1',
  String participantProfileId = 'user-2',
  String participantDisplayName = 'Jordan',
  String originatingRequestId = 'request-1',
  MembershipStatus status = MembershipStatus.current,
  DateTime? joinedAt,
}) => ManagerProjectMember(
  id: id,
  participantProfileId: participantProfileId,
  participantDisplayName: participantDisplayName,
  originatingRequestId: originatingRequestId,
  status: status,
  joinedAt: joinedAt ?? DateTime.utc(2026, 9, 8, 11),
  leftAt: status == MembershipStatus.left ? DateTime.utc(2026, 9, 8, 12) : null,
  removedAt: status == MembershipStatus.removed
      ? DateTime.utc(2026, 9, 8, 12)
      : null,
  removedByProfileId: status == MembershipStatus.removed ? 'user-1' : null,
);

ParticipantMeetingDetails meetingDetailsFixture({
  String projectId = 'proposal-1',
  ProjectKind projectKind = ProjectKind.oneTime,
}) => ParticipantMeetingDetails(
  projectId: projectId,
  projectKind: projectKind,
  exactMeetingText: 'Meet beside the blue workshop door.',
  exactLocation: null,
);
