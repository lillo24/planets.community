import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/data/join_acceptance_triage_gateway.dart';
import 'package:planets_mobile/features/participation/domain/join_acceptance_triage_models.dart';

void main() {
  const parser = JoinAcceptanceTriagePayloadParser();
  const contract = JoinAcceptanceTriageRpcContract();

  test('strictly parses skill and resource selections', () {
    final skill = parser.selection({
      'selection_kind': 'skill',
      'selection_id': 'skill-1',
      'label': 'Carpentry',
    });
    final resource = parser.selection({
      'selection_kind': 'resource',
      'selection_id': 'need-1',
      'label': 'Paint',
    });

    expect(skill.kind, JoinAcceptanceSelectionKind.skill);
    expect(skill.decision, isNull);
    expect(resource.kind, JoinAcceptanceSelectionKind.resource);
    expect(resource.label, 'Paint');
  });

  test('unknown kinds and malformed rows fail safely', () {
    expect(
      () => parser.selection({
        'selection_kind': 'anything',
        'selection_id': 'item-1',
        'label': 'Anything',
      }),
      throwsFormatException,
    );
    expect(() => parser.selection([]), throwsFormatException);
  });

  test('maps the B1 read and D1 eight-argument mutation exactly', () {
    expect(contract.selectionParams('creator-1', 'request-1'), {
      'p_expected_profile_id': 'creator-1',
      'p_request_id': 'request-1',
    });
    expect(
      contract.acceptParams(
        expectedManagerProfileId: 'creator-1',
        requestId: 'request-1',
        neededSkillIds: const {'skill-b', 'skill-a'},
        alreadyFoundSkillIds: const {'skill-c'},
        extraSkillIds: const {},
        neededResourceNeedIds: const {'need-2'},
        alreadyFoundResourceNeedIds: const {'need-4', 'need-3'},
        extraResourceNeedIds: const {'need-5'},
      ),
      {
        'p_expected_manager_profile_id': 'creator-1',
        'p_request_id': 'request-1',
        'p_needed_skill_ids': ['skill-a', 'skill-b'],
        'p_already_found_skill_ids': ['skill-c'],
        'p_extra_skill_ids': <String>[],
        'p_needed_resource_need_ids': ['need-2'],
        'p_already_found_resource_need_ids': ['need-3', 'need-4'],
        'p_extra_resource_need_ids': ['need-5'],
      },
    );
  });

  test('all-empty acceptance still supplies all six arrays', () {
    final params = contract.acceptParams(
      expectedManagerProfileId: 'creator-1',
      requestId: 'request-1',
      neededSkillIds: const {},
      alreadyFoundSkillIds: const {},
      extraSkillIds: const {},
      neededResourceNeedIds: const {},
      alreadyFoundResourceNeedIds: const {},
      extraResourceNeedIds: const {},
    );

    for (final name in [
      'p_needed_skill_ids',
      'p_already_found_skill_ids',
      'p_extra_skill_ids',
      'p_needed_resource_need_ids',
      'p_already_found_resource_need_ids',
      'p_extra_resource_need_ids',
    ]) {
      expect(params[name], isEmpty);
    }
  });

  test('gateway is RPC-only and no other mobile accept helper remains', () {
    final source = File(
      'lib/features/participation/data/join_acceptance_triage_gateway.dart',
    ).readAsStringSync();
    expect(
      source,
      contains("'list_own_project_join_request_contribution_selections'"),
    );
    expect(source, contains("'accept_project_join_request_as_manager'"));
    expect(source, isNot(contains('.from(')));

    final participation = File(
      'lib/features/participation/data/participation_gateway.dart',
    ).readAsStringSync();
    final messages = File('lib/features/messages/data/messages_gateway.dart')
        .readAsStringSync();
    expect(
      participation,
      isNot(contains("'accept_project_join_request_as_manager'")),
    );
    expect(
      messages,
      isNot(contains("'accept_project_join_request_as_manager'")),
    );
  });
}
