import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_participant_invites/data/participant_invitation_gateway.dart';
import 'package:planets_mobile/features/project_participant_invites/domain/participant_invitation_models.dart';

class FakeParticipantInvitationGateway implements ParticipantInvitationGateway {
  ParticipantInvitePreview previewValue = const ParticipantInvitePreview(
    available: true,
    projectId: 'project-1',
    kind: ProjectKind.oneTime,
    title: 'Community mural',
  );
  ParticipantAdmissionResult receipt = const ParticipantAdmissionResult(
    projectId: 'project-1',
    membershipId: 'member-1',
    outcome: ParticipantAdmissionOutcome.joined,
    status: MembershipStatus.current,
    replayed: false,
  );
  ParticipantLink? link = ParticipantLink(
    id: 'link-1',
    token: 'A' * 43,
    createdAt: DateTime.utc(2030),
  );
  List<ParticipantLinkHistory> rows = [];
  final admissions = <({String account, String token, String action})>[];
  final calls = <String>[];
  Object? previewError;
  Object? acceptError;
  Object? mutationError;
  Object? readError;
  Object? chatError;
  Future<void>? acceptDelay;
  Future<void>? readDelay;
  Future<void>? mutationDelay;
  String? chat = 'chat-1';
  ParticipantLinkHistory? cursor;
  @override
  Future<ParticipantInvitePreview> preview(String token) async {
    calls.add('preview');
    if (previewError case final error?) throw error;
    return previewValue;
  }

  @override
  Future<ParticipantAdmissionResult> accept(
    String profileId,
    String token,
    String actionId,
  ) async {
    calls.add('accept');
    admissions.add((account: profileId, token: token, action: actionId));
    if (acceptDelay case final delay?) await delay;
    if (acceptError case final error?) throw error;
    return receipt;
  }

  @override
  Future<ParticipantLink?> current(String profileId, String projectId) async {
    calls.add('current:$profileId:$projectId');
    if (readDelay case final delay?) await delay;
    if (readError case final error?) throw error;
    return link;
  }

  @override
  Future<ParticipantLink> create(String profileId, String projectId) async {
    calls.add('create:$profileId:$projectId');
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final error?) throw error;
    return link ??= ParticipantLink(
      id: 'link-1',
      token: 'A' * 43,
      createdAt: DateTime.utc(2030),
    );
  }

  @override
  Future<ParticipantLink> regenerate(String profileId, String projectId) async {
    calls.add('regenerate:$profileId:$projectId');
    if (mutationDelay case final delay?) await delay;
    link = ParticipantLink(
      id: 'link-2',
      token: 'B' * 43,
      createdAt: DateTime.utc(2030, 2),
    );
    if (mutationError case final error?) throw error;
    return link!;
  }

  @override
  Future<void> revoke(
    String profileId,
    String projectId,
    String invitationId,
  ) async {
    calls.add('revoke:$profileId:$projectId:$invitationId');
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final error?) throw error;
    link = null;
  }

  @override
  Future<List<ParticipantLinkHistory>> history(
    String profileId,
    String projectId, {
    ParticipantLinkHistory? before,
  }) async {
    calls.add('history:$profileId:$projectId');
    cursor = before;
    if (readError case final error?) throw error;
    return rows;
  }

  @override
  Future<String?> currentChat(String profileId, String projectId) async {
    calls.add('chat:$profileId:$projectId');
    if (chatError case final error?) throw error;
    return chat;
  }
}
