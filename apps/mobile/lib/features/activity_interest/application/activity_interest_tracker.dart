import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../mock_mode/application/mock_mode_coordinator.dart';
import '../data/activity_interest_sink.dart';
import '../data/posthog_activity_interest_sink.dart';
import '../domain/activity_interest_event.dart';

/// Independent of Terms acceptance, login and Activities Split Mode.
abstract interface class ActivityInterestPermissionPolicy {
  bool get allowed;
}

final class DeniedActivityInterestPermission
    implements ActivityInterestPermissionPolicy {
  const DeniedActivityInterestPermission();
  @override
  bool get allowed => false;
}

final activityInterestPermissionProvider =
    Provider<ActivityInterestPermissionPolicy>(
      (ref) => const DeniedActivityInterestPermission(),
    );

final class ActivityInterestConfiguration {
  const ActivityInterestConfiguration({
    this.enabled = 'false',
    this.projectToken = '',
  });
  const ActivityInterestConfiguration.fromCompileTime()
    : enabled = const String.fromEnvironment(
        'ACTIVITY_INTEREST_ENABLED',
        defaultValue: 'false',
      ),
      projectToken = const String.fromEnvironment('POSTHOG_PROJECT_TOKEN');

  final String enabled;
  final String projectToken;
  bool get configured =>
      enabled == 'true' &&
      PostHogActivityInterestSink.validProjectToken(projectToken);
  ActivityInterestDelivery get readiness => switch (enabled) {
    'false' => ActivityInterestDelivery.disabled,
    'true' => PostHogActivityInterestSink(projectToken: projectToken).readiness,
    _ => ActivityInterestDelivery.invalidConfiguration,
  };
}

final activityInterestConfigurationProvider =
    Provider<ActivityInterestConfiguration>(
      (ref) => const ActivityInterestConfiguration.fromCompileTime(),
    );

final activityInterestSinkFactoryProvider =
    Provider<ActivityInterestSink Function()>((ref) {
      final config = ref.watch(activityInterestConfigurationProvider);
      return () => config.enabled == 'true'
          ? PostHogActivityInterestSink(projectToken: config.projectToken)
          : const NoopActivityInterestSink();
    });

final activityInterestTrackerProvider = Provider<ActivityInterestTracker>((
  ref,
) {
  final config = ref.watch(activityInterestConfigurationProvider);
  final permission = ref.watch(activityInterestPermissionProvider);
  final sinkFactory = ref.watch(activityInterestSinkFactoryProvider);
  final mock = ref.watch(activeMockRealmProvider);
  final tracker = ActivityInterestTracker(
    isAllowed: () => !mock && config.configured && permission.allowed,
    sinkFactory: sinkFactory,
  );
  // The identity is observed only to discard work; it never enters an event.
  ref.listen(
    authSessionProvider.select((state) => (state.phase, state.identity?.id)),
    (_, _) => tracker.invalidate(),
  );
  ref.onDispose(tracker.dispose);
  return tracker;
});

/// Dispatches an optional event without exposing dependency failures to the UI.
void recordActivityInterest(
  WidgetRef ref,
  ActivityInterestEvent event, {
  bool Function()? isCurrent,
}) {
  try {
    if (ref.read(activeMockRealmProvider)) return;
    ref
        .read(activityInterestTrackerProvider)
        .record(event, isCurrent: isCurrent);
  } catch (_) {
    // Provider construction can fail before the tracker's own error boundary.
    // Dropping optional telemetry must preserve navigation/platform success.
  }
}

/// Records deliberate gesture events with bounded, best-effort dispatch.
///
/// Uses no observer, disk cache, retry or user identifier.
final class ActivityInterestTracker {
  ActivityInterestTracker({
    required this._isAllowed,
    required this._sinkFactory,
    DateTime Function()? now,
    this.deliveryTimeout = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now;

  final bool Function() _isAllowed;
  final ActivityInterestSink Function() _sinkFactory;
  final DateTime Function() _now;
  final Duration deliveryTimeout;
  ActivityInterestSink? _sink;
  final _recent = <String, DateTime>{};
  int _revision = 0;
  int _inFlight = 0;
  int _volume = 0;
  DateTime? _window;
  bool _disposed = false;
  ActivityInterestDelivery lastDelivery = ActivityInterestDelivery.disabled;

  void tavoloCardOpened(String id, {bool Function()? isCurrent}) {
    final item = PublicActivityInterestItem.tavolo(id);
    if (item == null) return;
    record(ActivityInterestEvent.cardOpened(item), isCurrent: isCurrent);
  }

  void record(ActivityInterestEvent event, {bool Function()? isCurrent}) {
    // Catch only at this explicit best-effort telemetry boundary. A broken
    // injected policy/sink must not throw into navigation or platform sharing.
    try {
      if (_disposed || !_isAllowed() || isCurrent?.call() == false) return;
      final sink = _sink ??= _sinkFactory();
      if (!sink.available) {
        lastDelivery = sink is PostHogActivityInterestSink
            ? sink.readiness
            : ActivityInterestDelivery.disabled;
        return;
      }
      final now = _now();
      if (_window == null ||
          now.difference(_window!) >= const Duration(minutes: 1)) {
        _window = now;
        _volume = 0;
      }
      if (_inFlight >= 8 || _volume >= 60) return;
      final recent = _recent[event.deduplicationKey];
      if (recent != null &&
          now.difference(recent) < const Duration(milliseconds: 500)) {
        return;
      }
      if (_recent.length >= 32) _recent.remove(_recent.keys.first);
      _recent[event.deduplicationKey] = now;
      _volume++;
      _inFlight++;
      final revision = _revision;
      unawaited(_deliver(sink, event, revision, isCurrent));
    } catch (_) {
      lastDelivery = ActivityInterestDelivery.failed;
    }
  }

  Future<void> _deliver(
    ActivityInterestSink sink,
    ActivityInterestEvent event,
    int revision,
    bool Function()? isCurrent,
  ) async {
    var expired = false;
    bool allowed() =>
        !expired &&
        !_disposed &&
        revision == _revision &&
        _isAllowed() &&
        isCurrent?.call() != false;
    try {
      // Move all sink work off the gesture callback, rechecking authorization.
      await Future<void>.value();
      if (!allowed()) return;
      final result = await sink
          .capture(event, isAllowed: allowed)
          .timeout(deliveryTimeout);
      if (revision == _revision && !_disposed) lastDelivery = result;
    } on TimeoutException {
      if (revision == _revision && !_disposed) {
        // Invalidate all old guards and close a future client's pending work.
        // Merely timing out a Future would not cancel an underlying SDK send.
        invalidate();
        lastDelivery = ActivityInterestDelivery.failed;
      }
    } catch (_) {
      if (revision == _revision && !_disposed) {
        lastDelivery = ActivityInterestDelivery.failed;
      }
    } finally {
      expired = true;
      if (revision == _revision) _inFlight--;
    }
  }

  void invalidate() {
    _revision++;
    _inFlight = 0;
    _recent.clear();
    // Volume bounds survive actor changes; toggling accounts cannot reset them.
    final sink = _sink;
    _sink = null;
    try {
      sink?.dispose();
    } catch (_) {
      lastDelivery = ActivityInterestDelivery.failed;
    }
  }

  void dispose() {
    _disposed = true;
    invalidate();
  }
}
