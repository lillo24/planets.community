import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_delegates/application/project_delegate_controllers.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_delegates.dart';

void main() {
  test('loads exact management role and clears it on account switch', () async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.delegate;
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
      ProjectManagementRole.delegate,
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
      final gateway = FakeProjectDelegateGateway();
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectCoorganizersProvider.notifier,
      );

      await controller.load(
        expectedOwnerId: 'user-1',
        projectId: 'project-1',
        projectKind: ProjectKind.oneTime,
      );
      final result = await controller.createInvitation();

      expect(result?.token, 'A' * 43);
      expect(
        session.container.read(projectCoorganizersProvider).toString(),
        isNot(contains('A' * 43)),
      );
    },
  );

  test('created token survives an authoritative-list reload failure', () async {
    final gateway = FakeProjectDelegateGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectCoorganizersProvider.notifier,
    );
    await controller.load(
      expectedOwnerId: 'user-1',
      projectId: 'project-1',
      projectKind: ProjectKind.oneTime,
    );
    gateway.listFailure = StateError('reload failed');

    final result = await controller.createInvitation();

    expect(result?.token, 'A' * 43);
    expect(
      session.container.read(projectCoorganizersProvider).phase,
      ProjectDelegateLoadPhase.failure,
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
