import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../groups/data/group_gateway.dart';
import '../../groups/domain/group_models.dart';
import '../domain/group_relationships.dart';

enum GroupMutation {
  request('create_group_join_request'),
  withdraw('withdraw_group_join_request'),
  acceptRequest('accept_group_join_request'),
  rejectRequest('reject_group_join_request'),
  leave('leave_group'),
  remove('remove_group_member'),
  invite('create_group_authority_invitation'),
  offer('create_group_role_offer'),
  acceptOffer('accept_group_role_offer'),
  declineOffer('decline_group_role_offer'),
  revokeInvite('revoke_group_authority_invitation'),
  changeRole('change_group_delegate_role'),
  revokeRole('revoke_group_delegate'),
  stepDown('step_down_group_authority'),
  acceptParticipant('accept_group_participant_invitation'),
  acceptAuthority('accept_group_authority_invitation');

  const GroupMutation(this.rpc);
  final String rpc;
  bool get exit =>
      this == withdraw ||
      this == leave ||
      this == stepDown ||
      this == declineOffer;
}

class GroupRelationshipGateway {
  const GroupRelationshipGateway(this.base);
  final GroupGateway base;
  Map<String, dynamic> actor(String id) => {
    'p_expected_profile_id': groupUuid(id),
  };
  Future<GroupSelfContext> self(String profile, String group) async {
    final row = base.single(
      await base.rpc('get_own_group_membership_context', {
        ...actor(profile),
        'p_group_id': groupUuid(group),
      }),
      GroupSelfContext.new,
    );
    if (row == null) throw const FormatException('Missing own group context.');
    return row;
  }

  Future<List<GroupPerson>> people(
    String profile,
    String group,
    Map<String, dynamic>? cursor,
  ) async => base.rows(
    await base.rpc('list_current_group_people', {
      ...actor(profile),
      'p_group_id': groupUuid(group),
      'p_limit': 25,
      'p_after_role_rank': null,
      'p_after_profile_id': null,
      ...?cursor,
    }),
    GroupPerson.new,
  );
  Future<List<GroupHistoryRow>> history(
    String profile,
    GroupHistoryKind family, {
    String? group,
    Map<String, dynamic>? cursor,
  }) async {
    final name = switch (family) {
      GroupHistoryKind.requests =>
        group == null
            ? 'list_own_group_join_requests'
            : 'list_group_join_requests',
      GroupHistoryKind.memberships =>
        group == null
            ? 'list_own_group_memberships'
            : 'list_group_membership_history',
      GroupHistoryKind.delegates => 'list_group_delegates',
      GroupHistoryKind.offers =>
        group == null
            ? 'list_own_group_role_offers'
            : 'list_group_authority_invitations',
      GroupHistoryKind.roleChanges => 'list_group_delegate_role_history',
      GroupHistoryKind.links => 'list_group_participant_invitation_history',
      GroupHistoryKind.managed => 'list_managed_groups',
    };
    final time = switch (family) {
      GroupHistoryKind.memberships => 'joined_at',
      GroupHistoryKind.delegates => 'granted_at',
      _ => 'created_at',
    };
    return base.rows(
      await base.rpc(name, {
        ...actor(profile),
        if (group != null) 'p_group_id': groupUuid(group),
        'p_limit': 25,
        'p_before_$time': null,
        'p_before_id': null,
        ...?cursor,
      }),
      (r) => GroupHistoryRow(r, family),
    );
  }

  Future<GroupRelationshipReceipt?> recover(String profile, String key) async =>
      base.single(
        await base.rpc('recover_group_relationship_command', {
          ...actor(profile),
          'p_client_request_id': groupUuid(key),
        }),
        GroupRelationshipReceipt.new,
      );
  Future<GroupRelationshipReceipt> command(
    String profile,
    String key,
    GroupMutation mutation,
    Map<String, dynamic> intent,
  ) async {
    final row = base.single(
      await base.rpc(mutation.rpc, {
        ...intent,
        ...actor(profile),
        'p_client_request_id': groupUuid(key),
      }),
      GroupRelationshipReceipt.new,
    );
    if (row == null) {
      throw const FormatException('Missing group command result.');
    }
    return row;
  }

  Future<GroupInvitePreview> preview(String token, bool authority) async {
    groupToken(token);
    final row = base.single(
      await base.rpc(
        authority
            ? 'get_group_authority_invitation_preview'
            : 'get_group_participant_invitation_preview',
        {'p_token': token},
      ),
      (r) => GroupInvitePreview(r, authority: authority),
    );
    if (row == null) throw const FormatException('Missing group preview.');
    return row;
  }

  Future<GroupSharingLink?> sharing(String profile, String group) async =>
      base.single(
        await base.rpc('get_current_group_participant_invitation', {
          ...actor(profile),
          'p_group_id': groupUuid(group),
        }),
        GroupSharingLink.new,
      );
  Future<GroupSharingLink> changeSharing(
    String profile,
    String group,
    String key, {
    bool replace = false,
    String? revokeId,
  }) async {
    final row = base.single(
      await base.rpc(
        revokeId != null
            ? 'revoke_group_participant_invitation'
            : replace
            ? 'regenerate_group_participant_invitation'
            : 'create_group_participant_invitation',
        {
          ...actor(profile),
          'p_group_id': groupUuid(group),
          'p_client_request_id': groupUuid(key),
          if (revokeId != null) 'p_invitation_id': groupUuid(revokeId),
        },
      ),
      GroupSharingLink.new,
    );
    if (row == null) {
      throw const FormatException('Missing group sharing result.');
    }
    return row;
  }
}

final groupRelationshipGatewayProvider = Provider<GroupRelationshipGateway>(
  (ref) => GroupRelationshipGateway(ref.watch(groupGatewayProvider)),
);
