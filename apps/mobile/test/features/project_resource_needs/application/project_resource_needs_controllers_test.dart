import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/project_resource_needs/application/project_resource_needs_controllers.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/domain/project_resource_need_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_resource_needs.dart';

void main() {
  test(
    'owner create, edit, and close refresh canonical history and public data',
    () async {
      final gateway = FakeProjectResourceNeedsGateway();
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        ownProjectResourceNeedsProvider('proposal-1').notifier,
      );

      expect(await controller.load('user-1'), isTrue);
      expect(
        await controller.create(
          expectedCreatorProfileId: 'user-1',
          input: const ProjectResourceNeedInput(
            title: '  Paint  ',
            details: '  Exterior paint.  ',
          ),
        ),
        isTrue,
      );
      expect(gateway.lastTitle, 'Paint');
      expect(gateway.lastDetails, 'Exterior paint.');
      expect(
        await controller.update(
          expectedCreatorProfileId: 'user-1',
          resourceNeedId: 'need-1',
          input: const ProjectResourceNeedInput(
            title: 'Wood paint',
            details: '',
          ),
        ),
        isTrue,
      );
      expect(gateway.lastDetails, isNull);
      expect(
        await controller.close(
          expectedCreatorProfileId: 'user-1',
          resourceNeedId: 'need-1',
        ),
        isTrue,
      );
      final state = session.container.read(
        ownProjectResourceNeedsProvider('proposal-1'),
      );
      expect(state.items.single.state, ProjectResourceNeedState.closed);
      expect(
        session.container
            .read(publicProjectResourceNeedsProvider('proposal-1'))
            .items,
        isEmpty,
      );
    },
  );

  test('invalid input fails before a mutation RPC', () async {
    final gateway = FakeProjectResourceNeedsGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      ownProjectResourceNeedsProvider('proposal-1').notifier,
    );
    await controller.load('user-1');

    expect(
      await controller.create(
        expectedCreatorProfileId: 'user-1',
        input: const ProjectResourceNeedInput(title: 'X', details: ''),
      ),
      isFalse,
    );
    expect(gateway.calls.where((call) => call.startsWith('create:')), isEmpty);
    expect(
      session.container
          .read(ownProjectResourceNeedsProvider('proposal-1'))
          .failure,
      ProjectResourceNeedsFailureKind.invalidInput,
    );
  });

  test('account switch clears owner history and rejects a late load', () async {
    final pending = Completer<void>();
    final gateway = FakeProjectResourceNeedsGateway()
      ..ownItems = [projectResourceNeedFixture()]
      ..ownerDelay = pending.future;
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      ownProjectResourceNeedsProvider('proposal-1').notifier,
    );
    final load = controller.load('user-1');
    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    pending.complete();

    expect(await load, isFalse);
    final state = session.container.read(
      ownProjectResourceNeedsProvider('proposal-1'),
    );
    expect(state.expectedCreatorProfileId, isNull);
    expect(state.items, isEmpty);
  });
}

({ProviderContainer container, FakeAuthGateway auth}) _readyContainer(
  FakeProjectResourceNeedsGateway gateway,
) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      projectResourceNeedsGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return (container: container, auth: auth);
}
