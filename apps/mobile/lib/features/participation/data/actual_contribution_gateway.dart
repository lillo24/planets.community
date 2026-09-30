import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/actual_contribution_models.dart';

abstract interface class ActualContributionGateway {
  Future<List<ActualContribution>> listActualContributions({
    required String expectedProfileId,
    required String membershipId,
  });

  Future<List<ActualContributionOption>> listActualContributionOptions({
    required String expectedCreatorProfileId,
    required String membershipId,
  });

  Future<void> replaceActualContributions({
    required String expectedCreatorProfileId,
    required String membershipId,
    required Set<String> expectedSkillIds,
    required Set<String> expectedResourceNeedIds,
    required bool expectedSubstantialEffort,
    required Set<String> skillIds,
    required Set<String> resourceNeedIds,
    required bool substantialEffort,
  });
}

class SupabaseActualContributionGateway implements ActualContributionGateway {
  const SupabaseActualContributionGateway(this._client);

  final SupabaseClient _client;
  static const parser = ActualContributionPayloadParser();
  static const contract = ActualContributionRpcContract();

  @override
  Future<List<ActualContribution>> listActualContributions({
    required String expectedProfileId,
    required String membershipId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_project_membership_actual_contributions',
      params: contract.readParams(expectedProfileId, membershipId),
    );
    return response.map(parser.contribution).toList(growable: false);
  }

  @override
  Future<List<ActualContributionOption>> listActualContributionOptions({
    required String expectedCreatorProfileId,
    required String membershipId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_project_membership_actual_contribution_options',
      params: contract.optionsParams(expectedCreatorProfileId, membershipId),
    );
    return response.map(parser.option).toList(growable: false);
  }

  @override
  Future<void> replaceActualContributions({
    required String expectedCreatorProfileId,
    required String membershipId,
    required Set<String> expectedSkillIds,
    required Set<String> expectedResourceNeedIds,
    required bool expectedSubstantialEffort,
    required Set<String> skillIds,
    required Set<String> resourceNeedIds,
    required bool substantialEffort,
  }) async {
    await _client.rpc<String>(
      'replace_project_membership_actual_contributions',
      params: contract.replaceParams(
        expectedCreatorProfileId: expectedCreatorProfileId,
        membershipId: membershipId,
        expectedSkillIds: expectedSkillIds,
        expectedResourceNeedIds: expectedResourceNeedIds,
        expectedSubstantialEffort: expectedSubstantialEffort,
        skillIds: skillIds,
        resourceNeedIds: resourceNeedIds,
        substantialEffort: substantialEffort,
      ),
    );
  }
}

class ActualContributionRpcContract {
  const ActualContributionRpcContract();

  Map<String, Object?> readParams(
    String expectedProfileId,
    String membershipId,
  ) => {
    'p_expected_profile_id': expectedProfileId,
    'p_membership_id': membershipId,
  };

  Map<String, Object?> optionsParams(
    String expectedCreatorProfileId,
    String membershipId,
  ) => {
    'p_expected_creator_profile_id': expectedCreatorProfileId,
    'p_membership_id': membershipId,
  };

  Map<String, Object?> replaceParams({
    required String expectedCreatorProfileId,
    required String membershipId,
    required Set<String> expectedSkillIds,
    required Set<String> expectedResourceNeedIds,
    required bool expectedSubstantialEffort,
    required Set<String> skillIds,
    required Set<String> resourceNeedIds,
    required bool substantialEffort,
  }) => {
    'p_expected_creator_profile_id': expectedCreatorProfileId,
    'p_membership_id': membershipId,
    'p_expected_skill_ids': _sorted(expectedSkillIds),
    'p_expected_resource_need_ids': _sorted(expectedResourceNeedIds),
    'p_expected_substantial_effort': expectedSubstantialEffort,
    'p_skill_ids': _sorted(skillIds),
    'p_resource_need_ids': _sorted(resourceNeedIds),
    'p_substantial_effort': substantialEffort,
  };

  List<String> _sorted(Set<String> values) => values.toList()..sort();
}

class ActualContributionPayloadParser {
  const ActualContributionPayloadParser();

  ActualContribution contribution(Object? value) {
    final row = _row(value);
    final kind = ActualContributionKind.fromWire(
      row['contribution_kind'] as String,
    );
    final source = ActualContributionSource.fromWire(
      row['attribution_source'] as String,
    );
    final id = row['contribution_id'] as String?;
    final label = row['label'] as String?;
    if (kind == ActualContributionKind.substantialEffort) {
      if (id != null ||
          label != null ||
          source != ActualContributionSource.substantialEffort) {
        throw const FormatException(
          'Substantial effort must use the built-in null-ID shape.',
        );
      }
    } else {
      if (id == null || label == null || label.isEmpty) {
        throw const FormatException(
          'Catalog actual contributions require an ID and label.',
        );
      }
      if (source == ActualContributionSource.substantialEffort) {
        throw const FormatException(
          'Catalog actual contributions require a catalog source.',
        );
      }
    }
    return ActualContribution(kind: kind, id: id, label: label, source: source);
  }

  ActualContributionOption option(Object? value) {
    final row = _row(value);
    final kind = ActualContributionKind.fromWire(row['option_kind'] as String);
    if (kind == ActualContributionKind.substantialEffort) {
      throw const FormatException(
        'Substantial effort is not a catalog option.',
      );
    }
    final id = row['option_id'] as String?;
    final label = row['label'] as String?;
    if (id == null || label == null || label.isEmpty) {
      throw const FormatException(
        'Actual contribution options require an ID and label.',
      );
    }
    return ActualContributionOption(kind: kind, id: id, label: label);
  }

  Map<String, dynamic> _row(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Actual contribution payload was not an object.',
      );
    }
    return value.cast<String, dynamic>();
  }
}

final actualContributionGatewayProvider = Provider<ActualContributionGateway>((
  ref,
) {
  return SupabaseActualContributionGateway(ref.watch(supabaseClientProvider));
});
