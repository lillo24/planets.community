import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/application/membership_commitment_controller.dart';
import 'package:planets_mobile/features/participation/data/membership_commitment_gateway.dart';
import 'package:planets_mobile/features/participation/domain/membership_commitment_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_membership_commitment.dart';

void main() {
  test('maps the commitment SQLSTATE contract', () {
    expect(
      mapMembershipCommitmentFailure(
        const PostgrestException(message: 'stale', code: 'PT409'),
      ),
      MembershipCommitmentFailureKind.staleEdit,
    );
    expect(
      mapMembershipCommitmentFailure(
        const PostgrestException(
          message: 'genuine serialization failure',
          code: '40001',
        ),
      ),
      MembershipCommitmentFailureKind.unavailable,
    );
    expect(
      mapMembershipCommitmentFailure(
        const PostgrestException(message: 'option', code: '22023'),
      ),
      MembershipCommitmentFailureKind.optionsChanged,
    );
    expect(
      mapMembershipCommitmentFailure(
        const PostgrestException(message: 'forbidden', code: '42501'),
      ),
      MembershipCommitmentFailureKind.forbidden,
    );
    expect(
      mapMembershipCommitmentFailure(
        const PostgrestException(message: 'lifecycle', code: '55000'),
      ),
      MembershipCommitmentFailureKind.noLongerEditable,
    );
    expect(
      mapMembershipCommitmentFailure(
        const PostgrestException(message: 'missing', code: 'P0002'),
      ),
      MembershipCommitmentFailureKind.notFound,
    );
  });

  test(
    'loads current and options separately and retains stale selections',
    () async {
      final gateway = FakeMembershipCommitmentGateway()
        ..commitments = [
          membershipCommitmentFixture(id: 'skill-stale', label: 'Old ladder'),
          membershipCommitmentFixture(id: 'skill-current'),
        ]
        ..options = [
          membershipCommitmentOptionFixture(id: 'skill-current'),
          membershipCommitmentOptionFixture(id: 'skill-new', label: 'Painting'),
        ];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);

      expect(
        await session.container
            .read(membershipCommitmentProvider('membership-1').notifier)
            .load(expectedProfileId: 'user-1', editable: true),
        isTrue,
      );
      final state = session.container.read(
        membershipCommitmentProvider('membership-1'),
      );
      expect(state.readPhase, MembershipCommitmentReadPhase.ready);
      expect(state.optionsPhase, MembershipCommitmentOptionsPhase.ready);
      expect(state.expectedSkillIds, {'skill-stale', 'skill-current'});
      final items = state
          .itemsFor(MembershipCommitmentKind.skill)
          .toList(growable: false);
      expect(items.map((item) => item.id), [
        'skill-stale',
        'skill-current',
        'skill-new',
      ]);
      expect(items[0].isRetained, isTrue);
      expect(items[1].isRetained, isFalse);
      expect(items[2].isRetained, isFalse);
    },
  );

  test('initial option loading does not infer retained commitments', () async {
    final pendingOptions = Completer<void>();
    final gateway = FakeMembershipCommitmentGateway()
      ..commitments = [membershipCommitmentFixture()]
      ..optionsDelay = pendingOptions.future;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      membershipCommitmentProvider('membership-1').notifier,
    );

    final load = controller.load(expectedProfileId: 'user-1', editable: true);
    await pumpEventQueue();
    final loading = session.container.read(
      membershipCommitmentProvider('membership-1'),
    );
    expect(loading.readPhase, MembershipCommitmentReadPhase.ready);
    expect(loading.optionsPhase, MembershipCommitmentOptionsPhase.loading);
    expect(
      loading.itemsFor(MembershipCommitmentKind.skill).single.isRetained,
      isFalse,
    );

    pendingOptions.complete();
    expect(await load, isTrue);
  });

  test('historical reads do not infer retained commitments', () async {
    final gateway = FakeMembershipCommitmentGateway()
      ..commitments = [membershipCommitmentFixture()];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    expect(
      await session.container
          .read(membershipCommitmentProvider('membership-1').notifier)
          .load(expectedProfileId: 'user-1', editable: false),
      isTrue,
    );
    final state = session.container.read(
      membershipCommitmentProvider('membership-1'),
    );
    expect(state.optionsPhase, MembershipCommitmentOptionsPhase.notRequested);
    expect(
      state.itemsFor(MembershipCommitmentKind.skill).single.isRetained,
      isFalse,
    );
    expect(gateway.calls.where((call) => call.startsWith('options:')), isEmpty);
  });

  test('keeps commitment read when options fail and retries locally', () async {
    final gateway = FakeMembershipCommitmentGateway()
      ..commitments = [membershipCommitmentFixture()]
      ..optionsError = StateError('temporary');
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      membershipCommitmentProvider('membership-1').notifier,
    );

    expect(
      await controller.load(expectedProfileId: 'user-1', editable: true),
      isFalse,
    );
    final failed = session.container.read(
      membershipCommitmentProvider('membership-1'),
    );
    expect(failed.commitments, hasLength(1));
    expect(failed.optionsPhase, MembershipCommitmentOptionsPhase.failure);
    expect(
      failed.itemsFor(MembershipCommitmentKind.skill).single.isRetained,
      isFalse,
    );
    gateway.optionsError = null;
    gateway.options = [membershipCommitmentOptionFixture()];
    expect(await controller.retryOptions('user-1'), isTrue);
    expect(
      gateway.calls.where((call) => call.startsWith('commitments:')),
      hasLength(1),
    );
  });

  test(
    '55000 options response preserves read and becomes final read-only',
    () async {
      final gateway = FakeMembershipCommitmentGateway()
        ..commitments = [membershipCommitmentFixture()]
        ..optionsError = const PostgrestException(
          message: 'private lifecycle detail',
          code: '55000',
        );
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);

      expect(
        await session.container
            .read(membershipCommitmentProvider('membership-1').notifier)
            .load(expectedProfileId: 'user-1', editable: true),
        isTrue,
      );
      final state = session.container.read(
        membershipCommitmentProvider('membership-1'),
      );
      expect(state.commitments, hasLength(1));
      expect(
        state.optionsPhase,
        MembershipCommitmentOptionsPhase.noLongerEditable,
      );
      expect(state.isEditable, isFalse);
      expect(
        state.itemsFor(MembershipCommitmentKind.skill).single.isRetained,
        isFalse,
      );
    },
  );

  test(
    'authoritative empty options classify current commitments retained',
    () async {
      final gateway = FakeMembershipCommitmentGateway()
        ..commitments = [membershipCommitmentFixture()]
        ..options = [];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);

      expect(
        await session.container
            .read(membershipCommitmentProvider('membership-1').notifier)
            .load(expectedProfileId: 'user-1', editable: true),
        isTrue,
      );
      final state = session.container.read(
        membershipCommitmentProvider('membership-1'),
      );
      expect(state.optionsPhase, MembershipCommitmentOptionsPhase.ready);
      expect(state.options, isEmpty);
      expect(
        state.itemsFor(MembershipCommitmentKind.skill).single.isRetained,
        isTrue,
      );
    },
  );

  test('stale commitment can toggle off and on before CAS save', () async {
    final gateway = FakeMembershipCommitmentGateway()
      ..commitments = [membershipCommitmentFixture(id: 'skill-stale')]
      ..options = [membershipCommitmentOptionFixture(id: 'skill-new')];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      membershipCommitmentProvider('membership-1').notifier,
    );
    await controller.load(expectedProfileId: 'user-1', editable: true);

    expect(
      controller.toggle(MembershipCommitmentKind.skill, 'skill-stale'),
      isTrue,
    );
    expect(
      controller.toggle(MembershipCommitmentKind.skill, 'skill-stale'),
      isTrue,
    );
    expect(
      controller.toggle(MembershipCommitmentKind.skill, 'skill-new'),
      isTrue,
    );
    expect(await controller.save('user-1'), isTrue);
    expect(gateway.lastExpectedSkillIds, {'skill-stale'});
    expect(gateway.lastSkillIds, {'skill-stale', 'skill-new'});
    expect(gateway.lastExpectedProfileId, 'user-1');
  });

  test('saved stale removal disappears after canonical reload', () async {
    final gateway = FakeMembershipCommitmentGateway()
      ..commitments = [membershipCommitmentFixture(id: 'skill-stale')]
      ..options = [membershipCommitmentOptionFixture(id: 'skill-new')];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      membershipCommitmentProvider('membership-1').notifier,
    );
    await controller.load(expectedProfileId: 'user-1', editable: true);

    expect(
      controller.toggle(MembershipCommitmentKind.skill, 'skill-stale'),
      isTrue,
    );
    expect(await controller.save('user-1'), isTrue);
    final state = session.container.read(
      membershipCommitmentProvider('membership-1'),
    );
    expect(state.commitments, isEmpty);
    expect(
      state.itemsFor(MembershipCommitmentKind.skill).map((item) => item.id),
      ['skill-new'],
    );
  });

  test('enforces independent 50/50 limits and clear-all is valid', () async {
    final gateway = FakeMembershipCommitmentGateway()
      ..options = [
        for (var index = 0; index <= participationSkillSelectionMax; index++)
          membershipCommitmentOptionFixture(id: 'skill-$index'),
        for (
          var index = 0;
          index <= participationResourceNeedSelectionMax;
          index++
        )
          membershipCommitmentOptionFixture(
            id: 'need-$index',
            kind: MembershipCommitmentKind.resource,
          ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      membershipCommitmentProvider('membership-1').notifier,
    );
    await controller.load(expectedProfileId: 'user-1', editable: true);

    for (var index = 0; index < participationSkillSelectionMax; index++) {
      expect(
        controller.toggle(MembershipCommitmentKind.skill, 'skill-$index'),
        isTrue,
      );
    }
    expect(
      controller.toggle(MembershipCommitmentKind.skill, 'skill-50'),
      isFalse,
    );
    for (
      var index = 0;
      index < participationResourceNeedSelectionMax;
      index++
    ) {
      expect(
        controller.toggle(MembershipCommitmentKind.resource, 'need-$index'),
        isTrue,
      );
    }
    expect(
      controller.toggle(MembershipCommitmentKind.resource, 'need-50'),
      isFalse,
    );
    controller.clearAll();
    final cleared = session.container.read(
      membershipCommitmentProvider('membership-1'),
    );
    expect(cleared.desiredSkillIds, isEmpty);
    expect(cleared.desiredResourceNeedIds, isEmpty);
    expect(cleared.isDirty, isFalse);
    expect(await controller.save('user-1'), isFalse);
    expect(gateway.calls.where((call) => call.startsWith('replace:')), isEmpty);
  });

  test(
    'retained selections count toward limits and clear-all saves empty sets',
    () async {
      final gateway = FakeMembershipCommitmentGateway()
        ..commitments = [membershipCommitmentFixture(id: 'skill-stale')]
        ..options = [
          for (var index = 0; index < participationSkillSelectionMax; index++)
            membershipCommitmentOptionFixture(id: 'skill-$index'),
        ];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        membershipCommitmentProvider('membership-1').notifier,
      );
      await controller.load(expectedProfileId: 'user-1', editable: true);

      for (var index = 0; index < participationSkillSelectionMax - 1; index++) {
        expect(
          controller.toggle(MembershipCommitmentKind.skill, 'skill-$index'),
          isTrue,
        );
      }
      expect(
        controller.toggle(MembershipCommitmentKind.skill, 'skill-49'),
        isFalse,
      );
      controller.clearAll();
      expect(await controller.save('user-1'), isTrue);
      expect(gateway.lastExpectedSkillIds, {'skill-stale'});
      expect(gateway.lastSkillIds, isEmpty);
      expect(gateway.lastResourceNeedIds, isEmpty);
    },
  );

  test(
    'PT409 reloads canonical current/options and resets desired state',
    () async {
      final gateway = FakeMembershipCommitmentGateway()
        ..commitments = [membershipCommitmentFixture(id: 'skill-old')]
        ..options = [
          membershipCommitmentOptionFixture(id: 'skill-old'),
          membershipCommitmentOptionFixture(id: 'skill-new'),
        ]
        ..replaceErrors.add(
          const PostgrestException(
            message: 'private stale detail',
            code: 'PT409',
          ),
        );
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        membershipCommitmentProvider('membership-1').notifier,
      );
      await controller.load(expectedProfileId: 'user-1', editable: true);
      controller.toggle(MembershipCommitmentKind.skill, 'skill-new');
      gateway.commitments = [
        membershipCommitmentFixture(id: 'skill-concurrent'),
      ];

      expect(await controller.save('user-1'), isFalse);
      final state = session.container.read(
        membershipCommitmentProvider('membership-1'),
      );
      expect(state.expectedSkillIds, {'skill-concurrent'});
      expect(state.desiredSkillIds, {'skill-concurrent'});
      expect(state.actionFailure, MembershipCommitmentFailureKind.staleEdit);
      expect(
        gateway.calls.where((call) => call.startsWith('replace:')),
        hasLength(1),
      );
    },
  );

  test('22023 reloads options and resets desired state', () async {
    final gateway = FakeMembershipCommitmentGateway()
      ..commitments = [membershipCommitmentFixture(id: 'skill-old')]
      ..options = [
        membershipCommitmentOptionFixture(id: 'skill-old'),
        membershipCommitmentOptionFixture(id: 'skill-new'),
      ]
      ..replaceErrors.add(
        const PostgrestException(
          message: 'private option detail',
          code: '22023',
        ),
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      membershipCommitmentProvider('membership-1').notifier,
    );
    await controller.load(expectedProfileId: 'user-1', editable: true);
    controller.toggle(MembershipCommitmentKind.skill, 'skill-new');
    gateway.options = [membershipCommitmentOptionFixture(id: 'skill-old')];

    expect(await controller.save('user-1'), isFalse);
    final state = session.container.read(
      membershipCommitmentProvider('membership-1'),
    );
    expect(state.desiredSkillIds, {'skill-old'});
    expect(state.actionFailure, MembershipCommitmentFailureKind.optionsChanged);
  });

  test('save-time 55000 reloads commitments into read-only state', () async {
    final gateway = FakeMembershipCommitmentGateway()
      ..commitments = [membershipCommitmentFixture(id: 'skill-old')]
      ..options = [
        membershipCommitmentOptionFixture(id: 'skill-old'),
        membershipCommitmentOptionFixture(id: 'skill-new'),
      ]
      ..replaceErrors.add(
        const PostgrestException(
          message: 'private lifecycle detail',
          code: '55000',
        ),
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      membershipCommitmentProvider('membership-1').notifier,
    );
    await controller.load(expectedProfileId: 'user-1', editable: true);
    controller.toggle(MembershipCommitmentKind.skill, 'skill-new');

    expect(await controller.save('user-1'), isFalse);
    final state = session.container.read(
      membershipCommitmentProvider('membership-1'),
    );
    expect(state.commitments, hasLength(1));
    expect(
      state.optionsPhase,
      MembershipCommitmentOptionsPhase.noLongerEditable,
    );
    expect(
      state.actionFailure,
      MembershipCommitmentFailureKind.noLongerEditable,
    );
  });

  test(
    'account switch rejects a late response and clears private state',
    () async {
      final pending = Completer<void>();
      final gateway = FakeMembershipCommitmentGateway()
        ..commitments = [membershipCommitmentFixture()]
        ..readDelay = pending.future;
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final load = session.container
          .read(membershipCommitmentProvider('membership-1').notifier)
          .load(expectedProfileId: 'user-1', editable: true);

      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      pending.complete();
      expect(await load, isFalse);
      final state = session.container.read(
        membershipCommitmentProvider('membership-1'),
      );
      expect(state.expectedProfileId, isNull);
      expect(state.commitments, isEmpty);
      expect(state.options, isEmpty);
    },
  );
}

({ProviderContainer container, FakeAuthGateway auth, void Function() dispose})
_readyContainer(FakeMembershipCommitmentGateway gateway) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      membershipCommitmentGatewayProvider.overrideWithValue(gateway),
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
