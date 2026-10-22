import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/activity_interest/data/activity_interest_sink.dart';
import 'package:planets_mobile/features/activity_interest/data/posthog_activity_interest_sink.dart';
import 'package:planets_mobile/features/activity_interest/domain/activity_interest_event.dart';

final _event = ActivityInterestEvent.cardOpened(
  PublicActivityInterestItem.tavolo('fb040000-0000-4000-8000-000000000002')!,
);

void main() {
  test(
    'production adapter remains blocked even with project configuration',
    () async {
      final sink = PostHogActivityInterestSink(
        projectToken: 'phc_testproject1234',
      );
      expect(sink.available, isFalse);
      expect(
        await sink.capture(_event, isAllowed: () => true),
        ActivityInterestDelivery.unsupportedSdkPrivacy,
      );
    },
  );

  test(
    'denied or persistence-capable clients receive zero setup/capture calls',
    () async {
      for (final allowed in [false, true]) {
        final client = _FakeClient()..supportsMemoryOnlyManualCapture = false;
        final sink = PostHogActivityInterestSink(
          projectToken: 'phc_testproject1234',
          client: client,
        );
        await sink.capture(_event, isAllowed: () => allowed);
        expect(client.setups, 0);
        expect(client.events, isEmpty);
      }
    },
  );

  test(
    'injected verified client gets EU/manual-only requirements and allowlist',
    () async {
      final client = _FakeClient();
      final sink = PostHogActivityInterestSink(
        projectToken: 'phc_testproject1234',
        client: client,
      );
      expect(
        await sink.capture(_event, isAllowed: () => true),
        ActivityInterestDelivery.captured,
      );
      expect(client.options!.host.toString(), 'https://eu.i.posthog.com');
      final options = client.options!;
      expect([
        options.autocapture,
        options.lifecycleCapture,
        options.screenCapture,
        options.sessionReplay,
        options.personProfiles,
        options.identityEnrichment,
        options.persistentIdentity,
        options.persistentQueue,
      ], everyElement(isFalse));
      expect(options.maxPendingEvents, 8);
      expect(options.retries, 0);
      expect(client.events.single.$1, _event.name);
      expect(client.events.single.$2, _event.properties);
      await sink.capture(_event, isAllowed: () => true);
      expect(client.setups, 1);
    },
  );

  test(
    'revoke or dispose during setup prevents capture; failures are explicit',
    () async {
      for (final dispose in [false, true]) {
        final setup = Completer<void>();
        final client = _FakeClient()..delay = setup.future;
        final sink = PostHogActivityInterestSink(
          projectToken: 'phc_testproject1234',
          client: client,
        );
        var allowed = true;
        final pending = sink.capture(_event, isAllowed: () => allowed);
        if (dispose) {
          sink.dispose();
        } else {
          allowed = false;
        }
        setup.complete();
        expect(
          await pending,
          dispose
              ? ActivityInterestDelivery.disposed
              : ActivityInterestDelivery.permissionDenied,
        );
        expect(client.events, isEmpty);
      }
      final client = _FakeClient()..failure = StateError('native error');
      final sink = PostHogActivityInterestSink(
        projectToken: 'phc_testproject1234',
        client: client,
      );
      expect(
        await sink.capture(_event, isAllowed: () => true),
        ActivityInterestDelivery.failed,
      );
    },
  );
}

final class _FakeClient implements ManualActivityInterestPostHogClient {
  @override
  bool supportsMemoryOnlyManualCapture = true;
  int setups = 0;
  ManualActivityInterestPostHogOptions? options;
  Future<void>? delay;
  Object? failure;
  final events = <(String, Map<String, Object>)>[];
  @override
  Future<void> setup(ManualActivityInterestPostHogOptions options) async {
    setups++;
    this.options = options;
    if (delay case final delay?) await delay;
    if (failure case final failure?) throw failure;
  }

  @override
  Future<void> capture(String eventName, Map<String, Object> properties) async {
    events.add((eventName, properties));
  }

  @override
  void dispose() {}
}
