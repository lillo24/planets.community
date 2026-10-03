import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../project_delegates/domain/project_delegate_models.dart';
import '../domain/participation_models.dart';
import '../domain/project_people_models.dart';
import 'participation_gateway.dart';

abstract interface class ProjectPeopleGateway {
  Future<List<ProjectPerson>> people(
    String profileId,
    String projectId,
    ProjectPerson? after,
  );
  Future<List<ManagerProjectJoinRequest>> requests(
    String profileId,
    String projectId,
    ManagerProjectJoinRequest? after,
  );
  Future<List<ManagerProjectMember>> history(
    String profileId,
    String projectId,
    ManagerProjectMember? after,
  );
  Future<List<ProjectRoleOffer>> offers(
    String profileId,
    String projectId,
    ProjectRoleOffer? after,
  );
  Future<void> offer(
    String profileId,
    String projectId,
    String membershipId,
    ProjectDelegatedAuthorityRole role,
  );
  Future<void> respond(
    String profileId,
    String offerId, {
    required bool accept,
  });
  Future<void> stepDown(String profileId, String delegateId);
}

class SupabaseProjectPeopleGateway implements ProjectPeopleGateway {
  const SupabaseProjectPeopleGateway(this.client);
  final SupabaseClient client;
  static const pageSize = 50;
  Map<String, dynamic> _params(String profileId, String projectId) => {
    'p_expected_profile_id': profileId,
    'p_project_id': projectId,
    'p_limit': pageSize,
  };
  Future<List<T>> _page<T>(
    String rpc,
    Map<String, dynamic> params,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final rows = await client.rpc<List<dynamic>>(rpc, params: params);
    return List.unmodifiable(
      rows.map((row) => parse(Map<String, dynamic>.from(row as Map))),
    );
  }

  @override
  Future<List<ProjectPerson>> people(
    String profileId,
    String projectId,
    ProjectPerson? after,
  ) => _page('list_current_project_people', {
    ..._params(profileId, projectId),
    'p_after_role_rank': after?.roleRank,
    'p_after_profile_id': after?.profileId,
  }, ProjectPerson.fromJson);
  @override
  Future<List<ManagerProjectJoinRequest>> requests(
    String profileId,
    String projectId,
    ManagerProjectJoinRequest? after,
  ) => _page('page_project_requests_for_manager', {
    ..._params(profileId, projectId),
    'p_after_pending': after?.isPending,
    'p_after_created_at': after?.createdAt.toUtc().toIso8601String(),
    'p_after_id': after?.id,
  }, const ParticipationPayloadParser().managerJoinRequest);
  @override
  Future<List<ManagerProjectMember>> history(
    String profileId,
    String projectId,
    ManagerProjectMember? after,
  ) => _page('page_project_history_for_manager', {
    ..._params(profileId, projectId),
    'p_after_joined_at': after?.joinedAt.toUtc().toIso8601String(),
    'p_after_id': after?.id,
  }, const ParticipationPayloadParser().managerMember);
  @override
  Future<List<ProjectRoleOffer>> offers(
    String profileId,
    String projectId,
    ProjectRoleOffer? after,
  ) => _page('list_project_role_offers', {
    ..._params(profileId, projectId),
    'p_after_created_at': after?.createdAt.toUtc().toIso8601String(),
    'p_after_id': after?.id,
  }, ProjectRoleOffer.fromJson);
  @override
  Future<void> offer(
    String profileId,
    String projectId,
    String membershipId,
    ProjectDelegatedAuthorityRole role,
  ) async {
    await client.rpc<dynamic>(
      'create_project_role_offer',
      params: {
        'p_expected_structural_profile_id': profileId,
        'p_project_id': projectId,
        'p_membership_id': membershipId,
        'p_authority_role': role.wireValue,
      },
    );
  }

  @override
  Future<void> respond(
    String profileId,
    String offerId, {
    required bool accept,
  }) async {
    await client.rpc<dynamic>(
      accept ? 'accept_project_role_offer' : 'decline_project_role_offer',
      params: {'p_expected_profile_id': profileId, 'p_offer_id': offerId},
    );
  }

  @override
  Future<void> stepDown(String profileId, String delegateId) async {
    await client.rpc<dynamic>(
      'step_down_project_authority',
      params: {'p_expected_profile_id': profileId, 'p_delegate_id': delegateId},
    );
  }
}

final projectPeopleGatewayProvider = Provider<ProjectPeopleGateway>(
  (ref) => SupabaseProjectPeopleGateway(ref.watch(supabaseClientProvider)),
);
