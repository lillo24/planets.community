import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/application/actual_contribution_controller.dart';
import 'package:planets_mobile/features/participation/data/actual_contribution_gateway.dart';
import 'package:planets_mobile/features/participation/domain/actual_contribution_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_actual_contribution.dart';
import '../../../support/fake_auth.dart';

void main() {
  test('maps the actual-contribution SQLSTATE contract', () {
    for (final entry in <String, ActualContributionFailureKind>{
      '40001': ActualContributionFailureKind.staleEdit,
      '22023': ActualContributionFailureKind.optionsChanged,
      '42501': ActualContributionFailureKind.forbidden,
      '55000': ActualContributionFailureKind.notAvailable,
      'P0002': ActualContributionFailureKind.notFound,
    }.entries) {
      expect(
        mapActualContributionFailure(
          PostgrestException(message: 'private detail', code: entry.key),
        ),
        entry.value,
      );
    }
  });

  test('read-only mode loads all kinds and never requests options', () async {
    final gateway = FakeActualContributionGateway()
      ..contributions = [
        actualContributionFixture(),
        actualContributionFixture(
          id: 'need-1',
          kind: ActualContributionKind.resource,
          label: 'Paint',
        ),
        substantialEffortFixture(),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    expect(
      await session.container
          .read(actualContributionProvider('membership-1').notifier)
          .load(expectedProfileId: 'user-1', editable: false),
      isTrue,
    );
    final state = session.container.read(
      actualContributionProvider('membership-1'),
    );
    expect(state.readPhase, ActualContributionReadPhase.ready);
    expect(state.optionsPhase, ActualContributionOptionsPhase.notRequested);
    expect(state.expectedSkillIds, {'skill-1'});
    expect(state.expectedResourceNeedIds, {'need-1'});
    expect(state.expectedSubstantialEffort, isTrue);
    expect(gateway.calls, ['contributions:membership-1']);
  });

  test('editable load creates a kind-and-ID keyed options union', () async {
    final gateway = FakeActualContributionGateway()
      ..contributions = [
        actualContributionFixture(id: 'shared', label: 'Carpentry'),
        actualContributionFixture(
          id: 'shared',
          kind: ActualContributionKind.resource,
          label: 'Wood',
          source: ActualContributionSource.creatorAdded,
        ),
      ]
      ..options = [
        actualContributionOptionFixture(id: 'shared'),
        actualContributionOptionFixture(
          id: 'shared',
          kind: ActualContributionKind.resource,
          label: 'Wood',
        ),
        actualContributionOptionFixture(id: 'skill-2', label: 'Painting'),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    await session.container
        .read(actualContributionProvider('membership-1').notifier)
        .load(expectedProfileId: 'user-1', editable: true);
    final state = session.container.read(
      actualContributionProvider('membership-1'),
    );
    expect(
      state.itemsFor(ActualContributionKind.skill).map((item) => item.id),
      ['shared', 'skill-2'],
    );
    expect(
      state.itemsFor(ActualContributionKind.resource).map((item) => item.id),
      ['shared'],
    );
    expect(
      state.itemsFor(ActualContributionKind.resource).single.source,
      ActualContributionSource.creatorAdded,
    );
  });

  test('options failure preserves factual read and retries locally', () async {
    final gateway = FakeActualContributionGateway()
      ..contributions = [actualContributionFixture()]
      ..optionsError = StateError('temporary');
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      actualContributionProvider('membership-1').notifier,
    );

    expect(
      await controller.load(expectedProfileId: 'user-1', editable: true),
      isFalse,
    );
    expect(
      session.container
          .read(actualContributionProvider('membership-1'))
          .contributions,
      hasLength(1),
    );
    gateway.optionsError = null;
    gateway.options = [actualContributionOptionFixture()];
    expect(await controller.retryOptions('user-1'), isTrue);
    expect(
      gateway.calls.where((call) => call.startsWith('contributions:')),
      hasLength(1),
    );
  });

  test(
    'read and options lifecycle failures become safe unavailable states',
    () async {
      final readGateway = FakeActualContributionGateway()
        ..readError = const PostgrestException(
          message: 'private lifecycle',
          code: '55000',
        );
      final readSession = _readyContainer(readGateway);
      addTearDown(readSession.dispose);
      await readSession.container
          .read(actualContributionProvider('membership-read').notifier)
          .load(expectedProfileId: 'user-1', editable: false);
      expect(
        readSession.container
            .read(actualContributionProvider('membership-read'))
            .readFailure,
        ActualContributionFailureKind.notAvailable,
      );

      final optionsGateway = FakeActualContributionGateway()
        ..contributions = [actualContributionFixture()]
        ..optionsError = const PostgrestException(
          message: 'private lifecycle',
          code: '55000',
        );
      final optionsSession = _readyContainer(optionsGateway);
      addTearDown(optionsSession.dispose);
      expect(
        await optionsSession.container
            .read(actualContributionProvider('membership-options').notifier)
            .load(expectedProfileId: 'user-1', editable: true),
        isTrue,
      );
      final state = optionsSession.container.read(
        actualContributionProvider('membership-options'),
      );
      expect(state.contributions, hasLength(1));
      expect(state.optionsPhase, ActualContributionOptionsPhase.notAvailable);
      expect(state.isEditable, isFalse);
    },
  );

  test(
    'toggles keep expected snapshot and enforce independent 50/50 limits',
    () async {
      final gateway = FakeActualContributionGateway()
        ..options = [
          for (var index = 0; index <= participationSkillSelectionMax; index++)
            actualContributionOptionFixture(id: 'skill-$index'),
          for (
            var index = 0;
            index <= participationResourceNeedSelectionMax;
            index++
          )
            actualContributionOptionFixture(
              id: 'need-$index',
              kind: ActualContributionKind.resource,
            ),
        ];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        actualContributionProvider('membership-1').notifier,
      );
      await controller.load(expectedProfileId: 'user-1', editable: true);

      for (var index = 0; index < participationSkillSelectionMax; index++) {
        expect(
          controller.toggle(ActualContributionKind.skill, 'skill-$index'),
          isTrue,
        );
      }
      expect(
        controller.toggle(ActualContributionKind.skill, 'skill-50'),
        isFalse,
      );
      for (
        var index = 0;
        index < participationResourceNeedSelectionMax;
        index++
      ) {
        expect(
          controller.toggle(ActualContributionKind.resource, 'need-$index'),
          isTrue,
        );
      }
      expect(
        controller.toggle(ActualContributionKind.resource, 'need-50'),
        isFalse,
      );
      controller.toggleSubstantialEffort();
      final state = session.container.read(
        actualContributionProvider('membership-1'),
      );
      expect(state.expectedSkillIds, isEmpty);
      expect(state.expectedResourceNeedIds, isEmpty);
      expect(state.expectedSubstantialEffort, isFalse);
      expect(state.desiredSkillIds, hasLength(50));
      expect(state.desiredResourceNeedIds, hasLength(50));
      expect(state.desiredSubstantialEffort, isTrue);
    },
  );

  test(
    'clear-all sends exact expected and desired CAS values then reloads',
    () async {
      final gateway = FakeActualContributionGateway()
        ..contributions = [
          actualContributionFixture(),
          actualContributionFixture(
            id: 'need-1',
            kind: ActualContributionKind.resource,
            label: 'Paint',
          ),
          substantialEffortFixture(),
        ]
        ..options = [
          actualContributionOptionFixture(),
          actualContributionOptionFixture(
            id: 'need-1',
            kind: ActualContributionKind.resource,
            label: 'Paint',
          ),
        ];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        actualContributionProvider('membership-1').notifier,
      );
      await controller.load(expectedProfileId: 'user-1', editable: true);
      controller.clearAll();

      expect(await controller.save('user-1'), isTrue);
      expect(gateway.lastExpectedSkillIds, {'skill-1'});
      expect(gateway.lastExpectedResourceNeedIds, {'need-1'});
      expect(gateway.lastExpectedSubstantialEffort, isTrue);
      expect(gateway.lastSkillIds, isEmpty);
      expect(gateway.lastResourceNeedIds, isEmpty);
      expect(gateway.lastSubstantialEffort, isFalse);
      final reloaded = session.container.read(
        actualContributionProvider('membership-1'),
      );
      expect(reloaded.contributions, isEmpty);
      expect(reloaded.isDirty, isFalse);
    },
  );

  test('no-op save never mutates', () async {
    final gateway = FakeActualContributionGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      actualContributionProvider('membership-1').notifier,
    );
    await controller.load(expectedProfileId: 'user-1', editable: true);

    expect(await controller.save('user-1'), isFalse);
    expect(gateway.calls.where((call) => call.startsWith('replace:')), isEmpty);
  });

  test(
    '40001 reloads latest and never resubmits stale desired state',
    () async {
      final gateway = FakeActualContributionGateway()
        ..contributions = [actualContributionFixture(id: 'skill-old')]
        ..options = [
          actualContributionOptionFixture(id: 'skill-old'),
          actualContributionOptionFixture(id: 'skill-new'),
        ]
        ..replaceErrors.add(
          const PostgrestException(message: 'private stale', code: '40001'),
        );
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        actualContributionProvider('membership-1').notifier,
      );
      await controller.load(expectedProfileId: 'user-1', editable: true);
      controller.toggle(ActualContributionKind.skill, 'skill-new');
      gateway.contributions = [
        actualContributionFixture(id: 'skill-concurrent'),
      ];

      expect(await controller.save('user-1'), isFalse);
      final state = session.container.read(
        actualContributionProvider('membership-1'),
      );
      expect(state.expectedSkillIds, {'skill-concurrent'});
      expect(state.desiredSkillIds, {'skill-concurrent'});
      expect(state.actionFailure, ActualContributionFailureKind.staleEdit);
      expect(
        gateway.calls.where((call) => call.startsWith('replace:')),
        hasLength(1),
      );
    },
  );

  test('22023 reloads options and discards the local draft', () async {
    final gateway = FakeActualContributionGateway()
      ..contributions = [actualContributionFixture(id: 'skill-old')]
      ..options = [
        actualContributionOptionFixture(id: 'skill-old'),
        actualContributionOptionFixture(id: 'skill-new'),
      ]
      ..replaceErrors.add(
        const PostgrestException(message: 'private option', code: '22023'),
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      actualContributionProvider('membership-1').notifier,
    );
    await controller.load(expectedProfileId: 'user-1', editable: true);
    controller.toggle(ActualContributionKind.skill, 'skill-new');
    gateway.options = [actualContributionOptionFixture(id: 'skill-old')];

    expect(await controller.save('user-1'), isFalse);
    final state = session.container.read(
      actualContributionProvider('membership-1'),
    );
    expect(state.desiredSkillIds, {'skill-old'});
    expect(state.actionFailure, ActualContributionFailureKind.optionsChanged);
    expect(
      gateway.calls.where((call) => call.startsWith('replace:')),
      hasLength(1),
    );
  });

  test(
    'forbidden and account switch clear private state and late reads',
    () async {
      final forbiddenGateway = FakeActualContributionGateway()
        ..contributions = [actualContributionFixture()]
        ..optionsError = const PostgrestException(
          message: 'private forbidden',
          code: '42501',
        );
      final forbiddenSession = _readyContainer(forbiddenGateway);
      addTearDown(forbiddenSession.dispose);
      await forbiddenSession.container
          .read(actualContributionProvider('membership-forbidden').notifier)
          .load(expectedProfileId: 'user-1', editable: true);
      expect(
        forbiddenSession.container
            .read(actualContributionProvider('membership-forbidden'))
            .contributions,
        isEmpty,
      );

      final pending = Completer<void>();
      final delayedGateway = FakeActualContributionGateway()
        ..contributions = [actualContributionFixture()]
        ..readDelay = pending.future;
      final delayedSession = _readyContainer(delayedGateway);
      addTearDown(delayedSession.dispose);
      final load = delayedSession.container
          .read(actualContributionProvider('membership-late').notifier)
          .load(expectedProfileId: 'user-1', editable: false);
      delayedSession.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      pending.complete();
      expect(await load, isFalse);
      final cleared = delayedSession.container.read(
        actualContributionProvider('membership-late'),
      );
      expect(cleared.expectedProfileId, isNull);
      expect(cleared.contributions, isEmpty);
    },
  );
}

({ProviderContainer container, FakeAuthGateway auth, void Function() dispose})
_readyContainer(FakeActualContributionGateway gateway) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      actualContributionGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return (
    container: container,
    auth: auth,
    dispose: () {
      container.dispose();
      auth.close();
    },
  );
}
