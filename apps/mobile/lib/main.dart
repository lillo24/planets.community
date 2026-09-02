import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/startup_failure_app.dart';
import 'bootstrap/bootstrap.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await bootstrapApplication();
  } on AppConfigException {
    _launchFailure(StartupFailureKind.configuration);
  } catch (_) {
    _launchFailure(StartupFailureKind.backendInitialization);
  }
}

void _launchFailure(StartupFailureKind kind) {
  if (kDebugMode) {
    debugPrint('PLANETS startup failed (${kind.name}).');
  }
  runApp(StartupFailureApp(kind: kind));
}
