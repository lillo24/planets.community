import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/project_workspace/application/project_workspace_controller.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_workspace.dart';

void main() {
  test(
    'loads participant/manager read state and binds expected profile',
    () async {
      final gateway = FakeProjectWorkspaceGateway()
        ..workspace = projectWorkspaceFixture();
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);

      await session.container
          .read(projectWorkspaceProvider.notifier)
          .load(expectedProfileId: 'user-1', projectId: 'proposal-1');

      final state = session.container.read(projectWorkspaceProvider);
      expect(state.phase, ProjectWorkspacePhase.ready);
      expect(state.workspace?.url.hostname, 'drive.google.com');
      expect(gateway.calls, ['get:user-1:proposal-1']);
    },
  );

  test(
    'set and clear map manager identity and update canonical state',
    () async {
      final gateway = FakeProjectWorkspaceGateway();
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectWorkspaceProvider.notifier,
      );

      expect(
        await controller.setWorkspace(
          expectedManagerProfileId: 'user-1',
          projectId: 'proposal-1',
          input: ' https://docs.example.org/team ',
        ),
        isTrue,
      );
      expect(
        session.container.read(projectWorkspaceProvider).workspace?.url.value,
        'https://docs.example.org/team',
      );
      expect(
        await controller.clearWorkspace(
          expectedManagerProfileId: 'user-1',
          projectId: 'proposal-1',
        ),
        isTrue,
      );
      expect(
        session.container.read(projectWorkspaceProvider).workspace,
        isNull,
      );
    },
  );

  test(
    'identity switch clears sensitive state and ignores a late read',
    () async {
      final pending = Completer<void>();
      final gateway = FakeProjectWorkspaceGateway()
        ..workspace = projectWorkspaceFixture()
        ..readDelay = pending.future;
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);

      final load = session.container
          .read(projectWorkspaceProvider.notifier)
          .load(expectedProfileId: 'user-1', projectId: 'proposal-1');
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      pending.complete();
      await load;

      expect(
        session.container.read(projectWorkspaceProvider).phase,
        ProjectWorkspacePhase.idle,
      );
      expect(
        session.container.read(projectWorkspaceProvider).workspace,
        isNull,
      );
    },
  );

  test('identity switch ignores a late manager save response', () async {
    final pending = Completer<void>();
    final gateway = FakeProjectWorkspaceGateway()
      ..mutationDelay = pending.future;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    final save = session.container
        .read(projectWorkspaceProvider.notifier)
        .setWorkspace(
          expectedManagerProfileId: 'user-1',
          projectId: 'proposal-1',
          input: 'https://example.org/team',
        );
    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    pending.complete();
    expect(await save, isFalse);

    expect(
      session.container.read(projectWorkspaceProvider).phase,
      ProjectWorkspacePhase.idle,
    );
    expect(session.container.read(projectWorkspaceProvider).workspace, isNull);
  });

  test('entitlement loss clears the current project immediately', () async {
    final gateway = FakeProjectWorkspaceGateway()
      ..workspace = projectWorkspaceFixture();
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectWorkspaceProvider.notifier,
    );
    await controller.load(expectedProfileId: 'user-1', projectId: 'proposal-1');

    controller.clearProject('proposal-1');

    expect(session.container.read(projectWorkspaceProvider).workspace, isNull);
    expect(
      session.container.read(projectWorkspaceProvider).phase,
      ProjectWorkspacePhase.idle,
    );
  });

  test('maps validation, authorization, and unknown failures safely', () {
    expect(
      mapProjectWorkspaceFailure(
        const PostgrestException(message: 'private', code: '22023'),
      ),
      ProjectWorkspaceFailureKind.invalidUrl,
    );
    expect(
      mapProjectWorkspaceFailure(
        const PostgrestException(message: 'private', code: '42501'),
      ),
      ProjectWorkspaceFailureKind.forbidden,
    );
    expect(
      mapProjectWorkspaceFailure(StateError('private diagnostic')),
      ProjectWorkspaceFailureKind.unavailable,
    );
  });
}

({ProviderContainer container, void Function() dispose}) _readyContainer(
  FakeProjectWorkspaceGateway gateway,
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
      projectWorkspaceGatewayProvider.overrideWithValue(gateway),
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
