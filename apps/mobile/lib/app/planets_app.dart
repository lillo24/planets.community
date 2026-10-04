import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_session_controller.dart';
import '../features/settings/application/language_preference_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'router/app_router.dart';
import 'router/draft_departure_coordinator.dart';

class PlanetsApp extends ConsumerStatefulWidget {
  const PlanetsApp({super.key});

  @override
  ConsumerState<PlanetsApp> createState() => _PlanetsAppState();
}

class _PlanetsAppState extends ConsumerState<PlanetsApp> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      if (mounted) {
        await ref.read(authSessionProvider.notifier).start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final languagePreference = ref.watch(languagePreferenceProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: ref.watch(draftDepartureProvider).messengerKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: languagePreference.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
