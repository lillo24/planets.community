import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/membership_commitment_models.dart';

abstract interface class MembershipCommitmentGateway {
  Future<List<MembershipCommitment>> listCommitments({
    required String expectedProfileId,
    required String membershipId,
  });

  Future<List<MembershipCommitmentOption>> listOptions({
    required String expectedProfileId,
    required String membershipId,
  });

  Future<void> replaceCommitments({
    required String expectedActorProfileId,
    required String membershipId,
    required Set<String> expectedSkillIds,
    required Set<String> expectedResourceNeedIds,
    required Set<String> skillIds,
    required Set<String> resourceNeedIds,
  });
}

class SupabaseMembershipCommitmentGateway
    implements MembershipCommitmentGateway {
  const SupabaseMembershipCommitmentGateway(this._client);

  final SupabaseClient _client;
  static const parser = MembershipCommitmentPayloadParser();
  static const contract = MembershipCommitmentRpcContract();

  @override
  Future<List<MembershipCommitment>> listCommitments({
    required String expectedProfileId,
    required String membershipId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_project_membership_commitments',
      params: contract.readParams(expectedProfileId, membershipId),
    );
    return response.map(parser.commitment).toList(growable: false);
  }

  @override
  Future<List<MembershipCommitmentOption>> listOptions({
    required String expectedProfileId,
    required String membershipId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_project_membership_commitment_options',
      params: contract.readParams(expectedProfileId, membershipId),
    );
    return response.map(parser.option).toList(growable: false);
  }

  @override
  Future<void> replaceCommitments({
    required String expectedActorProfileId,
    required String membershipId,
    required Set<String> expectedSkillIds,
    required Set<String> expectedResourceNeedIds,
    required Set<String> skillIds,
    required Set<String> resourceNeedIds,
  }) async {
    await _client.rpc<String>(
      'replace_project_membership_commitments',
      params: contract.replaceParams(
        expectedActorProfileId: expectedActorProfileId,
        membershipId: membershipId,
        expectedSkillIds: expectedSkillIds,
        expectedResourceNeedIds: expectedResourceNeedIds,
        skillIds: skillIds,
        resourceNeedIds: resourceNeedIds,
      ),
    );
  }
}

class MembershipCommitmentRpcContract {
  const MembershipCommitmentRpcContract();

  Map<String, Object?> readParams(
    String expectedProfileId,
    String membershipId,
  ) => {
    'p_expected_profile_id': expectedProfileId,
    'p_membership_id': membershipId,
  };

  Map<String, Object?> replaceParams({
    required String expectedActorProfileId,
    required String membershipId,
    required Set<String> expectedSkillIds,
    required Set<String> expectedResourceNeedIds,
    required Set<String> skillIds,
    required Set<String> resourceNeedIds,
  }) => {
    'p_expected_actor_profile_id': expectedActorProfileId,
    'p_membership_id': membershipId,
    'p_expected_skill_ids': _sorted(expectedSkillIds),
    'p_expected_resource_need_ids': _sorted(expectedResourceNeedIds),
    'p_skill_ids': _sorted(skillIds),
    'p_resource_need_ids': _sorted(resourceNeedIds),
  };

  List<String> _sorted(Set<String> values) => values.toList()..sort();
}

class MembershipCommitmentPayloadParser {
  const MembershipCommitmentPayloadParser();

  MembershipCommitment commitment(Object? value) {
    final row = _row(value);
    return MembershipCommitment(
      id: row['commitment_id'] as String,
      kind: MembershipCommitmentKind.fromWire(row['commitment_kind'] as String),
      label: row['label'] as String,
    );
  }

  MembershipCommitmentOption option(Object? value) {
    final row = _row(value);
    return MembershipCommitmentOption(
      id: row['option_id'] as String,
      kind: MembershipCommitmentKind.fromWire(row['option_kind'] as String),
      label: row['label'] as String,
    );
  }

  Map<String, dynamic> _row(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Membership commitment payload was not an object.',
      );
    }
    return value.cast<String, dynamic>();
  }
}

final membershipCommitmentGatewayProvider =
    Provider<MembershipCommitmentGateway>((ref) {
      return SupabaseMembershipCommitmentGateway(
        ref.watch(supabaseClientProvider),
      );
    });
