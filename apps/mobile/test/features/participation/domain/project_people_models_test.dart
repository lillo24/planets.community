import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/domain/project_people_models.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';

void main() {
  const participant = ProjectPerson(
    profileId: 'target',
    displayName: 'Sara',
    isCreator: false,
    roleRank: 3,
    membershipId: 'episode',
  );
  const organizer = ProjectPerson(
    profileId: 'target',
    displayName: 'Sara',
    isCreator: false,
    roleRank: 2,
    authorityRole: ProjectDelegatedAuthorityRole.coOrganizer,
    delegateId: 'authority',
    membershipId: 'episode',
  );
  const cocreator = ProjectPerson(
    profileId: 'target',
    displayName: 'Sara',
    isCreator: false,
    roleRank: 1,
    authorityRole: ProjectDelegatedAuthorityRole.coCreator,
    delegateId: 'authority',
  );
  const creator = ProjectPerson(
    profileId: 'target',
    displayName: 'Sara',
    isCreator: true,
    roleRank: 0,
    membershipId: 'episode',
  );
  for (final role in ProjectManagementRole.values) {
    test(
      '$role participant actions respect separate authority and membership',
      () {
        final actions = projectPersonActions(participant, role, 'viewer');
        expect(
          actions.contains(PeopleAction.removeParticipant),
          role.isManager,
        );
        expect(actions.contains(PeopleAction.commitments), role.isManager);
        expect(
          actions.contains(PeopleAction.inviteCoCreator),
          role.hasStructuralAuthority,
        );
        expect(
          actions.contains(PeopleAction.inviteCoOrganizer),
          role.hasStructuralAuthority,
        );
        expect(actions, isNot(contains(PeopleAction.stepDown)));
      },
    );
    test(
      '$role self organizer offers step-down, never generic self mutations',
      () {
        final actions = projectPersonActions(organizer, role, 'target');
        expect(actions, {
          PeopleAction.commitments,
          PeopleAction.actualContributions,
          PeopleAction.stepDown,
        });
      },
    );
    test(
      '$role other co-creator cannot be removed as a participant without membership',
      () {
        final actions = projectPersonActions(cocreator, role, 'viewer');
        expect(
          actions,
          role.hasStructuralAuthority
              ? {PeopleAction.makeCoOrganizer, PeopleAction.revokeAuthority}
              : <PeopleAction>{},
        );
      },
    );
    test('$role immutable creator never exposes authority mutations', () {
      final actions = projectPersonActions(creator, role, 'viewer');
      expect(
        actions.intersection({
          PeopleAction.inviteCoCreator,
          PeopleAction.makeCoOrganizer,
          PeopleAction.revokeAuthority,
          PeopleAction.stepDown,
        }),
        isEmpty,
      );
    });
  }
  test('ordinary participant can open only their own contributions', () {
    expect(
      projectPersonActions(participant, ProjectManagementRole.none, 'target'),
      {PeopleAction.commitments, PeopleAction.actualContributions},
    );
    expect(
      projectPersonActions(organizer, ProjectManagementRole.none, 'viewer'),
      isEmpty,
    );
  });
  test('strict payload parser does not manufacture private names or roles', () {
    final row = <String, dynamic>{
      'profile_id': 'target',
      'display_name': 'Private name',
      'is_creator': false,
      'role_rank': 2,
      'authority_role': 'co_organizer',
      'delegate_id': 'd',
      'current_membership_id': 'm',
      'joined_at': '2026-10-02T10:00:00Z',
    };
    final person = ProjectPerson.fromJson(row);
    expect(person.isParticipant, isTrue);
    expect(person.isManager, isTrue);
    expect(person.displayName, 'Private name');
    expect(
      () => ProjectPerson.fromJson({...row, 'display_name': null}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => ProjectPerson.fromJson({...row, 'authority_role': 'invented'}),
      throwsFormatException,
    );
  });
}
