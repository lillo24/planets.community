import '../domain/activity_interest_event.dart';
import 'activity_interest_sink.dart';

/// App-owned requirements for manual capture.
///
/// These are not fields claimed to exist in PostHog's SDK API. A future concrete
/// client must verify every requirement on Android and iOS.
final class ManualActivityInterestPostHogOptions {
  const ManualActivityInterestPostHogOptions(this.projectToken);
  final String projectToken;
  Uri get host => Uri.parse('https://eu.i.posthog.com');
  bool get autocapture => false;
  bool get lifecycleCapture => false;
  bool get screenCapture => false;
  bool get sessionReplay => false;
  bool get personProfiles => false;
  bool get identityEnrichment => false;
  bool get persistentIdentity => false;
  bool get persistentQueue => false;
  int get maxPendingEvents => 8;
  int get retries => 0;
}

/// Narrow platform seam for injected tests and a later privacy-verified SDK.
///
/// No production implementation is installed: posthog_flutter 5.56.0 cannot
/// disable native identity persistence through its public configuration.
abstract interface class ManualActivityInterestPostHogClient {
  bool get supportsMemoryOnlyManualCapture;
  Future<void> setup(ManualActivityInterestPostHogOptions options);
  Future<void> capture(String eventName, Map<String, Object> properties);
  void dispose();
}

final class PostHogActivityInterestSink implements ActivityInterestSink {
  PostHogActivityInterestSink({required this.projectToken, this._client});

  final String projectToken;
  final ManualActivityInterestPostHogClient? _client;
  Future<void>? _setup;
  bool _disposed = false;

  static bool validProjectToken(String value) =>
      RegExp(r'^phc_[A-Za-z0-9]{8,200}$').stringMatch(value) == value;

  ActivityInterestDelivery get readiness {
    if (_disposed) return ActivityInterestDelivery.disposed;
    if (!validProjectToken(projectToken)) {
      return ActivityInterestDelivery.invalidConfiguration;
    }
    if (_client?.supportsMemoryOnlyManualCapture != true) {
      return ActivityInterestDelivery.unsupportedSdkPrivacy;
    }
    return ActivityInterestDelivery.ready;
  }

  @override
  bool get available => readiness == ActivityInterestDelivery.ready;

  @override
  Future<ActivityInterestDelivery> capture(
    ActivityInterestEvent event, {
    required bool Function() isAllowed,
  }) async {
    if (!isAllowed()) return ActivityInterestDelivery.permissionDenied;
    if (!available) return readiness;
    try {
      _setup ??= _client!.setup(
        ManualActivityInterestPostHogOptions(projectToken),
      );
      await _setup;
      // Permission, actor, widget and timeout revisions can change during setup.
      if (_disposed) return ActivityInterestDelivery.disposed;
      if (!isAllowed()) return ActivityInterestDelivery.permissionDenied;
      await _client!.capture(event.name, event.properties);
      return ActivityInterestDelivery.captured;
    } catch (_) {
      // Explicit telemetry boundary: never log payloads or affect user actions.
      return ActivityInterestDelivery.failed;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client?.dispose();
  }
}
