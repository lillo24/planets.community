import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/recurring_activities/application/recurring_activity_controllers.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/domain/recurring_activity_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_recurring_activity.dart';

void main() {
  late FakeRecurringActivityGateway g;
  late FakeAuthGateway auth;
  late ProviderContainer c;
  setUp(() {
    g = FakeRecurringActivityGateway();
    auth = FakeAuthGateway();
    c = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        recurringActivityGatewayProvider.overrideWithValue(g),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await auth.close();
  });
  test(
    '60 records use 7/15/20/20, retry same cursor and stop after 18',
    () async {
      final limits = <int>[];
      final cursors = <String?>[];
      final rows = List.generate(
        60,
        (i) => publicRecurringSummaryFixture(id: 'item-$i'),
      );
      bool fail = false;
      g.publicLoader =
          ({
            required int limit,
            required DateTime referenceTime,
            RecurringActivityCursor? cursor,
            String? locality,
          }) async {
            limits.add(limit);
            cursors.add(cursor?.id);
            if (fail) throw Exception('offline');
            final start = cursor == null
                ? 0
                : int.parse(cursor.id.split('-').last) + 1;
            return rows.skip(start).take(limit).toList();
          };
      final ctrl = c.read(publicRecurringActivitiesProvider.notifier);
      await ctrl.load();
      expect(c.read(publicRecurringActivitiesProvider).items, hasLength(7));
      fail = true;
      await ctrl.load(reset: false);
      expect(c.read(publicRecurringActivitiesProvider).items, hasLength(7));
      expect(c.read(publicRecurringActivitiesProvider).hasMore, isTrue);
      fail = false;
      await ctrl.retry();
      await ctrl.load(reset: false);
      await ctrl.load(reset: false);
      expect(limits, [7, 15, 15, 20, 20]);
      expect(cursors, [null, 'item-6', 'item-6', 'item-21', 'item-41']);
      expect(
        c.read(publicRecurringActivitiesProvider).items.map((e) => e.id),
        rows.map((e) => e.id),
      );
      expect(c.read(publicRecurringActivitiesProvider).hasMore, isFalse);
      await ctrl.load(reset: false);
      expect(limits, hasLength(5));
      await ctrl.load();
      expect(limits.last, 7);
      expect(cursors.last, isNull);
    },
  );
  test(
    'filter and refresh supersede pending pages; rapid loads coalesce',
    () async {
      final pending = Completer<List<PublicRecurringActivitySummary>>();
      final limits = <int>[];
      g.publicLoader =
          ({
            required int limit,
            required DateTime referenceTime,
            RecurringActivityCursor? cursor,
            String? locality,
          }) {
            limits.add(limit);
            if (cursor != null) return pending.future;
            return Future.value(
              List.generate(
                7,
                (i) => publicRecurringSummaryFixture(id: 'item-$i'),
              ),
            );
          };
      final ctrl = c.read(publicRecurringActivitiesProvider.notifier);
      await ctrl.load();
      final old = ctrl.load(reset: false);
      await ctrl.load(reset: false);
      expect(limits, [7, 15]);
      await ctrl.applyLocality('fresh');
      pending.complete([publicRecurringSummaryFixture(id: 'old-page')]);
      await old;
      expect(
        c
            .read(publicRecurringActivitiesProvider)
            .items
            .any((e) => e.id == 'old-page'),
        isFalse,
      );
      expect(limits, [7, 15, 7]);
    },
  );
  test(
    'overlapping records deduplicate without changing loaded order',
    () async {
      g.publicLoader =
          ({
            required int limit,
            required DateTime referenceTime,
            RecurringActivityCursor? cursor,
            String? locality,
          }) async => cursor == null
          ? List.generate(
              7,
              (i) => publicRecurringSummaryFixture(id: 'item-$i'),
            )
          : [
              publicRecurringSummaryFixture(id: 'item-6'),
              publicRecurringSummaryFixture(id: 'item-7'),
            ];
      final ctrl = c.read(publicRecurringActivitiesProvider.notifier);
      await ctrl.load();
      await ctrl.load(reset: false);
      expect(
        c.read(publicRecurringActivitiesProvider).items.map((e) => e.id),
        List.generate(8, (i) => 'item-$i'),
      );
    },
  );
  test(
    'identity reset rejects a late continuation and restarts at seven',
    () async {
      final pending = Completer<List<PublicRecurringActivitySummary>>();
      final limits = <int>[];
      g.publicLoader =
          ({
            required int limit,
            required DateTime referenceTime,
            RecurringActivityCursor? cursor,
            String? locality,
          }) {
            limits.add(limit);
            if (cursor != null) return pending.future;
            return Future.value(
              List.generate(
                7,
                (i) => publicRecurringSummaryFixture(id: 'item-$i'),
              ),
            );
          };
      final ctrl = c.read(publicRecurringActivitiesProvider.notifier);
      await ctrl.load();
      final old = ctrl.load(reset: false);
      c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'new-user'));
      await Future<void>.delayed(Duration.zero);
      pending.complete([publicRecurringSummaryFixture(id: 'stale-user')]);
      await old;
      expect(limits, [7, 15, 7]);
      expect(
        c
            .read(publicRecurringActivitiesProvider)
            .items
            .any((e) => e.id == 'stale-user'),
        isFalse,
      );
    },
  );
}
