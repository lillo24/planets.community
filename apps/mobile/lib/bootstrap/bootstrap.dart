import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/planets_app.dart';
import '../core/backend/supabase_backend.dart';
import '../core/config/app_config.dart';
import '../core/monitoring/app_monitoring.dart';

typedef AppConfigLoader = AppConfig Function();
typedef BackendInitializer = Future<void> Function(AppConfig config);
typedef MonitoringLauncher = Future<void> Function(
  AppConfig config,
  AppRunner appRunner,
);
typedef ApplicationLauncher = void Function(Widget application);

Future<void> bootstrapApplication({
  AppConfigLoader configLoader = AppConfig.fromCompileTime,
  BackendInitializer backendInitializer = initializeSupabase,
  MonitoringLauncher monitoringLauncher = runWithOptionalMonitoring,
  ApplicationLauncher applicationLauncher = runApp,
}) async {
  final config = configLoader();
  await backendInitializer(config);
  await monitoringLauncher(
    config,
    () => applicationLauncher(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: const PlanetsApp(),
      ),
    ),
  );
}
