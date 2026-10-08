import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/planets_app.dart';
import '../app/startup/startup_flow.dart';
import '../core/backend/supabase_backend.dart';
import '../core/config/app_config.dart';
import '../core/monitoring/app_monitoring.dart';
import '../features/settings/application/language_preference_controller.dart';
import '../features/settings/data/language_preference_store.dart';
import '../features/settings/domain/language_preference.dart';
import '../features/settings/application/navigation_preference_controller.dart';
import '../features/settings/data/navigation_preference_store.dart';
import '../features/settings/domain/navigation_preference.dart';

typedef AppConfigLoader = AppConfig Function();
typedef BackendInitializer = Future<void> Function(AppConfig config);
typedef MonitoringLauncher = Future<void> Function(
  AppConfig config,
  AppRunner appRunner,
);
typedef ApplicationLauncher = void Function(Widget application);
typedef LanguagePreferenceLoader = Future<LanguagePreference> Function();
typedef NavigationPreferenceLoader =
    Future<NavigationPreferenceState> Function();
typedef StartupPreferenceLoader = Future<StartupPreference> Function();

Future<StartupPreference> loadStartupPreference() =>
    restoreStartupPreference(SharedPreferencesStartupStore());

Future<LanguagePreference> loadLanguagePreference() =>
    restoreLanguagePreference(SharedPreferencesLanguagePreferenceStore());

Future<NavigationPreferenceState> loadNavigationPreference() =>
    restoreNavigationPreference(SharedPreferencesNavigationPreferenceStore());

Future<void> bootstrapApplication({
  AppConfigLoader configLoader = AppConfig.fromCompileTime,
  BackendInitializer backendInitializer = initializeSupabase,
  MonitoringLauncher monitoringLauncher = runWithOptionalMonitoring,
  ApplicationLauncher applicationLauncher = runApp,
  LanguagePreferenceLoader languagePreferenceLoader = loadLanguagePreference,
  NavigationPreferenceLoader navigationPreferenceLoader =
      loadNavigationPreference,
  StartupPreferenceLoader startupPreferenceLoader = loadStartupPreference,
}) async {
  final config = configLoader();
  LanguagePreference languagePreference;
  try {
    languagePreference = await languagePreferenceLoader();
  } catch (_) {
    languagePreference = LanguagePreference.system;
  }
  NavigationPreferenceState navigationPreference;
  try {
    navigationPreference = await navigationPreferenceLoader();
  } catch (_) {
    navigationPreference = const NavigationPreferenceState(restoreFailed: true);
  }
  await backendInitializer(config);
  StartupPreference startupPreference;
  try {
    startupPreference = await startupPreferenceLoader();
  } catch (_) {
    startupPreference = const StartupPreference(restoreFailed: true);
  }
  await monitoringLauncher(
    config,
    () => applicationLauncher(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          initialStartupPreferenceProvider.overrideWithValue(startupPreference),
          initialLanguagePreferenceProvider.overrideWithValue(
            languagePreference,
          ),
          initialNavigationPreferenceProvider.overrideWithValue(
            navigationPreference,
          ),
        ],
        child: const PlanetsApp(),
      ),
    ),
  );
}
