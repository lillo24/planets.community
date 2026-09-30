import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/data/membership_commitment_gateway.dart';
import 'package:planets_mobile/features/participation/domain/membership_commitment_models.dart';

void main() {
  const parser = MembershipCommitmentPayloadParser();
  const contract = MembershipCommitmentRpcContract();

  test('strictly parses skill/resource commitments and options', () {
    final skill = parser.commitment({
      'commitment_kind': 'skill',
      'commitment_id': 'skill-1',
      'label': 'Carpentry',
    });
    final resource = parser.option({
      'option_kind': 'resource',
      'option_id': 'need-1',
      'label': 'Wooden boards',
    });

    expect(skill.kind, MembershipCommitmentKind.skill);
    expect(skill.id, 'skill-1');
    expect(resource.kind, MembershipCommitmentKind.resource);
    expect(resource.label, 'Wooden boards');
  });

  test('unknown kinds and malformed rows fail safely', () {
    expect(
      () => parser.commitment({
        'commitment_kind': 'anything',
        'commitment_id': 'item-1',
        'label': 'Anything',
      }),
      throwsFormatException,
    );
    expect(() => parser.option([]), throwsFormatException);
  });

  test('maps reads and six-argument CAS replacement exactly', () {
    expect(contract.readParams('profile-1', 'membership-1'), {
      'p_expected_profile_id': 'profile-1',
      'p_membership_id': 'membership-1',
    });
    expect(
      contract.replaceParams(
        expectedActorProfileId: 'profile-1',
        membershipId: 'membership-1',
        expectedSkillIds: const {'skill-b', 'skill-a'},
        expectedResourceNeedIds: const {'need-2'},
        skillIds: const {'skill-c'},
        resourceNeedIds: const {'need-3', 'need-1'},
      ),
      {
        'p_expected_actor_profile_id': 'profile-1',
        'p_membership_id': 'membership-1',
        'p_expected_skill_ids': ['skill-a', 'skill-b'],
        'p_expected_resource_need_ids': ['need-2'],
        'p_skill_ids': ['skill-c'],
        'p_resource_need_ids': ['need-1', 'need-3'],
      },
    );
  });

  test('gateway source uses only the three authorized C1 RPCs', () {
    final source = File(
      'lib/features/participation/data/membership_commitment_gateway.dart',
    ).readAsStringSync();
    for (final rpc in [
      'list_own_project_membership_commitments',
      'list_own_project_membership_commitment_options',
      'replace_project_membership_commitments',
    ]) {
      expect(source, contains("'$rpc'"));
    }
    expect(source, isNot(contains(".from('project_membership")));
    expect(source, isNot(contains(".from('project_resource_needs")));
    expect(source, isNot(contains(".from('proposal_skill")));
  });
}
