import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_delegates/application/project_delegate_controllers.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_delegates.dart';

void main() {
  test('loads exact management role and clears it on account switch', () async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.coOrganizer;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    await session.container
        .read(projectManagementRoleProvider.notifier)
        .load(
          expectedProfileId: 'user-1',
          projectId: 'project-1',
          projectKind: ProjectKind.oneTime,
        );
    expect(
      session.container.read(projectManagementRoleProvider).role,
      ProjectManagementRole.coOrganizer,
    );

    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    expect(
      session.container.read(projectManagementRoleProvider).phase,
      ProjectDelegateLoadPhase.idle,
    );
  });

  test(
    'acceptance is explicit, expected-profile bound, and clears token state',
    () async {
      final gateway = FakeProjectDelegateGateway()
        ..preview = ProjectDelegateInvitePreview(
          isAvailable: true,
          projectId: '00000000-0000-4000-8000-000000000001',
          projectKind: ProjectKind.oneTime,
          projectTitle: 'Community mural',
          expiresAt: DateTime.utc(2030),
        );
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final subscription = session.container.listen(
        projectInviteProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final controller = session.container.read(projectInviteProvider.notifier);

      await controller.load('A' * 43);
      expect(
        gateway.calls.where((call) => call.startsWith('accept:')),
        isEmpty,
      );
      final preview = await controller.accept('user-1');

      expect(preview?.projectTitle, 'Community mural');
      expect(gateway.calls, contains('accept:user-1:${'A' * 43}'));
      expect(session.container.read(projectInviteProvider).token, isNull);
    },
  );

  test(
    'create result token is returned but never retained in owner state',
    () async {
      final gateway = FakeProjectDelegateGateway()
        ..role = ProjectManagementRole.creator;
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(projectTeamProvider.notifier);

      await controller.load(
        expectedProfileId: 'user-1',
        projectId: 'project-1',
        projectKind: ProjectKind.oneTime,
      );
      final result = await controller.createInvitation(
        ProjectDelegatedAuthorityRole.coCreator,
      );

      expect(result?.token, 'A' * 43);
      expect(
        result?.requestedAuthorityRole,
        ProjectDelegatedAuthorityRole.coCreator,
      );
      expect(gateway.calls, contains('create:user-1:project-1:co_creator'));
      expect(
        session.container.read(projectTeamProvider).toString(),
        isNot(contains('A' * 43)),
      );
    },
  );

  test('created token survives an authoritative-list reload failure', () async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.creator;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(projectTeamProvider.notifier);
    await controller.load(
      expectedProfileId: 'user-1',
      projectId: 'project-1',
      projectKind: ProjectKind.oneTime,
    );
    gateway.listFailure = StateError('reload failed');

    final result = await controller.createInvitation(
      ProjectDelegatedAuthorityRole.coOrganizer,
    );

    expect(result?.token, 'A' * 43);
    expect(
      session.container.read(projectTeamProvider).phase,
      ProjectDelegateLoadPhase.failure,
    );
  });

  test('Co-creator can load the structural Project team surface', () async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.coCreator;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    await session.container
        .read(projectTeamProvider.notifier)
        .load(
          expectedProfileId: 'user-1',
          projectId: 'project-1',
          projectKind: ProjectKind.oneTime,
        );

    final state = session.container.read(projectTeamProvider);
    expect(state.phase, ProjectDelegateLoadPhase.ready);
    expect(state.actorRole, ProjectManagementRole.coCreator);
    expect(gateway.calls, contains('delegates:user-1:project-1'));
  });

  test('Co-organizer cannot load structural Project team data', () async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.coOrganizer;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    await session.container
        .read(projectTeamProvider.notifier)
        .load(
          expectedProfileId: 'user-1',
          projectId: 'project-1',
          projectKind: ProjectKind.oneTime,
        );

    final state = session.container.read(projectTeamProvider);
    expect(state.phase, ProjectDelegateLoadPhase.failure);
    expect(state.failure, ProjectDelegateFailureKind.forbidden);
    expect(state.delegates, isEmpty);
    expect(
      gateway.calls.where((call) => call.startsWith('delegates:')),
      isEmpty,
    );
  });

  test('capacity conflicts map to a dedicated delegate failure', () {
    expect(
      mapProjectDelegateFailure(
        const PostgrestException(
          message: 'Project capacity cannot add another organizer.',
          code: 'PT409',
        ),
      ),
      ProjectDelegateFailureKind.capacityConflict,
    );
  });

  test('role and revoke mutations refresh canonical team state', () async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.creator
      ..delegates = [
        ProjectDelegate(
          id: 'delegate-1',
          profileId: 'user-2',
          displayName: 'Jordan',
          delegatedAt: DateTime.utc(2030),
          grantedByProfileId: 'user-1',
          grantedByDisplayName: 'Creator',
        ),
      ]
      ..invitations = [
        ProjectDelegateInvitation(
          id: 'invitation-1',
          createdAt: DateTime.utc(2030),
          expiresAt: DateTime.utc(2030, 1, 8),
          issuerProfileId: 'user-1',
          issuerDisplayName: 'Creator',
        ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(projectTeamProvider.notifier);
    await controller.load(
      expectedProfileId: 'user-1',
      projectId: 'project-1',
      projectKind: ProjectKind.oneTime,
    );

    expect(
      await controller.changeDelegateRole(
        'delegate-1',
        ProjectDelegatedAuthorityRole.coCreator,
      ),
      isTrue,
    );
    expect(
      session.container
          .read(projectTeamProvider)
          .delegates
          .single
          .authorityRole,
      ProjectDelegatedAuthorityRole.coCreator,
    );
    expect(await controller.revokeInvitation('invitation-1'), isTrue);
    expect(session.container.read(projectTeamProvider).invitations, isEmpty);
    expect(await controller.revokeDelegate('delegate-1'), isTrue);
    expect(session.container.read(projectTeamProvider).delegates, isEmpty);
    expect(
      gateway.calls,
      containsAll([
        'change-role:user-1:delegate-1:co_creator',
        'revoke-invitation:user-1:invitation-1',
        'revoke-delegate:user-1:delegate-1',
      ]),
    );
    expect(
      gateway.calls.where((call) => call == 'role:user-1:project-1').length,
      4,
    );
  });

  test('stale authority failure clears retained team controls', () async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.creator
      ..delegates = [
        ProjectDelegate(
          id: 'delegate-1',
          profileId: 'user-2',
          displayName: 'Jordan',
          delegatedAt: DateTime.utc(2030),
          grantedByProfileId: 'user-1',
          grantedByDisplayName: 'Creator',
        ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(projectTeamProvider.notifier);
    await controller.load(
      expectedProfileId: 'user-1',
      projectId: 'project-1',
      projectKind: ProjectKind.oneTime,
    );
    gateway
      ..role = ProjectManagementRole.none
      ..mutationFailure = const PostgrestException(
        message: 'Authority changed.',
        code: '42501',
      );

    final changed = await controller.changeDelegateRole(
      'delegate-1',
      ProjectDelegatedAuthorityRole.coCreator,
    );

    expect(changed, isFalse);
    final state = session.container.read(projectTeamProvider);
    expect(state.actorRole, ProjectManagementRole.none);
    expect(state.failure, ProjectDelegateFailureKind.forbidden);
    expect(state.delegates, isEmpty);
    expect(state.invitations, isEmpty);
  });

  test('late team data is ignored after an account switch', () async {
    final delayedDelegates = Completer<List<ProjectDelegate>>();
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.creator
      ..delegatesResult = delayedDelegates.future;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final load = session.container
        .read(projectTeamProvider.notifier)
        .load(
          expectedProfileId: 'user-1',
          projectId: 'project-1',
          projectKind: ProjectKind.oneTime,
        );
    await Future<void>.delayed(Duration.zero);

    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    delayedDelegates.complete(const []);
    await load;

    expect(
      session.container.read(projectTeamProvider).phase,
      ProjectDelegateLoadPhase.idle,
    );
  });

  test('late mutation result is discarded after an account switch', () async {
    final delayedMutation = Completer<void>();
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.creator;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(projectTeamProvider.notifier);
    await controller.load(
      expectedProfileId: 'user-1',
      projectId: 'project-1',
      projectKind: ProjectKind.oneTime,
    );
    gateway.mutationDelay = delayedMutation.future;

    final result = controller.createInvitation(
      ProjectDelegatedAuthorityRole.coCreator,
    );
    await Future<void>.delayed(Duration.zero);
    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    delayedMutation.complete();

    expect(await result, isNull);
    expect(
      session.container.read(projectTeamProvider).phase,
      ProjectDelegateLoadPhase.idle,
    );
    expect(
      session.container.read(projectTeamProvider).toString(),
      isNot(contains('A' * 43)),
    );
  });
}

({ProviderContainer container, void Function() dispose}) _readyContainer(
  FakeProjectDelegateGateway gateway,
) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      projectDelegateGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return (
    container: container,
    dispose: () {
      container.dispose();
      auth.close();
    },
  );
}
