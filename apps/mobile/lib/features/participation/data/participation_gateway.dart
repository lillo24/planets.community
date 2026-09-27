import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/participation_models.dart';

abstract interface class ParticipationGateway {
  Future<List<OwnProjectJoinRequest>> listOwnJoinRequests(
    String expectedRequesterProfileId,
  );

  Future<List<OwnProjectMembership>> listOwnMemberships(
    String expectedParticipantProfileId,
  );

  Future<String> requestToJoin({
    required String expectedRequesterProfileId,
    required String projectId,
    String? message,
    Set<String> skillIds = const {},
    Set<String> resourceNeedIds = const {},
  });

  Future<void> withdrawRequest({
    required String expectedRequesterProfileId,
    required String requestId,
  });

  Future<List<ManagerProjectJoinRequest>> listProjectJoinRequests({
    required String expectedManagerProfileId,
    required String projectId,
  });

  Future<List<ManagerProjectMember>> listProjectMembers({
    required String expectedManagerProfileId,
    required String projectId,
  });

  Future<void> rejectRequest({
    required String expectedManagerProfileId,
    required String requestId,
  });

  Future<void> leaveProject({
    required String expectedParticipantProfileId,
    required String membershipId,
  });

  Future<void> removeMember({
    required String expectedManagerProfileId,
    required String membershipId,
  });

  Future<ParticipantMeetingDetails?> getParticipantMeetingDetails({
    required String expectedProfileId,
    required String projectId,
  });
}

class SupabaseParticipationGateway implements ParticipationGateway {
  const SupabaseParticipationGateway(this._client);

  final SupabaseClient _client;
  static const parser = ParticipationPayloadParser();

  @override
  Future<List<OwnProjectJoinRequest>> listOwnJoinRequests(
    String expectedRequesterProfileId,
  ) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_project_join_requests',
      params: {'p_expected_requester_profile_id': expectedRequesterProfileId},
    );
    return response.map(parser.ownJoinRequest).toList(growable: false);
  }

  @override
  Future<List<OwnProjectMembership>> listOwnMemberships(
    String expectedParticipantProfileId,
  ) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_project_memberships',
      params: {
        'p_expected_participant_profile_id': expectedParticipantProfileId,
      },
    );
    return response.map(parser.ownMembership).toList(growable: false);
  }

  @override
  Future<String> requestToJoin({
    required String expectedRequesterProfileId,
    required String projectId,
    String? message,
    Set<String> skillIds = const {},
    Set<String> resourceNeedIds = const {},
  }) => _client.rpc<String>(
    'request_to_join_project',
    params: {
      'p_expected_requester_profile_id': expectedRequesterProfileId,
      'p_project_id': projectId,
      'p_request_message': message,
      'p_skill_ids': (skillIds.toList()..sort()),
      'p_resource_need_ids': (resourceNeedIds.toList()..sort()),
    },
  );

  @override
  Future<void> withdrawRequest({
    required String expectedRequesterProfileId,
    required String requestId,
  }) async {
    await _client.rpc<String>(
      'withdraw_project_join_request',
      params: {
        'p_expected_requester_profile_id': expectedRequesterProfileId,
        'p_request_id': requestId,
      },
    );
  }

  @override
  Future<List<ManagerProjectJoinRequest>> listProjectJoinRequests({
    required String expectedManagerProfileId,
    required String projectId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_project_join_requests_for_manager',
      params: {
        'p_expected_manager_profile_id': expectedManagerProfileId,
        'p_project_id': projectId,
      },
    );
    return response.map(parser.managerJoinRequest).toList(growable: false);
  }

  @override
  Future<List<ManagerProjectMember>> listProjectMembers({
    required String expectedManagerProfileId,
    required String projectId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_project_members_for_manager',
      params: {
        'p_expected_manager_profile_id': expectedManagerProfileId,
        'p_project_id': projectId,
      },
    );
    return response.map(parser.managerMember).toList(growable: false);
  }

  @override
  Future<void> rejectRequest({
    required String expectedManagerProfileId,
    required String requestId,
  }) async {
    await _client.rpc<String>(
      'reject_project_join_request_as_manager',
      params: {
        'p_expected_manager_profile_id': expectedManagerProfileId,
        'p_request_id': requestId,
      },
    );
  }

  @override
  Future<void> leaveProject({
    required String expectedParticipantProfileId,
    required String membershipId,
  }) async {
    await _client.rpc<String>(
      'leave_project',
      params: {
        'p_expected_participant_profile_id': expectedParticipantProfileId,
        'p_membership_id': membershipId,
      },
    );
  }

  @override
  Future<void> removeMember({
    required String expectedManagerProfileId,
    required String membershipId,
  }) async {
    await _client.rpc<String>(
      'remove_project_member_as_manager',
      params: {
        'p_expected_manager_profile_id': expectedManagerProfileId,
        'p_membership_id': membershipId,
      },
    );
  }

  @override
  Future<ParticipantMeetingDetails?> getParticipantMeetingDetails({
    required String expectedProfileId,
    required String projectId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_project_participant_meeting_details',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_project_id': projectId,
      },
    );
    return response.isEmpty ? null : parser.meetingDetails(response.single);
  }
}

class ParticipationPayloadParser {
  const ParticipationPayloadParser();

  OwnProjectJoinRequest ownJoinRequest(Object? value) {
    final row = _row(value);
    return OwnProjectJoinRequest(
      id: row['request_id'] as String,
      projectId: row['project_id'] as String,
      projectKind: ProjectKind.fromWire(row['project_kind'] as String),
      status: JoinRequestStatus.fromWire(row['status'] as String),
      message: row['request_message'] as String?,
      createdAt: _date(row['created_at']),
      resolvedAt: _optionalDate(row['resolved_at']),
    );
  }

  OwnProjectMembership ownMembership(Object? value) {
    final row = _row(value);
    return OwnProjectMembership(
      id: row['membership_id'] as String,
      projectId: row['project_id'] as String,
      projectKind: ProjectKind.fromWire(row['project_kind'] as String),
      originatingRequestId: row['originating_request_id'] as String,
      status: MembershipStatus.fromWire(row['membership_status'] as String),
      joinedAt: _date(row['joined_at']),
      leftAt: _optionalDate(row['left_at']),
      removedAt: _optionalDate(row['removed_at']),
    );
  }

  ManagerProjectJoinRequest managerJoinRequest(Object? value) {
    final row = _row(value);
    return ManagerProjectJoinRequest(
      id: row['request_id'] as String,
      requesterProfileId: row['requester_profile_id'] as String,
      requesterDisplayName: row['requester_display_name'] as String,
      status: JoinRequestStatus.fromWire(row['status'] as String),
      message: row['request_message'] as String?,
      createdAt: _date(row['created_at']),
      resolvedAt: _optionalDate(row['resolved_at']),
      resolvedByProfileId: row['resolved_by_profile_id'] as String?,
    );
  }

  ManagerProjectMember managerMember(Object? value) {
    final row = _row(value);
    return ManagerProjectMember(
      id: row['membership_id'] as String,
      participantProfileId: row['participant_profile_id'] as String,
      participantDisplayName: row['participant_display_name'] as String,
      originatingRequestId: row['originating_request_id'] as String,
      status: MembershipStatus.fromWire(row['membership_status'] as String),
      joinedAt: _date(row['joined_at']),
      leftAt: _optionalDate(row['left_at']),
      removedAt: _optionalDate(row['removed_at']),
      removedByProfileId: row['removed_by_profile_id'] as String?,
    );
  }

  ParticipantMeetingDetails meetingDetails(Object? value) {
    final row = _row(value);
    return ParticipantMeetingDetails(
      projectId: row['project_id'] as String,
      projectKind: ProjectKind.fromWire(row['project_kind'] as String),
      exactMeetingText: row['exact_meeting_text'] as String,
      exactLocation: row['exact_location'],
    );
  }

  Map<String, dynamic> _row(Object? value) {
    if (value is! Map) {
      throw const FormatException('Participation payload was not an object.');
    }
    return value.cast<String, dynamic>();
  }

  DateTime _date(Object? value) => DateTime.parse(value as String);

  DateTime? _optionalDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}

final participationGatewayProvider = Provider<ParticipationGateway>((ref) {
  return SupabaseParticipationGateway(ref.watch(supabaseClientProvider));
});
