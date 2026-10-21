import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/activity_interest/application/activity_interest_tracker.dart';
import 'package:planets_mobile/features/activity_interest/data/activity_interest_sink.dart';
import 'package:planets_mobile/features/activity_interest/domain/activity_interest_event.dart';
import 'package:planets_mobile/features/activities_sandbox/data/activity_examples.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';

import '../../support/fake_activity_interest.dart';
import '../../support/fake_auth.dart';

const _id = 'fb040000-0000-4000-8000-000000000002';
final _item = PublicActivityInterestItem.tavolo(_id)!;
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('strict public vocabulary and immutable property allowlist', () {
    expect(activityExamples, hasLength(12));
    for (final example in activityExamples) {
      expect(PublicActivityInterestItem.tavolo(example.id), isNull);
    }
    for (final invalid in [
      '',
      'example-trail',
      'project-1',
      'A' * 43,
      'https://planets.community/tavoli/$_id',
      ' $_id',
      '$_id\n',
      '00000000-0000-0000-0000-000000000000',
      '$_id?token=secret',
    ]) {
      expect(PublicActivityInterestItem.tavolo(invalid), isNull);
    }
    final opened = ActivityInterestEvent.cardOpened(_item);
    expect(opened.name, 'activity_card_opened');
    expect(opened.properties, {
      'schema_version': 1,
      'item_kind': 'tavolo',
      'item_id': _id,
      'origin_surface': 'tavoli_list',
    });
    expect(() => opened.properties['email'] = 'secret', throwsUnsupportedError);
    for (final action in ActivityShareAction.values) {
      final shared = ActivityInterestEvent.publicShare(_item, action);
      expect(shared.name, 'activity_share_action');
      expect(
        shared.properties.keys,
        unorderedEquals([
          'schema_version',
          'item_kind',
          'item_id',
          'origin_surface',
          'action',
        ]),
      );
      expect(shared.properties['origin_surface'], 'tavolo_detail');
      expect(shared.properties['action'], action.value);
    }
  });

  test(
    'default policy/config denied, malformed config explicit, SDK blocked',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(activityInterestPermissionProvider).allowed,
        isFalse,
      );
      expect(
        const ActivityInterestConfiguration().readiness,
        ActivityInterestDelivery.disabled,
      );
      expect(
        const ActivityInterestConfiguration(enabled: 'yes').readiness,
        ActivityInterestDelivery.invalidConfiguration,
      );
      expect(
        const ActivityInterestConfiguration(enabled: 'true').readiness,
        ActivityInterestDelivery.invalidConfiguration,
      );
      expect(
        const ActivityInterestConfiguration(
          enabled: 'true',
          projectToken: 'phc_localtest1234',
        ).readiness,
        ActivityInterestDelivery.unsupportedSdkPrivacy,
      );
    },
  );

  test('denied gate never creates a sink or retains events', () async {
    var factoryCalls = 0;
    final tracker = ActivityInterestTracker(
      isAllowed: () => false,
      sinkFactory: () {
        factoryCalls++;
        return MemoryActivityInterestSink();
      },
    );
    addTearDown(tracker.dispose);
    for (var i = 0; i < 100; i++) {
      tracker.tavoloCardOpened(_id);
    }
    await _settle();
    expect(factoryCalls, 0);
  });

  test(
    'provider requires valid explicit configuration and independent permission',
    () async {
      for (final config in [
        const ActivityInterestConfiguration(),
        const ActivityInterestConfiguration(
          enabled: 'yes',
          projectToken: 'phc_localtest1234',
        ),
        const ActivityInterestConfiguration(enabled: 'true'),
        const ActivityInterestConfiguration(
          enabled: 'true',
          projectToken: 'phc_localtest1234\n',
        ),
        const ActivityInterestConfiguration(
          enabled: 'true',
          projectToken: 'phc_localtest1234',
        ),
      ]) {
        final auth = FakeAuthGateway();
        var factories = 0;
        final permission = FakeActivityInterestPermission()
          ..allowed = !config.configured;
        final container = ProviderContainer(
          overrides: [
            authGatewayProvider.overrideWithValue(auth),
            activityInterestConfigurationProvider.overrideWithValue(config),
            activityInterestPermissionProvider.overrideWithValue(permission),
            activityInterestSinkFactoryProvider.overrideWithValue(() {
              factories++;
              return MemoryActivityInterestSink();
            }),
          ],
        );
        container.read(activityInterestTrackerProvider).tavoloCardOpened(_id);
        await _settle();
        expect(factories, 0);
        container.dispose();
        await auth.close();
      }
    },
  );

  test(
    'gate revoked before dispatch or during a pending send drops work',
    () async {
      final permission = FakeActivityInterestPermission();
      final sink = MemoryActivityInterestSink();
      final tracker = memoryActivityInterestTracker(
        sink,
        permission: permission,
      );
      addTearDown(tracker.dispose);
      tracker.tavoloCardOpened(_id);
      permission.allowed = false;
      await _settle();
      expect(sink.calls, 0);
      permission.allowed = true;
      final delayed = Completer<void>();
      sink.delay = delayed.future;
      tracker.record(
        ActivityInterestEvent.publicShare(
          _item,
          ActivityShareAction.linkCopied,
        ),
      );
      await _settle();
      permission.allowed = false;
      delayed.complete();
      await _settle();
      expect(sink.events, isEmpty);
    },
  );

  test(
    'duplicates coalesce for 500ms; separate actions and later taps count',
    () async {
      var now = DateTime.utc(2026);
      final sink = MemoryActivityInterestSink();
      final tracker = ActivityInterestTracker(
        isAllowed: () => true,
        sinkFactory: () => sink,
        now: () => now,
      );
      addTearDown(tracker.dispose);
      tracker.tavoloCardOpened(_id);
      tracker.tavoloCardOpened(_id);
      tracker.record(
        ActivityInterestEvent.publicShare(
          _item,
          ActivityShareAction.linkCopied,
        ),
      );
      tracker.record(
        ActivityInterestEvent.publicShare(
          _item,
          ActivityShareAction.shareSheetInvoked,
        ),
      );
      await _settle();
      expect(sink.events, hasLength(3));
      now = now.add(const Duration(milliseconds: 500));
      tracker.tavoloCardOpened(_id);
      await _settle();
      expect(sink.events, hasLength(4));
    },
  );

  test(
    'source invalidation, actor revision and disposal discard late work',
    () async {
      final delayed = Completer<void>();
      final sink = MemoryActivityInterestSink()..delay = delayed.future;
      final tracker = memoryActivityInterestTracker(sink);
      var current = true;
      tracker.tavoloCardOpened(_id, isCurrent: () => current);
      await _settle();
      current = false;
      tracker.record(
        ActivityInterestEvent.publicShare(
          _item,
          ActivityShareAction.linkCopied,
        ),
      );
      tracker.invalidate();
      delayed.complete();
      await _settle();
      expect(sink.events, isEmpty);
      tracker.dispose();
      tracker.tavoloCardOpened(_id);
      await _settle();
      expect(sink.events, isEmpty);
    },
  );

  test('bounded in-flight work, 60/minute cap, no offline replay', () async {
    var now = DateTime.utc(2026);
    final delayed = Completer<void>();
    final sink = MemoryActivityInterestSink()..delay = delayed.future;
    final tracker = ActivityInterestTracker(
      isAllowed: () => true,
      sinkFactory: () => sink,
      now: () => now,
    );
    addTearDown(tracker.dispose);
    for (var i = 0; i < 100; i++) {
      tracker.tavoloCardOpened(
        'fb040000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
      );
    }
    await _settle();
    expect(sink.calls, 8);
    delayed.complete();
    await _settle();
    expect(sink.events, hasLength(8));
    sink.delay = null;
    for (var i = 0; i < 80; i++) {
      now = now.add(const Duration(milliseconds: 500));
      tracker.tavoloCardOpened(_id);
      await _settle();
    }
    expect(sink.events, hasLength(60));
    now = now.add(const Duration(minutes: 1));
    tracker.tavoloCardOpened(_id);
    await _settle();
    expect(sink.events, hasLength(61));
  });

  test(
    'failures, throwing policy and timeouts never escape the gesture',
    () async {
      final sink = MemoryActivityInterestSink()
        ..failure = StateError('offline');
      final tracker = memoryActivityInterestTracker(sink);
      addTearDown(tracker.dispose);
      expect(() => tracker.tavoloCardOpened(_id), returnsNormally);
      await _settle();
      expect(tracker.lastDelivery, ActivityInterestDelivery.failed);
      final broken = ActivityInterestTracker(
        isAllowed: () => throw StateError('policy'),
        sinkFactory: () => sink,
      );
      addTearDown(broken.dispose);
      expect(() => broken.tavoloCardOpened(_id), returnsNormally);
      final delayed = Completer<void>();
      final slowSink = MemoryActivityInterestSink()..delay = delayed.future;
      final slow = ActivityInterestTracker(
        isAllowed: () => true,
        sinkFactory: () => slowSink,
        deliveryTimeout: const Duration(milliseconds: 1),
      );
      addTearDown(slow.dispose);
      slow.tavoloCardOpened(_id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      delayed.complete();
      await _settle();
      expect(slow.lastDelivery, ActivityInterestDelivery.failed);
      expect(slowSink.events, isEmpty);
    },
  );

  test('guest to account changes invalidate pending events without identity payload', () async {
    final auth = FakeAuthGateway(snapshot: const AuthSnapshot());
    addTearDown(auth.close);
    final permission = FakeActivityInterestPermission();
    final pending = Completer<void>();
    final sink = MemoryActivityInterestSink()..delay = pending.future;
    final container = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        activityInterestPermissionProvider.overrideWithValue(permission),
        activityInterestSinkFactoryProvider.overrideWithValue(() => sink),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway(),
        ),
        activityInterestConfigurationProvider.overrideWithValue(
          const ActivityInterestConfiguration(
            enabled: 'true',
            projectToken: 'phc_localtest1234',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final tracker = container.read(activityInterestTrackerProvider);
    await container.read(authSessionProvider.notifier).start();
    tracker.tavoloCardOpened(_id);
    await _settle();
    expect(sink.calls, 1);
    auth.emit(
      const AuthSnapshot(identity: AuthIdentity(id: 'account-private')),
    );
    await _settle();
    pending.complete();
    await _settle();
    expect(sink.events, isEmpty);
    expect(sink.disposals, greaterThan(0));
    sink.delay = null;
    tracker.tavoloCardOpened(_id);
    await _settle();
    expect(
      sink.events.single.properties.values,
      isNot(contains('account-private')),
    );
    auth.emit(const AuthSnapshot());
    await _settle();
    tracker.record(
      ActivityInterestEvent.publicShare(_item, ActivityShareAction.linkCopied),
    );
    await _settle();
    expect(sink.events, hasLength(2));
  });
}
