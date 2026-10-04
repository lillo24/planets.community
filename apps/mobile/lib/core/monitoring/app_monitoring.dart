import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_config.dart';
import 'invitation_telemetry_filter.dart';

typedef AppRunner = FutureOr<void> Function();
typedef SentryRunner = Future<void> Function({
  required String dsn,
  required AppRunner appRunner,
});

Future<void> runWithOptionalMonitoring(
  AppConfig config,
  AppRunner appRunner, {
  SentryRunner sentryRunner = _runWithSentry,
}) async {
  final dsn = config.sentryDsn;
  if (dsn == null) {
    await Future<void>.sync(appRunner);
    return;
  }

  var applicationStarted = false;
  Future<void> startApplicationOnce() async {
    if (applicationStarted) {
      return;
    }
    applicationStarted = true;
    await Future<void>.sync(appRunner);
  }

  try {
    await sentryRunner(dsn: dsn.toString(), appRunner: startApplicationOnce);
  } catch (_) {
    await startApplicationOnce();
  }
}

Future<void> _runWithSentry({
  required String dsn,
  required AppRunner appRunner,
}) async {
  await SentryFlutter.init((options) {
    options
      ..dsn = dsn
      ..sendDefaultPii = false
      ..tracesSampleRate = 0
      // The SDK's null profiling sample rate remains unchanged (disabled).
      ..enableAutoPerformanceTracing = false
      ..enableUserInteractionTracing = false
      ..attachScreenshot = false
      ..replay.sessionSampleRate = 0
      ..replay.onErrorSampleRate = 0
      ..captureFailedRequests = false
      ..captureNativeFailedRequests = false
      ..recordHttpBreadcrumbs = false;
    // Capability URLs can also appear inside encoded auth return destinations.
    options.beforeBreadcrumb = (breadcrumb, hint) =>
        containsInvitationSecret(breadcrumb?.toJson()) ? null : breadcrumb;
    options.beforeSend = (event, hint) =>
        containsInvitationSecret(event.toJson()) ||
            containsInvitationSecret(event.throwable?.toString())
        ? null
        : event;
  }, appRunner: appRunner);
}
