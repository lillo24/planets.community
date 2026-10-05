import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/backend/supabase_backend.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/moderation/application/own_consequence_controller.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Dedicated test entrypoint. No Driver extension or fixture privilege is added
// to lib/main.dart. Both app and staff use real synthetic OTP sessions, never a
// service-role key. Configuration comes from the task-owned host preparer.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real private history, refresh, account switch and suspension', (
    tester,
  ) async {
    final config = AppConfig.fromCompileTime();
    const mailpit = String.fromEnvironment('HISTORY_SMOKE_MAILPIT_URL');
    const emailA = String.fromEnvironment('HISTORY_SMOKE_EMAIL_A');
    const emailB = String.fromEnvironment('HISTORY_SMOKE_EMAIL_B');
    const staffEmail = String.fromEnvironment('HISTORY_SMOKE_STAFF_EMAIL');
    const caseId = String.fromEnvironment('HISTORY_SMOKE_CASE_ID');
    if (config.environment != AppEnvironment.local ||
        config.monitoringEnabled ||
        ![
          '10.0.2.2',
          '127.0.0.1',
          'localhost',
        ].contains(config.supabaseUrl.host) ||
        ![
          '10.0.2.2',
          '127.0.0.1',
          'localhost',
        ].contains(Uri.parse(mailpit).host) ||
        ![
          emailA,
          emailB,
          staffEmail,
        ].every((email) => email.endsWith('@planets.invalid')) ||
        caseId.isEmpty) {
      throw StateError(
        'Own-history smoke requires prepared disposable local fixtures and monitoring disabled.',
      );
    }
    final app = SupabaseClient(
      config.supabaseUrl.toString(),
      config.supabasePublishableKey,
    );
    final staff = SupabaseClient(
      config.supabaseUrl.toString(),
      config.supabasePublishableKey,
    );
    String? notice;
    String? suspension;
    const applyReason =
        'Synthetic Mobile notice <b>plain</b> https://example.invalid';
    const removeReason = 'Synthetic Mobile removal';
    try {
      await _login(staff, staffEmail, mailpit);
      await _login(app, emailA, mailpit);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(config),
            supabaseClientProvider.overrideWithValue(app),
            initialLanguagePreferenceProvider.overrideWithValue(
              LanguagePreference.english,
            ),
          ],
          child: const PlanetsApp(),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanetsApp)),
      );
      final router = container.read(appRouterProvider);
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase == AuthSessionPhase.ready,
        'verified ready session',
      );
      router.go('/settings');
      await _wait(
        tester,
        () =>
            find.byKey(const Key('settings-notices-row')).evaluate().isNotEmpty,
        'Settings notices entry',
      );
      await tester.tap(find.byKey(const Key('settings-notices-row')));
      await _wait(
        tester,
        () => find.byKey(const Key('notices-empty')).evaluate().isNotEmpty,
        'genuine own empty history',
      );
      notice = await staff.rpc<String>(
        'apply_moderation_consequence',
        params: {
          'p_expected_staff_profile_id': staff.auth.currentUser!.id,
          'p_case_id': caseId,
          'p_consequence_type': 'safety_notice',
          'p_user_reason': applyReason,
          'p_internal_note': 'Synthetic private Mobile note',
        },
      );
      await tester.tap(find.byKey(const Key('notices-refresh')));
      await _wait(
        tester,
        () => find.text(applyReason).evaluate().isNotEmpty,
        'real applied notice and verbatim plain reason',
      );
      expect(find.text('Active'), findsOneWidget);
      await staff.rpc(
        'revoke_moderation_consequence',
        params: {
          'p_expected_staff_profile_id': staff.auth.currentUser!.id,
          'p_consequence_id': notice,
          'p_user_reason': removeReason,
          'p_internal_note': 'Synthetic private Mobile removal note',
        },
      );
      notice = null;
      await tester.tap(find.byKey(const Key('notices-refresh')));
      await _wait(
        tester,
        () => find.text('Removed').evaluate().isNotEmpty,
        'refreshed canonical removed state',
      );
      expect(find.text('Active'), findsNothing);
      await tester.pageBack();
      await _wait(
        tester,
        () => router.routerDelegate.state.uri.path == '/settings',
        'Back returns to Settings',
      );
      await app.auth.signOut();
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase ==
            AuthSessionPhase.signedOut,
        'sign-out clears account',
      );
      expect(find.text(applyReason), findsNothing);
      await _login(app, emailB, mailpit);
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase == AuthSessionPhase.ready,
        'second verified account',
      );
      router.go('/settings/notices');
      await _wait(
        tester,
        () => find.byKey(const Key('notices-empty')).evaluate().isNotEmpty,
        'second account owns no notices',
      );
      expect(find.text(applyReason), findsNothing);
      await app.auth.signOut();
      await _login(app, emailA, mailpit);
      await _wait(
        tester,
        () =>
            container.read(authSessionProvider).phase == AuthSessionPhase.ready,
        'original account verified again',
      );
      router.go('/settings/notices');
      await _wait(
        tester,
        () => find.text(applyReason).evaluate().isNotEmpty,
        'original private history reloaded',
      );
      suspension = await staff.rpc<String>(
        'apply_account_suspension',
        params: {
          'p_expected_staff_profile_id': staff.auth.currentUser!.id,
          'p_case_id': caseId,
          'p_user_reason': 'Synthetic Mobile suspension',
          'p_internal_note': 'Synthetic private Mobile suspension note',
        },
      );
      await tester.tap(find.byKey(const Key('notices-refresh')));
      await _wait(
        tester,
        () =>
            router.routerDelegate.state.uri.path == '/account/suspended' &&
            find.byKey(const Key('account-status-check')).evaluate().isNotEmpty,
        'general history denial routes through narrow Auth status',
      );
      expect(find.text(applyReason), findsNothing);
      expect(find.byKey(const Key('settings-notices-row')), findsNothing);
      expect(find.byKey(const Key('account-status-sign-out')), findsOneWidget);
      expect(container.read(ownConsequenceProvider).items, isEmpty);
      await staff.rpc(
        'revoke_account_suspension',
        params: {
          'p_expected_staff_profile_id': staff.auth.currentUser!.id,
          'p_consequence_id': suspension,
          'p_user_reason': 'Synthetic Mobile access restored',
          'p_internal_note': 'Synthetic private Mobile restoration note',
        },
      );
      suspension = null;
      await tester.tap(find.byKey(const Key('account-status-check')));
      await _wait(
        tester,
        () =>
            router.routerDelegate.state.uri.path == '/settings/notices' &&
            find.text('Account suspension').evaluate().isNotEmpty,
        'Check status again restores private history with removed suspension',
      );
      expect(
        container
            .read(ownConsequenceProvider)
            .items
            .every((item) => !item.isActive),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    } finally {
      // Explicit cleanup failures remain failures; no success-shaped fallback.
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
              'p_user_reason': 'Synthetic smoke cleanup',
              'p_internal_note': 'Synthetic private smoke cleanup note',
            },
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await app.dispose();
      await staff.dispose();
    }
  });
}

Future<void> _wait(
  WidgetTester tester,
  bool Function() ready,
  String step,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Own-history smoke timed out: $step.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

Future<void> _login(SupabaseClient client, String email, String mailpit) async {
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  Future<Map<String, dynamic>> get(String path) async {
    final request = await http.getUrl(Uri.parse('$mailpit$path'));
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Local smoke mailbox HTTP ${response.statusCode}.');
    }
    return jsonDecode(
      await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 15)),
    ) as Map<String, dynamic>;
  }

  final query =
      '/api/v1/search?query=${Uri.encodeQueryComponent('to:$email')}&limit=20';
  try {
    final before = await get(query);
    final ids = (before['messages'] as List? ?? [])
        .map((message) => message['ID'])
        .toSet();
    await client.auth.signInWithOtp(email: email, shouldCreateUser: false);
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      final found = await get(query);
      final messages = found['messages'] as List? ?? [];
      final fresh = messages.where((message) => !ids.contains(message['ID']));
      if (fresh.isNotEmpty) {
        final message = await get(
          '/api/v1/message/${Uri.encodeComponent(fresh.first['ID'] as String)}',
        );
        final token = RegExp(r'(?:^|\D)(\d{6})(?:\D|$)')
            .firstMatch('${message['Text'] ?? ''} ${message['HTML'] ?? ''}')
            ?.group(1);
        if (token == null) {
          throw StateError('Synthetic smoke mailbox contains no OTP.');
        }
        final response = await client.auth.verifyOTP(
          email: email,
          token: token,
          type: OtpType.email,
        );
        if (response.user == null || response.session == null) {
          throw StateError('Synthetic smoke login has no verified session.');
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('Synthetic smoke OTP delivery timed out.');
  } finally {
    http.close(force: true);
  }
}
