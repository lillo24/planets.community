import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/application/join_acceptance_triage_controller.dart';
import 'package:planets_mobile/features/participation/data/join_acceptance_triage_gateway.dart';
import 'package:planets_mobile/features/participation/domain/join_acceptance_triage_models.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_refresh.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_join_acceptance_triage.dart';

void main() {
  test('loads skills/resources and zero selections as ready', () async {
    final gateway = FakeJoinAcceptanceTriageGateway()
      ..selections = [
        triageItemFixture(),
        triageItemFixture(
          id: 'need-1',
          kind: JoinAcceptanceSelectionKind.resource,
          label: 'Paint',
        ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.read(
      joinAcceptanceTriageProvider('request-1').notifier,
    );

    expect(await controller.load('user-1'), isTrue);
    expect(
      session.read(joinAcceptanceTriageProvider('request-1')).items,
      hasLength(2),
    );
    gateway.selections = [];
    expect(await controller.load('user-1'), isTrue);
    final state = session.read(joinAcceptanceTriageProvider('request-1'));
    expect(state.loadPhase, JoinAcceptanceTriageLoadPhase.ready);
    expect(state.items, isEmpty);
  });

  test(
    'read failure is safe and duplicate composite keys fail closed',
    () async {
      final gateway = FakeJoinAcceptanceTriageGateway()
        ..selectionError = StateError('private diagnostic');
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.read(
        joinAcceptanceTriageProvider('request-1').notifier,
      );

      expect(await controller.load('user-1'), isFalse);
      expect(
        session.read(joinAcceptanceTriageProvider('request-1')).failure,
        JoinAcceptanceTriageFailureKind.unavailable,
      );
      gateway
        ..selectionError = null
        ..selections = [triageItemFixture(), triageItemFixture()];
      expect(await controller.load('user-1'), isFalse);
    },
  );

  test('identity switch clears state and ignores a late response', () async {
    final pending = Completer<void>();
    final gateway = FakeJoinAcceptanceTriageGateway()
      ..selections = [triageItemFixture()]
      ..selectionDelay = pending.future;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final load = session
        .read(joinAcceptanceTriageProvider('request-1').notifier)
        .load('user-1');
    session
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    pending.complete();

    expect(await load, isFalse);
    final state = session.read(joinAcceptanceTriageProvider('request-1'));
    expect(state.items, isEmpty);
    expect(state.failure, JoinAcceptanceTriageFailureKind.forbidden);
  });

  test(
    'decisions replace each other and composite keys remain distinct',
    () async {
      final gateway = FakeJoinAcceptanceTriageGateway()
        ..selections = [
          triageItemFixture(id: 'shared'),
          triageItemFixture(
            id: 'shared',
            kind: JoinAcceptanceSelectionKind.resource,
            label: 'Shared resource ID',
          ),
        ];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.read(
        joinAcceptanceTriageProvider('request-1').notifier,
      );
      await controller.load('user-1');
      const skillKey = JoinAcceptanceItemKey(
        JoinAcceptanceSelectionKind.skill,
        'shared',
      );
      const resourceKey = JoinAcceptanceItemKey(
        JoinAcceptanceSelectionKind.resource,
        'shared',
      );

      controller.decide(skillKey, JoinAcceptanceDecision.needed);
      controller.decide(skillKey, JoinAcceptanceDecision.extra);
      controller.decide(resourceKey, JoinAcceptanceDecision.alreadyFound);
      final state = session.read(joinAcceptanceTriageProvider('request-1'));
      expect(state.items.first.decision, JoinAcceptanceDecision.extra);
      expect(state.items.last.decision, JoinAcceptanceDecision.alreadyFound);
    },
  );

  test(
    'incomplete acceptance validates locally and guides only once',
    () async {
      final gateway = FakeJoinAcceptanceTriageGateway()
        ..selections = [triageItemFixture()];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.read(
        joinAcceptanceTriageProvider('request-1').notifier,
      );
      await controller.load('user-1');

      expect(
        await controller.accept(),
        JoinAcceptanceTriageSubmitResult.incompleteWithGuidance,
      );
      var state = session.read(joinAcceptanceTriageProvider('request-1'));
      expect(state.validationAttempt, 1);
      expect(state.isInvalid(state.items.single.key), isTrue);
      expect(
        gateway.calls.where((call) => call.startsWith('accept:')),
        isEmpty,
      );
      expect(
        await controller.accept(),
        JoinAcceptanceTriageSubmitResult.incomplete,
      );
      state = session.read(joinAcceptanceTriageProvider('request-1'));
      expect(state.validationAttempt, 2);
      expect(state.hasShownFirstGuidance, isTrue);

      controller.decide(state.items.single.key, JoinAcceptanceDecision.needed);
      state = session.read(joinAcceptanceTriageProvider('request-1'));
      expect(state.isInvalid(state.items.single.key), isFalse);
    },
  );

  test('mixed decisions submit the exact six-set partition once', () async {
    final gateway = FakeJoinAcceptanceTriageGateway()
      ..selections = [
        triageItemFixture(id: 'skill-needed'),
        triageItemFixture(id: 'skill-found'),
        triageItemFixture(id: 'skill-extra'),
        triageItemFixture(
          id: 'resource-needed',
          kind: JoinAcceptanceSelectionKind.resource,
        ),
        triageItemFixture(
          id: 'resource-found',
          kind: JoinAcceptanceSelectionKind.resource,
        ),
        triageItemFixture(
          id: 'resource-extra',
          kind: JoinAcceptanceSelectionKind.resource,
        ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.read(
      joinAcceptanceTriageProvider('request-1').notifier,
    );
    await controller.load('user-1');
    final items = session.read(joinAcceptanceTriageProvider('request-1')).items;
    for (var index = 0; index < items.length; index++) {
      controller.decide(
        items[index].key,
        JoinAcceptanceDecision.values[index % 3],
      );
    }

    expect(
      await controller.accept(),
      JoinAcceptanceTriageSubmitResult.accepted,
    );
    expect(gateway.neededSkillIds, {'skill-needed'});
    expect(gateway.alreadyFoundSkillIds, {'skill-found'});
    expect(gateway.extraSkillIds, {'skill-extra'});
    expect(gateway.neededResourceNeedIds, {'resource-needed'});
    expect(gateway.alreadyFoundResourceNeedIds, {'resource-found'});
    expect(gateway.extraResourceNeedIds, {'resource-extra'});
    expect(session.read(projectChatRefreshProvider), 1);
  });

  test('zero selections accept with six empty sets', () async {
    final gateway = FakeJoinAcceptanceTriageGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.read(
      joinAcceptanceTriageProvider('request-1').notifier,
    );
    await controller.load('user-1');

    expect(
      await controller.accept(),
      JoinAcceptanceTriageSubmitResult.accepted,
    );
    expect(gateway.neededSkillIds, isEmpty);
    expect(gateway.alreadyFoundSkillIds, isEmpty);
    expect(gateway.extraSkillIds, isEmpty);
    expect(gateway.neededResourceNeedIds, isEmpty);
    expect(gateway.alreadyFoundResourceNeedIds, isEmpty);
    expect(gateway.extraResourceNeedIds, isEmpty);
  });

  test('22023 preserves decisions while 55000 is terminal', () async {
    final gateway = FakeJoinAcceptanceTriageGateway()
      ..selections = [triageItemFixture()]
      ..mutationError = const PostgrestException(
        message: 'private stale need',
        code: '22023',
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.read(
      joinAcceptanceTriageProvider('request-1').notifier,
    );
    await controller.load('user-1');
    final key = session
        .read(joinAcceptanceTriageProvider('request-1'))
        .items
        .single
        .key;
    controller.decide(key, JoinAcceptanceDecision.needed);

    expect(await controller.accept(), JoinAcceptanceTriageSubmitResult.failed);
    var state = session.read(joinAcceptanceTriageProvider('request-1'));
    expect(state.failure, JoinAcceptanceTriageFailureKind.projectNeedsChanged);
    expect(state.items.single.decision, JoinAcceptanceDecision.needed);

    gateway.mutationError = const PostgrestException(
      message: 'private conflict',
      code: '55000',
    );
    expect(await controller.accept(), JoinAcceptanceTriageSubmitResult.failed);
    state = session.read(joinAcceptanceTriageProvider('request-1'));
    expect(state.failure, JoinAcceptanceTriageFailureKind.conflict);
    expect(state.isTerminal, isTrue);
  });

  test(
    '42501 clears private selections and unknown failures stay safe',
    () async {
      final gateway = FakeJoinAcceptanceTriageGateway()
        ..selections = [triageItemFixture()]
        ..mutationError = const PostgrestException(
          message: 'private forbidden',
          code: '42501',
        );
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.read(
        joinAcceptanceTriageProvider('request-1').notifier,
      );
      await controller.load('user-1');
      final key = session
          .read(joinAcceptanceTriageProvider('request-1'))
          .items
          .single
          .key;
      controller.decide(key, JoinAcceptanceDecision.extra);
      expect(
        await controller.accept(),
        JoinAcceptanceTriageSubmitResult.failed,
      );
      var state = session.read(joinAcceptanceTriageProvider('request-1'));
      expect(state.failure, JoinAcceptanceTriageFailureKind.forbidden);
      expect(state.items, isEmpty);

      gateway
        ..mutationError = StateError('private unknown')
        ..selections = [];
      await controller.load('user-1');
      expect(
        await controller.accept(),
        JoinAcceptanceTriageSubmitResult.failed,
      );
      state = session.read(joinAcceptanceTriageProvider('request-1'));
      expect(state.failure, JoinAcceptanceTriageFailureKind.unavailable);
    },
  );

  test('PT409 maps to a terminal full-state failure', () {
    const error = PostgrestException(
      message: 'private capacity conflict',
      code: 'PT409',
    );
    expect(
      mapJoinAcceptanceTriageFailure(error),
      JoinAcceptanceTriageFailureKind.full,
    );
  });
}

ProviderContainer _readyContainer(FakeJoinAcceptanceTriageGateway gateway) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  addTearDown(auth.close);
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      joinAcceptanceTriageGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return container;
}
