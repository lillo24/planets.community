import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/main.dart' as normal;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'native_ui_settle.dart';

// Follow-up to actual Android Back exiting the suspended Activity. Install over
// that same owned app without clearing data: normal main must restore the real
// persisted OTP session and freshly deny it. No admission or login is replayed.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'normal cold reopen after suspended Android Back remains denied',
    (tester) async {
      final config = AppConfig.fromCompileTime();
      const email = String.fromEnvironment('HISTORY_SMOKE_EMAIL_A');
      if (!const bool.fromEnvironment('MODINT01_SMOKE') ||
          config.environment != AppEnvironment.local ||
          config.monitoringEnabled ||
          config.supabaseUrl.port != 54611 ||
          ![
            '10.0.2.2',
            '127.0.0.1',
            'localhost',
          ].contains(config.supabaseUrl.host) ||
          !email.endsWith('@planets.invalid')) {
        throw StateError(
          'Suspended resume requires the owned MODINT01 fixture.',
        );
      }
      await normal.main();
      await _wait(tester, () => find.byType(PlanetsApp).evaluate().isNotEmpty);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanetsApp)),
      );
      final router = container.read(appRouterProvider);
      final originalLanguage = container.read(languagePreferenceProvider);
      final app = Supabase.instance.client;
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase ==
            AuthSessionPhase.suspended,
      );
      expect(app.auth.currentUser?.email, email);
      expect(router.routerDelegate.state.uri.path, '/account/suspended');
      final status = await app.rpc(
        'get_own_account_suspension_status',
        params: {'p_expected_profile_id': app.auth.currentUser!.id},
      );
      expect((status as List).single['is_suspended'], isTrue);
      await binding.convertFlutterSurfaceToImage();
      try {
        for (final language in [
          LanguagePreference.english,
          LanguagePreference.italian,
        ]) {
          await container
              .read(languagePreferenceProvider.notifier)
              .select(language);
          await settleNativeUi(tester);
          await binding.takeScreenshot(
            'modint01-back-resumed-suspension-${language.storageValue}',
          );
        }
        router.go('/messages');
        await settleNativeUi(tester);
        expect(router.routerDelegate.state.uri.path, '/account/suspended');
        expect(find.byKey(const Key('messages-inbox')), findsNothing);
        await tester.ensureVisible(
          find.byKey(const Key('account-status-sign-out')),
        );
        await tester.tap(find.byKey(const Key('account-status-sign-out')));
        await _wait(
          tester,
          () =>
              container.read(authSessionProvider).phase ==
              AuthSessionPhase.signedOut,
        );
        expect(tester.takeException(), isNull);
        debugPrint(
          'MODINT01 native actual Back exit, cold suspended restore and real sign-out passed.',
        );
      } finally {
        await container
            .read(languagePreferenceProvider.notifier)
            .select(originalLanguage);
      }
    },
  );
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError(
        'Suspended cold reopen did not reach its required state.',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}
