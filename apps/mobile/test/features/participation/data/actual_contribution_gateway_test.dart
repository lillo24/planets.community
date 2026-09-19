import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/data/actual_contribution_gateway.dart';
import 'package:planets_mobile/features/participation/domain/actual_contribution_models.dart';

void main() {
  const parser = ActualContributionPayloadParser();
  const contract = ActualContributionRpcContract();

  test('strictly parses skill, resource, and null-shaped effort rows', () {
    final skill = parser.contribution({
      'contribution_kind': 'skill',
      'contribution_id': 'skill-1',
      'label': 'Carpentry',
      'attribution_source': 'final_commitment',
    });
    final resource = parser.contribution({
      'contribution_kind': 'resource',
      'contribution_id': 'need-1',
      'label': 'Wooden boards',
      'attribution_source': 'creator_added',
    });
    final effort = parser.contribution({
      'contribution_kind': 'substantial_effort',
      'contribution_id': null,
      'label': null,
      'attribution_source': 'substantial_effort',
    });

    expect(skill.kind, ActualContributionKind.skill);
    expect(skill.source, ActualContributionSource.finalCommitment);
    expect(resource.kind, ActualContributionKind.resource);
    expect(resource.source, ActualContributionSource.creatorAdded);
    expect(effort.id, isNull);
    expect(effort.label, isNull);
    expect(effort.source, ActualContributionSource.substantialEffort);
  });

  test('rejects invalid effort shapes, kinds, and attribution sources', () {
    expect(
      () => parser.contribution({
        'contribution_kind': 'substantial_effort',
        'contribution_id': 'fake-id',
        'label': null,
        'attribution_source': 'substantial_effort',
      }),
      throwsFormatException,
    );
    expect(
      () => parser.contribution({
        'contribution_kind': 'unknown',
        'contribution_id': 'item-1',
        'label': 'Unknown',
        'attribution_source': 'creator_added',
      }),
      throwsFormatException,
    );
    expect(
      () => parser.contribution({
        'contribution_kind': 'skill',
        'contribution_id': 'skill-1',
        'label': 'Carpentry',
        'attribution_source': 'verified',
      }),
      throwsFormatException,
    );
  });

  test('strictly parses only skill and resource options', () {
    final option = parser.option({
      'option_kind': 'resource',
      'option_id': 'need-1',
      'label': 'Paint',
    });
    expect(option.kind, ActualContributionKind.resource);
    expect(option.key, 'resource:need-1');
    expect(
      () => parser.option({
        'option_kind': 'substantial_effort',
        'option_id': 'fake-id',
        'label': 'Effort',
      }),
      throwsFormatException,
    );
  });

  test('maps exact reads and deterministic eight-argument CAS mutation', () {
    expect(contract.readParams('profile-1', 'membership-1'), {
      'p_expected_profile_id': 'profile-1',
      'p_membership_id': 'membership-1',
    });
    expect(contract.optionsParams('creator-1', 'membership-1'), {
      'p_expected_creator_profile_id': 'creator-1',
      'p_membership_id': 'membership-1',
    });
    expect(
      contract.replaceParams(
        expectedCreatorProfileId: 'creator-1',
        membershipId: 'membership-1',
        expectedSkillIds: const {'skill-b', 'skill-a'},
        expectedResourceNeedIds: const {'need-2', 'need-1'},
        expectedSubstantialEffort: true,
        skillIds: const {'skill-c'},
        resourceNeedIds: const {'need-4', 'need-3'},
        substantialEffort: false,
      ),
      {
        'p_expected_creator_profile_id': 'creator-1',
        'p_membership_id': 'membership-1',
        'p_expected_skill_ids': ['skill-a', 'skill-b'],
        'p_expected_resource_need_ids': ['need-1', 'need-2'],
        'p_expected_substantial_effort': true,
        'p_skill_ids': ['skill-c'],
        'p_resource_need_ids': ['need-3', 'need-4'],
        'p_substantial_effort': false,
      },
    );
  });

  test('gateway source uses only the three authorized 05C1 RPCs', () {
    final source = File(
      'lib/features/participation/data/actual_contribution_gateway.dart',
    ).readAsStringSync();
    for (final rpc in [
      'list_project_membership_actual_contributions',
      'list_project_membership_actual_contribution_options',
      'replace_project_membership_actual_contributions',
    ]) {
      expect(source, contains("'$rpc'"));
    }
    expect(source, isNot(contains('.from(')));
  });
}
