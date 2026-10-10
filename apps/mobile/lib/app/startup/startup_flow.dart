import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/application/return_destination.dart';

const tutorialCompletionKey = 'planets.startup.completedTutorialVersion';

/// Bump only when an approved tutorial should be offered again on this device.
/// Pages remain available for small test harnesses; production uses guided steps.
class TutorialRegistry {
  const TutorialRegistry({
    this.version = '1',
    this.pages = const [],
    this.steps = const [],
  });

  final String version;
  final List<WidgetBuilder> pages;
  final List<TutorialStep> steps;
  bool get isEmpty => pages.isEmpty && steps.isEmpty;
}

enum TutorialStep {
  introduction,
  home,
  projectCard,
  projectDetail,
  projectCreate,
  projectDrafts,
  projectGroupChatExample,
  messagesTabs,
  messagesScopes,
  homeResources,
  resources,
  farewell,
}

const productionTutorial = TutorialRegistry(
  version: 'interactive-2',
  steps: TutorialStep.values,
);

class StartupPreference {
  const StartupPreference({
    this.completedVersion,
    this.dismissedVersion,
    this.restoreFailed = false,
  });

  final String? completedVersion;
  final String? dismissedVersion;
  final bool restoreFailed;
}

abstract interface class StartupPreferenceStore {
  Future<String?> read();
  Future<void> complete(String version);
  Future<void> reset();
}

class SharedPreferencesStartupStore implements StartupPreferenceStore {
  SharedPreferencesStartupStore({this.preferences});

  final SharedPreferencesAsync? preferences;

  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _storage =>
      _preferences ??= preferences ?? SharedPreferencesAsync();

  @override
  Future<String?> read() => _storage.getString(tutorialCompletionKey);

  @override
  Future<void> complete(String version) =>
      _storage.setString(tutorialCompletionKey, version);

  @override
  Future<void> reset() => _storage.remove(tutorialCompletionKey);
}

Future<StartupPreference> restoreStartupPreference(
  StartupPreferenceStore store,
) async {
  try {
    final value = await store.read();
    // Legacy bare versions represent completion. Dismissal uses the same local
    // key, containing only status and version, never a destination or identity.
    return value != null && value.startsWith('dismissed:')
        ? StartupPreference(dismissedVersion: value.substring(10))
        : StartupPreference(completedVersion: value);
  } catch (_) {
    // The preference boundary reports failure separately from never completed.
    return const StartupPreference(restoreFailed: true);
  }
}

/// Installation preference and current-run entry policy, independent of Auth.
class StartupFlow extends ChangeNotifier {
  StartupFlow(this.store, this.registry, this.preference);

  final StartupPreferenceStore store;
  final TutorialRegistry registry;
  StartupPreference preference;
  bool hasEntered = false;
  bool tutorialDeferred = false;

  bool get needsTutorial =>
      !registry.isEmpty &&
      !tutorialDeferred &&
      (preference.restoreFailed ||
          (preference.completedVersion != registry.version &&
              preference.dismissedVersion != registry.version));

  // These run-only flags are read on the next router transition. They do not
  // rebuild routing configuration or discard an OTP/editor stack.
  void enter() => hasEntered = true;

  /// Explicit logout reopens Welcome without changing installation/tutorial state.
  void returnToWelcomeAfterSignOut() => hasEntered = false;

  void deferForExternalJourney() {
    enter();
    tutorialDeferred = true;
  }

  String continueTo(String destination) {
    enter();
    final safe = startupReturnDestination(destination);
    return needsTutorial
        ? Uri(path: '/intro', queryParameters: {'returnTo': safe}).toString()
        : safe;
  }

  String cancelTutorial(String destination) {
    deferForExternalJourney();
    return startupReturnDestination(destination);
  }

  Future<bool> retryRestore() async {
    preference = await restoreStartupPreference(store);
    notifyListeners();
    return !preference.restoreFailed;
  }

  Future<bool> finishTutorial() async {
    if (registry.isEmpty || preference.restoreFailed) return false;
    try {
      await store.complete(registry.version);
    } catch (_) {
      return false;
    }
    preference = StartupPreference(completedVersion: registry.version);
    notifyListeners();
    return true;
  }

  Future<bool> dismissTutorial() async {
    if (registry.isEmpty || preference.restoreFailed) return false;
    try {
      await store.complete('dismissed:${registry.version}');
    } catch (_) {
      return false;
    }
    preference = StartupPreference(dismissedVersion: registry.version);
    notifyListeners();
    return true;
  }

  /// Debug-only, targeted reset; Auth and all other preferences are untouched.
  Future<bool> resetForDevelopment() async {
    if (!kDebugMode) return false;
    try {
      await store.reset();
    } catch (_) {
      return false;
    }
    preference = const StartupPreference();
    hasEntered = false;
    tutorialDeferred = false;
    notifyListeners();
    return true;
  }
}

String startupReturnDestination(String? destination) {
  final safe = sanitizeReturnDestination(destination);
  final path = Uri.parse(safe).path;
  return path == '/welcome' || path == '/intro' ? '/' : safe;
}

final tutorialRegistryProvider = Provider<TutorialRegistry>(
  (ref) => productionTutorial,
);
final startupPreferenceStoreProvider = Provider<StartupPreferenceStore>(
  (ref) => SharedPreferencesStartupStore(),
  dependencies: const [],
);
final initialStartupPreferenceProvider = Provider<StartupPreference>(
  (ref) => const StartupPreference(),
  dependencies: const [],
);
final startupFlowProvider = Provider<StartupFlow>(
  (ref) {
    final flow = StartupFlow(
      ref.read(startupPreferenceStoreProvider),
      ref.read(tutorialRegistryProvider),
      ref.read(initialStartupPreferenceProvider),
    );
    ref.onDispose(flow.dispose);
    return flow;
  },
  dependencies: [
    startupPreferenceStoreProvider,
    initialStartupPreferenceProvider,
    tutorialRegistryProvider,
  ],
);
