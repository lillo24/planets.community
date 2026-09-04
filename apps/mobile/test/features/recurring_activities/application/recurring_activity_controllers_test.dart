import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/recurring_activities/application/recurring_activity_controllers.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/domain/recurring_activity_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_recurring_activity.dart';

void main() {
  test('pagination reuses one snapshot and sends the keyset cursor', () async {
    var clock = DateTime.utc(2026, 9, 4, 10);
    final gateway = FakeRecurringActivityGateway()
      ..publicItems = List.generate(
        recurringActivityPageSize,
        (index) => publicRecurringSummaryFixture(id: 'tavolo-$index'),
      );
    final container = ProviderContainer(
      overrides: [
        recurringActivityGatewayProvider.overrideWithValue(gateway),
        recurringActivityClockProvider.overrideWithValue(() => clock),
      ],
    );
    addTearDown(container.dispose);
    await container.read(publicRecurringActivitiesProvider.notifier).load();
    clock = DateTime.utc(2026, 9, 5, 10);
    await container
        .read(publicRecurringActivitiesProvider.notifier)
        .load(reset: false);
    expect(gateway.referenceTimes, everyElement(DateTime.utc(2026, 9, 4, 10)));
    expect(gateway.lastCursor?.id, 'tavolo-19');
    expect(
      gateway.lastCursor?.nextStartsAt,
      publicRecurringSummaryFixture().nextOccurrence.startsAt,
    );
  });

  test('refresh and locality changes create new snapshots', () async {
    final times = [
      DateTime.utc(2026, 9, 4, 10),
      DateTime.utc(2026, 9, 4, 11),
      DateTime.utc(2026, 9, 4, 12),
    ];
    var index = 0;
    final gateway = FakeRecurringActivityGateway();
    final container = ProviderContainer(
      overrides: [
        recurringActivityGatewayProvider.overrideWithValue(gateway),
        recurringActivityClockProvider.overrideWithValue(() => times[index++]),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      publicRecurringActivitiesProvider.notifier,
    );
    await controller.load();
    await controller.load();
    await controller.applyLocality(' Bologna ');
    expect(gateway.referenceTimes, times);
    expect(gateway.lastLocality, 'Bologna');
  });

  test(
    'late response from an older snapshot and filter is discarded',
    () async {
      final first = Completer<List<PublicRecurringActivitySummary>>();
      final second = Completer<List<PublicRecurringActivitySummary>>();
      var call = 0;
      final gateway = FakeRecurringActivityGateway()
        ..publicLoader = ({
          required referenceTime,
          required limit,
          cursor,
          locality,
        }) => call++ == 0 ? first.future : second.future;
      var hour = 10;
      final container = ProviderContainer(
        overrides: [
          recurringActivityGatewayProvider.overrideWithValue(gateway),
          recurringActivityClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 9, 4, hour++),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        publicRecurringActivitiesProvider.notifier,
      );
      final oldLoad = controller.load();
      final newLoad = controller.applyLocality('Rome');
      second.complete([publicRecurringSummaryFixture(id: 'new')]);
      await newLoad;
      first.complete([publicRecurringSummaryFixture(id: 'old')]);
      await oldLoad;
      expect(
        container.read(publicRecurringActivitiesProvider).items.single.id,
        'new',
      );
    },
  );

  test(
    'create then save updates the same draft and publish is canonical',
    () async {
      final gateway = FakeRecurringActivityGateway();
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        recurringActivityEditorProvider.notifier,
      );
      await controller.load('user-1', null);
      final id = await controller.saveDraft('user-1', recurringInputFixture());
      expect(id, 'new-tavolo');
      await controller.saveDraft('user-1', recurringInputFixture());
      await controller.publish('user-1', recurringInputFixture());
      expect(
        gateway.calls,
        containsAllInOrder([
          'create',
          'own-detail:new-tavolo',
          'update:new-tavolo',
          'own-detail:new-tavolo',
          'update:new-tavolo',
          'publish:new-tavolo',
        ]),
      );
    },
  );

  for (final command in ['publish', 'pause', 'resume', 'end']) {
    test('account switch rejects late $command continuation', () async {
      final pending = Completer<void>();
      final gateway = FakeRecurringActivityGateway()
        ..ownItems = [ownRecurringActivityFixture()]
        ..mutationDelay = pending.future;
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final owner = session.container.read(
        ownRecurringActivitiesProvider.notifier,
      );
      await owner.load('user-1');
      final mutation = switch (command) {
        'publish' => owner.publish('user-1', 'tavolo-1'),
        'pause' => owner.pause('user-1', 'tavolo-1'),
        'resume' => owner.resume('user-1', 'tavolo-1'),
        _ => owner.end('user-1', 'tavolo-1'),
      };
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      pending.complete();
      expect(await mutation, isFalse);
      expect(
        session.container.read(ownRecurringActivitiesProvider).items,
        isEmpty,
      );
    });
  }

  test('logout during create prevents the follow-up publish', () async {
    final pending = Completer<void>();
    final gateway = FakeRecurringActivityGateway()
      ..mutationDelay = pending.future;
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      recurringActivityEditorProvider.notifier,
    );
    await controller.load('user-1', null);
    final saving = controller.publish('user-1', recurringInputFixture());
    session.container.read(authSessionProvider.notifier).markSignedOut();
    pending.complete();
    expect(await saving, isNull);
    expect(gateway.calls, isNot(contains('publish:new-tavolo')));
  });
}

({ProviderContainer container, FakeAuthGateway auth}) _readyContainer(
  FakeRecurringActivityGateway gateway,
) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      recurringActivityGatewayProvider.overrideWithValue(gateway),
      recurringActivityClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 9, 4, 10),
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return (container: container, auth: auth);
}
