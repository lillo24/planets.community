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
    'independent edits/removal reconcile the full canonical collection',
    () async {
      final gateway = FakeProjectWorkspaceGateway()
        ..links.addAll([
          projectWorkspaceFixture(id: 'a'),
          projectWorkspaceFixture(id: 'b'),
        ]);
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectWorkspaceProvider.notifier,
      );
      await controller.load(
        expectedProfileId: 'user-1',
        projectId: 'proposal-1',
      );
      expect(
        await controller.saveLink(
          expectedManagerProfileId: 'user-1',
          projectId: 'proposal-1',
          name: 'Budget',
          input: 'https://example.org/budget',
          linkId: 'b',
        ),
        isTrue,
      );
      expect(
        session.container.read(projectWorkspaceProvider).links.map((x) => x.id),
        ['a', 'b'],
      );
      expect(gateway.links.first.url.hostname, 'drive.google.com');
      await controller.removeLink(
        expectedManagerProfileId: 'user-1',
        projectId: 'proposal-1',
        linkId: 'a',
      );
      expect(
        session.container.read(projectWorkspaceProvider).links.single.name,
        'Budget',
      );
    },
  );
  test('failed canonical refresh clears stale data and retry recovers committed link', () async {
    final gateway = FakeProjectWorkspaceGateway()
      ..readError = StateError('offline');
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectWorkspaceProvider.notifier,
    );
    expect(
      await controller.saveLink(
        expectedManagerProfileId: 'user-1',
        projectId: 'proposal-1',
        name: 'Doc',
        input: 'https://example.org',
      ),
      isFalse,
    );
    expect(
      session.container.read(projectWorkspaceProvider).phase,
      ProjectWorkspacePhase.failure,
    );
    expect(session.container.read(projectWorkspaceProvider).links, isEmpty);
    gateway.readError = null;
    await controller.load(expectedProfileId: 'user-1', projectId: 'proposal-1');
    expect(
      session.container.read(projectWorkspaceProvider).links.single.name,
      'Doc',
    );
  });
  test(
    'mutation failure retains collection; forbidden failure clears it',
    () async {
      final gateway = FakeProjectWorkspaceGateway()
        ..workspace = projectWorkspaceFixture();
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectWorkspaceProvider.notifier,
      );
      await controller.load(
        expectedProfileId: 'user-1',
        projectId: 'proposal-1',
      );
      gateway.mutationError = StateError('offline');
      expect(
        await controller.removeLink(
          expectedManagerProfileId: 'user-1',
          projectId: 'proposal-1',
          linkId: 'link-1',
        ),
        isFalse,
      );
      expect(
        session.container.read(projectWorkspaceProvider).links,
        hasLength(1),
      );
      gateway.mutationError = const PostgrestException(
        message: 'private',
        code: '42501',
      );
      expect(
        await controller.removeLink(
          expectedManagerProfileId: 'user-1',
          projectId: 'proposal-1',
          linkId: 'link-1',
        ),
        isFalse,
      );
      expect(session.container.read(projectWorkspaceProvider).links, isEmpty);
    },
  );
  test('project switch ignores stale reads and entitlement loss ignores stale mutation', () async {
    final pending = Completer<void>();
    final gateway = FakeProjectWorkspaceGateway()..readDelay = pending.future;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectWorkspaceProvider.notifier,
    );
    final first = controller.load(
      expectedProfileId: 'user-1',
      projectId: 'proposal-1',
    );
    final second = controller.load(
      expectedProfileId: 'user-1',
      projectId: 'proposal-2',
    );
    pending.complete();
    await Future.wait([first, second]);
    expect(
      session.container.read(projectWorkspaceProvider).projectId,
      'proposal-2',
    );
    final saving = Completer<void>();
    gateway.mutationDelay = saving.future;
    final save = controller.saveLink(
      expectedManagerProfileId: 'user-1',
      projectId: 'proposal-2',
      name: 'Doc',
      input: 'https://example.org',
    );
    controller.clearProject('proposal-2');
    saving.complete();
    expect(await save, isFalse);
    expect(
      session.container.read(projectWorkspaceProvider).phase,
      ProjectWorkspacePhase.idle,
    );
  });
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
      expect(state.links.firstOrNull?.url.hostname, 'drive.google.com');
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
        await controller.saveLink(
          expectedManagerProfileId: 'user-1',
          projectId: 'proposal-1',
          name: 'Documento',
          input: ' https://docs.example.org/team ',
        ),
        isTrue,
      );
      expect(
        session.container
            .read(projectWorkspaceProvider)
            .links
            .firstOrNull
            ?.url
            .value,
        'https://docs.example.org/team',
      );
      expect(
        await controller.removeLink(
          linkId: 'link-1',
          expectedManagerProfileId: 'user-1',
          projectId: 'proposal-1',
        ),
        isTrue,
      );
      expect(
        session.container.read(projectWorkspaceProvider).links.firstOrNull,
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
        session.container.read(projectWorkspaceProvider).links.firstOrNull,
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
        .saveLink(
          expectedManagerProfileId: 'user-1',
          projectId: 'proposal-1',
          name: 'Documento',
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
    expect(
      session.container.read(projectWorkspaceProvider).links.firstOrNull,
      isNull,
    );
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

    expect(
      session.container.read(projectWorkspaceProvider).links.firstOrNull,
      isNull,
    );
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
