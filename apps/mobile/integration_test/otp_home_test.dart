import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_command_controller.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/main.dart' as normal;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'isolated_pkce_storage.dart';

// Starts the NORMAL main.dart bootstrap signed out. No app gateway/provider
// override or pre-mounted app login: all ordinary OTPs enter through real UI.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('normal-main OTP, Home, profile, own history and suspension', (
    tester,
  ) async {
    final config = AppConfig.fromCompileTime();
    const mailpit = String.fromEnvironment('HISTORY_SMOKE_MAILPIT_URL');
    const emailA = String.fromEnvironment('HISTORY_SMOKE_EMAIL_A');
    const emailB = String.fromEnvironment('HISTORY_SMOKE_EMAIL_B');
    const emailNew = String.fromEnvironment('AUTHQA_NEW_EMAIL');
    const staffEmail = String.fromEnvironment('HISTORY_SMOKE_STAFF_EMAIL');
    const caseId = String.fromEnvironment('HISTORY_SMOKE_CASE_ID');
    if (config.environment != AppEnvironment.local ||
        config.monitoringEnabled ||
        ![
          '10.0.2.2',
          '127.0.0.1',
          'localhost',
        ].contains(config.supabaseUrl.host) ||
        config.supabaseUrl.port != 54511 ||
        ![
          '10.0.2.2',
          '127.0.0.1',
          'localhost',
        ].contains(Uri.parse(mailpit).host) ||
        ![
          emailA,
          emailB,
          emailNew,
          staffEmail,
        ].every((email) => email.endsWith('@planets.invalid')) ||
        caseId.isEmpty) {
      throw StateError(
        'Normal OTP smoke requires fresh AUTHQA01 loopback fixtures and monitoring disabled.',
      );
    }
    final staffStorage = IsolatedPkceStorage();
    final staff = SupabaseClient(
      config.supabaseUrl.toString(),
      config.supabasePublishableKey,
      authOptions: AuthClientOptions(pkceAsyncStorage: staffStorage),
    );
    String? notice;
    String? suspension;
    await normal.main();
    await _wait(
      tester,
      () => find.byType(PlanetsApp).evaluate().isNotEmpty,
      'normal main mounts',
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanetsApp)),
    );
    final router = container.read(appRouterProvider);
    final originalLanguage = container.read(languagePreferenceProvider);
    final trace = container.listen(authSessionProvider, (_, value) {
      // Safe state tags only: never session/OTP/email/reason dumps.
      debugPrint(
        'AUTHQA native session=${value.phase.name} command=${container.read(authCommandProvider).phase.name} failure=${container.read(authCommandProvider).failure?.name ?? 'none'}',
      );
    });
    final commandTrace = container.listen(authCommandProvider, (_, value) {
      debugPrint(
        'AUTHQA native command=${value.phase.name} failure=${value.failure?.name ?? 'none'} session=${container.read(authSessionProvider).phase.name}',
      );
    });
    final app = Supabase.instance.client;
    try {
      await _wait(
        tester,
        () => ![
          AuthSessionPhase.restoring,
          AuthSessionPhase.checkingAccount,
          AuthSessionPhase.checkingProfile,
        ].contains(container.read(authSessionProvider).phase),
        'initial session settles',
      );
      if (container.read(authSessionProvider).isAuthenticated) {
        // Restore a previously installed synthetic app using its actual sign-out UI.
        final statusSignOut = find.byKey(const Key('account-status-sign-out'));
        if (statusSignOut.evaluate().isNotEmpty) {
          await tester.tap(statusSignOut);
        } else {
          router.go('/');
          await tester.pump();
          await tester.tap(find.text('Sign out'));
        }
        await _wait(
          tester,
          () =>
              container.read(authSessionProvider).phase ==
              AuthSessionPhase.signedOut,
          'initial sign-out',
        );
      }
      await _language(tester, router, 'english');
      router.go('/');
      await tester.pump();
      await binding.convertFlutterSurfaceToImage();

      await _uiLogin(tester, emailA, mailpit);
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase ==
                AuthSessionPhase.ready &&
            !container.read(authCommandProvider).isBusy,
        'complete A settles',
      );
      await binding.takeScreenshot('authqa01-normal-home-en');
      expect(container.read(authCommandProvider).failure, isNull);
      expect(router.routerDelegate.state.uri.path, '/');
      expect(find.text("You're signed in."), findsOneWidget);
      expect(find.byKey(const Key('auth-safe-error')), findsNothing);
      final idA = app.auth.currentUser!.id;
      final profileA = await app
          .from('profiles')
          .select('id, display_name')
          .eq('id', idA)
          .single();
      expect(profileA['display_name'], isA<String>());
      debugPrint(
        'AUTHQA native complete-A canonical profile=complete Home=coherent',
      );

      await _language(tester, router, 'italian');
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-safe-error')), findsNothing);
      await binding.takeScreenshot('authqa01-normal-home-it');
      await _language(tester, router, 'english');

      // Focused own-history smoke, not the earlier full moderation campaign.
      await _staffLogin(staff, staffEmail, mailpit);
      notice = await staff.rpc<String>(
        'apply_moderation_consequence',
        params: {
          'p_expected_staff_profile_id': staff.auth.currentUser!.id,
          'p_case_id': caseId,
          'p_consequence_type': 'safety_notice',
          'p_user_reason': 'Synthetic AuthQA notice',
          'p_internal_note': 'Synthetic local fixture',
        },
      );
      router.go('/settings');
      await _wait(
        tester,
        () =>
            find.byKey(const Key('settings-notices-row')).evaluate().isNotEmpty,
        'ordinary Settings',
      );
      await tester.tap(find.byKey(const Key('settings-notices-row')));
      await _wait(
        tester,
        () => find.text('Synthetic AuthQA notice').evaluate().isNotEmpty,
        'A own history',
      );
      await tester.pageBack();
      await _wait(
        tester,
        () => router.routerDelegate.state.uri.path == '/settings',
        'history Back',
      );
      router.go('/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase ==
            AuthSessionPhase.signedOut,
        'A signed out',
      );

      router.go('/settings/notices');
      await tester.pumpAndSettle();
      await _uiLogin(tester, emailB, mailpit);
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase ==
                AuthSessionPhase.ready &&
            !container.read(authCommandProvider).isBusy,
        'B settles',
      );
      expect(app.auth.currentUser!.id, isNot(idA));
      expect(router.routerDelegate.state.uri.path, '/settings/notices');
      await _wait(
        tester,
        () => find.byKey(const Key('notices-empty')).evaluate().isNotEmpty,
        'B empty history',
      );
      expect(find.text('Synthetic AuthQA notice'), findsNothing);
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-safe-error')), findsNothing);
      await tester.tap(find.text('Sign out'));
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase ==
            AuthSessionPhase.signedOut,
        'B signed out',
      );
      debugPrint(
        'AUTHQA native A-to-B switch destination=/settings/notices history isolated',
      );

      await _uiLogin(tester, emailNew, mailpit);
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase ==
                AuthSessionPhase.profileSetupRequired &&
            !container.read(authCommandProvider).isBusy,
        'new C anchor',
      );
      expect(container.read(authSessionProvider).hasProfileAnchor, isTrue);
      expect(container.read(authCommandProvider).failure, isNull);
      final idNew = app.auth.currentUser!.id;
      final anchor = await app
          .from('profiles')
          .select('id, display_name')
          .eq('id', idNew)
          .single();
      expect(anchor['display_name'], isNull);
      await tester.tap(find.text('Complete profile'));
      await _wait(
        tester,
        () => find
            .byKey(const Key('profile-display-name-field'))
            .evaluate()
            .isNotEmpty,
        'C profile editor',
      );
      expect(router.routerDelegate.state.uri.path, '/profile/edit');
      await tester.enterText(
        find.byKey(const Key('profile-display-name-field')),
        'Synthetic AuthQA new',
      );
      await tester.tap(find.byKey(const Key('profile-save-button')));
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase == AuthSessionPhase.ready,
        'C canonical setup complete',
      );
      expect(
        (await app
            .from('profiles')
            .select('display_name')
            .eq('id', idNew)
            .single())['display_name'],
        'Synthetic AuthQA new',
      );
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.text("You're signed in."), findsOneWidget);
      expect(find.byKey(const Key('auth-safe-error')), findsNothing);
      await tester.tap(find.text('Sign out'));
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase ==
            AuthSessionPhase.signedOut,
        'C signed out',
      );
      debugPrint(
        'AUTHQA native new-C missing-to-incomplete-to-complete canonical profile passed',
      );

      suspension = await staff.rpc<String>(
        'apply_account_suspension',
        params: {
          'p_expected_staff_profile_id': staff.auth.currentUser!.id,
          'p_case_id': caseId,
          'p_user_reason': 'Synthetic AuthQA suspension',
          'p_internal_note': 'Synthetic local fixture',
        },
      );
      await _uiLogin(tester, emailA, mailpit);
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase ==
                AuthSessionPhase.suspended &&
            !container.read(authCommandProvider).isBusy,
        'suspended A OTP',
      );
      expect(router.routerDelegate.state.uri.path, '/account/suspended');
      for (final target in ['/settings', '/settings/notices']) {
        router.go(target);
        await tester.pumpAndSettle();
        expect(router.routerDelegate.state.uri.path, '/account/suspended');
        expect(find.byKey(const Key('settings-notices-row')), findsNothing);
        expect(find.text('Synthetic AuthQA notice'), findsNothing);
      }
      final status = await app.rpc(
        'get_own_account_suspension_status',
        params: {'p_expected_profile_id': idA},
      );
      expect((status as List).single['is_suspended'], isTrue);
      await staff.rpc(
        'revoke_account_suspension',
        params: {
          'p_expected_staff_profile_id': staff.auth.currentUser!.id,
          'p_consequence_id': suspension,
          'p_user_reason': 'Synthetic AuthQA restored',
          'p_internal_note': 'Synthetic local fixture',
        },
      );
      suspension = null;
      await tester.tap(find.byKey(const Key('account-status-check')));
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase == AuthSessionPhase.ready,
        'A status restoration',
      );
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.text("You're signed in."), findsOneWidget);
      expect(find.byKey(const Key('auth-safe-error')), findsNothing);
      debugPrint(
        'AUTHQA native suspension fail-closed and fresh restoration passed',
      );
      expect(tester.takeException(), isNull);
    } finally {
      trace.close();
      commandTrace.close();
      for (final entry in [
        ('revoke_moderation_consequence', notice),
        ('revoke_account_suspension', suspension),
      ]) {
        if (entry.$2 != null) {
          await staff.rpc(
            entry.$1,
            params: {
              'p_expected_staff_profile_id': staff.auth.currentUser!.id,
              'p_consequence_id': entry.$2,
              'p_user_reason': 'Synthetic AuthQA cleanup',
              'p_internal_note': 'Synthetic local fixture',
            },
          );
        }
      }
      await app.auth.signOut();
      await container
          .read(languagePreferenceProvider.notifier)
          .select(originalLanguage);
      await tester.pumpWidget(const SizedBox.shrink());
      await staff.dispose();
      staffStorage.clear();
    }
  });
}

Future<void> _language(
  WidgetTester tester,
  GoRouter router,
  String language,
) async {
  router.go('/settings');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('settings-language-row')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('language-$language-option')));
  await _wait(
    tester,
    () => router.routerDelegate.state.uri.path == '/settings',
    'language saved',
  );
}

Future<void> _uiLogin(WidgetTester tester, String email, String mailpit) async {
  if (find.byKey(const Key('auth-email-field')).evaluate().isEmpty) {
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
  }
  final mailbox = _Mailbox(mailpit);
  try {
    final ids = await mailbox.ids(email);
    await tester.enterText(find.byKey(const Key('auth-email-field')), email);
    await tester.tap(find.byKey(const Key('auth-request-button')));
    await _wait(
      tester,
      () => find.byKey(const Key('auth-code-field')).evaluate().isNotEmpty,
      'real OTP requested',
    );
    final token = await mailbox.freshOtp(email, ids);
    await tester.enterText(find.byKey(const Key('auth-code-field')), token);
    await tester.tap(find.byKey(const Key('auth-verify-button')));
    await tester.pump();
  } finally {
    mailbox.close();
  }
}

Future<void> _staffLogin(
  SupabaseClient client,
  String email,
  String mailpit,
) async {
  final mailbox = _Mailbox(mailpit);
  try {
    final ids = await mailbox.ids(email);
    await client.auth.signInWithOtp(email: email, shouldCreateUser: false);
    final token = await mailbox.freshOtp(email, ids);
    final response = await client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
    if (response.user == null || response.session == null) {
      throw StateError('Synthetic staff OTP has no session.');
    }
  } finally {
    mailbox.close();
  }
}

Future<void> _wait(
  WidgetTester tester,
  bool Function() ready,
  String step,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Normal OTP smoke timed out: $step.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

class _Mailbox {
  _Mailbox(this.url);
  final String url;
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  void close() => http.close(force: true);
  Future<Map<String, dynamic>> get(String path) async {
    final request = await http.getUrl(Uri.parse('$url$path'));
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Local OTP mailbox HTTP ${response.statusCode}.');
    }
    return jsonDecode(
      await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 15)),
    ) as Map<String, dynamic>;
  }

  Future<List<dynamic>> messages(String email) async =>
      (await get(
            '/api/v1/search?query=${Uri.encodeQueryComponent('to:$email')}&limit=20',
          ))['messages']
          as List;
  Future<Set<Object?>> ids(String email) async =>
      (await messages(email)).map<Object?>((m) => m['ID']).toSet();
  Future<String> freshOtp(String email, Set<Object?> before) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      final fresh = (await messages(email))
          .where((m) => !before.contains(m['ID']));
      if (fresh.isNotEmpty) {
        final m = await get(
          '/api/v1/message/${Uri.encodeComponent(fresh.first['ID'] as String)}',
        );
        final token = RegExp(r'(?:^|\D)(\d{6})(?:\D|$)')
            .firstMatch('${m['Text'] ?? ''} ${m['HTML'] ?? ''}')
            ?.group(1);
        if (token == null) {
          throw StateError('Synthetic OTP email contains no numeric code.');
        }
        return token;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('Synthetic OTP email delivery timed out.');
  }
}
