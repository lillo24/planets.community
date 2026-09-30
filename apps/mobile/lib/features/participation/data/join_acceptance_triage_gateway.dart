import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/join_acceptance_triage_models.dart';

abstract interface class JoinAcceptanceTriageGateway {
  Future<List<JoinAcceptanceTriageItem>> listSelections({
    required String expectedCreatorProfileId,
    required String requestId,
  });

  Future<void> acceptWithTriage({
    required String expectedCreatorProfileId,
    required String requestId,
    required Set<String> neededSkillIds,
    required Set<String> alreadyFoundSkillIds,
    required Set<String> extraSkillIds,
    required Set<String> neededResourceNeedIds,
    required Set<String> alreadyFoundResourceNeedIds,
    required Set<String> extraResourceNeedIds,
  });
}

class SupabaseJoinAcceptanceTriageGateway
    implements JoinAcceptanceTriageGateway {
  const SupabaseJoinAcceptanceTriageGateway(this._client);

  final SupabaseClient _client;
  static const parser = JoinAcceptanceTriagePayloadParser();
  static const contract = JoinAcceptanceTriageRpcContract();

  @override
  Future<List<JoinAcceptanceTriageItem>> listSelections({
    required String expectedCreatorProfileId,
    required String requestId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_project_join_request_contribution_selections',
      params: contract.selectionParams(expectedCreatorProfileId, requestId),
    );
    return response.map(parser.selection).toList(growable: false);
  }

  @override
  Future<void> acceptWithTriage({
    required String expectedCreatorProfileId,
    required String requestId,
    required Set<String> neededSkillIds,
    required Set<String> alreadyFoundSkillIds,
    required Set<String> extraSkillIds,
    required Set<String> neededResourceNeedIds,
    required Set<String> alreadyFoundResourceNeedIds,
    required Set<String> extraResourceNeedIds,
  }) async {
    await _client.rpc<String>(
      'accept_project_join_request',
      params: contract.acceptParams(
        expectedCreatorProfileId: expectedCreatorProfileId,
        requestId: requestId,
        neededSkillIds: neededSkillIds,
        alreadyFoundSkillIds: alreadyFoundSkillIds,
        extraSkillIds: extraSkillIds,
        neededResourceNeedIds: neededResourceNeedIds,
        alreadyFoundResourceNeedIds: alreadyFoundResourceNeedIds,
        extraResourceNeedIds: extraResourceNeedIds,
      ),
    );
  }
}

class JoinAcceptanceTriagePayloadParser {
  const JoinAcceptanceTriagePayloadParser();

  JoinAcceptanceTriageItem selection(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Join-acceptance selection payload was not an object.',
      );
    }
    final row = value.cast<String, dynamic>();
    return JoinAcceptanceTriageItem(
      kind: JoinAcceptanceSelectionKind.fromWire(
        row['selection_kind'] as String,
      ),
      id: row['selection_id'] as String,
      label: row['label'] as String,
    );
  }
}

class JoinAcceptanceTriageRpcContract {
  const JoinAcceptanceTriageRpcContract();

  Map<String, Object> selectionParams(
    String expectedCreatorProfileId,
    String requestId,
  ) => {
    'p_expected_profile_id': expectedCreatorProfileId,
    'p_request_id': requestId,
  };

  Map<String, Object> acceptParams({
    required String expectedCreatorProfileId,
    required String requestId,
    required Set<String> neededSkillIds,
    required Set<String> alreadyFoundSkillIds,
    required Set<String> extraSkillIds,
    required Set<String> neededResourceNeedIds,
    required Set<String> alreadyFoundResourceNeedIds,
    required Set<String> extraResourceNeedIds,
  }) => {
    'p_expected_creator_profile_id': expectedCreatorProfileId,
    'p_request_id': requestId,
    'p_needed_skill_ids': _sorted(neededSkillIds),
    'p_already_found_skill_ids': _sorted(alreadyFoundSkillIds),
    'p_extra_skill_ids': _sorted(extraSkillIds),
    'p_needed_resource_need_ids': _sorted(neededResourceNeedIds),
    'p_already_found_resource_need_ids': _sorted(alreadyFoundResourceNeedIds),
    'p_extra_resource_need_ids': _sorted(extraResourceNeedIds),
  };

  List<String> _sorted(Set<String> values) => values.toList()..sort();
}

final joinAcceptanceTriageGatewayProvider =
    Provider<JoinAcceptanceTriageGateway>((ref) {
      return SupabaseJoinAcceptanceTriageGateway(
        ref.watch(supabaseClientProvider),
      );
    });
