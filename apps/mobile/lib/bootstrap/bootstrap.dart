import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/planets_app.dart';
import '../core/backend/supabase_backend.dart';
import '../core/config/app_config.dart';
import '../core/monitoring/app_monitoring.dart';
import '../features/settings/application/language_preference_controller.dart';
import '../features/settings/data/language_preference_store.dart';
import '../features/settings/domain/language_preference.dart';

typedef AppConfigLoader = AppConfig Function();
typedef BackendInitializer = Future<void> Function(AppConfig config);
typedef MonitoringLauncher = Future<void> Function(
  AppConfig config,
  AppRunner appRunner,
);
typedef ApplicationLauncher = void Function(Widget application);
typedef LanguagePreferenceLoader = Future<LanguagePreference> Function();

Future<LanguagePreference> loadLanguagePreference() =>
    restoreLanguagePreference(SharedPreferencesLanguagePreferenceStore());

Future<void> bootstrapApplication({
  AppConfigLoader configLoader = AppConfig.fromCompileTime,
  BackendInitializer backendInitializer = initializeSupabase,
  MonitoringLauncher monitoringLauncher = runWithOptionalMonitoring,
  ApplicationLauncher applicationLauncher = runApp,
  LanguagePreferenceLoader languagePreferenceLoader = loadLanguagePreference,
}) async {
  final config = configLoader();
  LanguagePreference languagePreference;
  try {
    languagePreference = await languagePreferenceLoader();
  } catch (_) {
    languagePreference = LanguagePreference.system;
  }
  await backendInitializer(config);
  await monitoringLauncher(
    config,
    () => applicationLauncher(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          initialLanguagePreferenceProvider.overrideWithValue(
            languagePreference,
          ),
        ],
        child: const PlanetsApp(),
      ),
    ),
  );
}
