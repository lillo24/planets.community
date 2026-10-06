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
import 'package:planets_mobile/features/resource_requests/application/resource_request_controllers.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/main.dart' as normal;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'isolated_pkce_storage.dart';

// Real normal main/OTP/forms; staff client only arranges synthetic consequences.
// No app provider override, injected session, remote target or production hook.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    '09C2B2 normal OTP, both request forms, own notices, retry and suspension',
    (tester) async {
      final config = AppConfig.fromCompileTime();
      const modint = bool.fromEnvironment('MODINT01_SMOKE');
      const mailbox = String.fromEnvironment('REQUEST_SMOKE_MAILPIT');
      const email = String.fromEnvironment('REQUEST_SMOKE_EMAIL');
      const unrelatedEmail = String.fromEnvironment(
        'REQUEST_SMOKE_UNRELATED_EMAIL',
      );
      const staffEmail = String.fromEnvironment('REQUEST_SMOKE_STAFF_EMAIL');
      const ownerEmail = String.fromEnvironment('REQUEST_SMOKE_OWNER_EMAIL');
      const caseId = String.fromEnvironment('REQUEST_SMOKE_CASE');
      const project = String.fromEnvironment('REQUEST_SMOKE_PROJECT');
      const listing = String.fromEnvironment('REQUEST_SMOKE_LISTING');
      const owner = String.fromEnvironment('REQUEST_SMOKE_OWNER');
      if (config.environment != AppEnvironment.local ||
          config.monitoringEnabled ||
          config.supabaseUrl.port != (modint ? 54611 : 54521) ||
          ![
            '10.0.2.2',
            '127.0.0.1',
            'localhost',
          ].contains(config.supabaseUrl.host) ||
          Uri.parse(mailbox).port != (modint ? 54614 : 54524) ||
          ![
            '10.0.2.2',
            '127.0.0.1',
            'localhost',
          ].contains(Uri.parse(mailbox).host) ||
          ![
            email,
            unrelatedEmail,
            staffEmail,
            ownerEmail,
          ].every((e) => e.endsWith('@planets.invalid')) ||
          [caseId, project, listing, owner].any((id) => id.isEmpty)) {
        throw StateError(
          'Native request smoke requires owned 09C2B2 loopback fixtures.',
        );
      }
      final storage = IsolatedPkceStorage();
      final staff = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        authOptions: AuthClientOptions(pkceAsyncStorage: storage),
      );
      final ownerStorage = IsolatedPkceStorage();
      final ownerClient = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        authOptions: AuthClientOptions(pkceAsyncStorage: ownerStorage),
      );
      String? blockedRequester;
      String? restriction;
      String? suspension;
      await normal.main();
      await _wait(
        tester,
        () => find.byType(PlanetsApp).evaluate().isNotEmpty,
        'normal main',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanetsApp)),
      );
      final router = container.read(appRouterProvider);
      final originalLanguage = container.read(languagePreferenceProvider);
      final app = Supabase.instance.client;
      Future<Object?> staffCommand(String name, Map<String, dynamic> params) =>
          _rpc(staff, name, {
            'p_expected_staff_profile_id': staff.auth.currentUser!.id,
            ...params,
          });
      Future<String> restrict() async =>
          (await staffCommand('apply_moderation_consequence', {
            'p_case_id': caseId,
            'p_consequence_type': 'interaction_restriction',
            'p_user_reason': 'Synthetic local request restriction.',
            'p_internal_note': 'Synthetic private fixture note',
          })) as String;
      Future<void> revokeRestriction() async {
        await staffCommand('revoke_moderation_consequence', {
          'p_consequence_id': restriction,
          'p_user_reason': 'Synthetic local removal.',
          'p_internal_note': 'Synthetic private fixture note',
        });
        restriction = null;
      }

      Future<void> revokeSuspension() async {
        await staffCommand('revoke_account_suspension', {
          'p_consequence_id': suspension,
          'p_user_reason': 'Synthetic local restoration.',
          'p_internal_note': 'Synthetic private fixture note',
        });
        suspension = null;
      }

      try {
        await _wait(
          tester,
          () => ![
            AuthSessionPhase.restoring,
            AuthSessionPhase.checkingAccount,
            AuthSessionPhase.checkingProfile,
          ].contains(container.read(authSessionProvider).phase),
          'initial session',
        );
        if (container.read(authSessionProvider).isAuthenticated) {
          final statusExit = find.byKey(const Key('account-status-sign-out'));
          if (statusExit.evaluate().isNotEmpty) {
            await tester.tap(statusExit);
          } else {
            await _signOut(tester, router);
          }
          await _wait(
            tester,
            () =>
                container.read(authSessionProvider).phase ==
                AuthSessionPhase.signedOut,
            'initial sign-out',
          );
        }
        await container
            .read(languagePreferenceProvider.notifier)
            .select(LanguagePreference.english);
        router.go('/');
        await tester.pumpAndSettle();
        await _uiLogin(tester, email, mailbox);
        await _wait(
          tester,
          () =>
              container.read(authSessionProvider).phase ==
                  AuthSessionPhase.ready &&
              !container.read(authCommandProvider).isBusy,
          'normal requester OTP',
        );
        expect(find.byKey(const Key('auth-safe-error')), findsNothing);
        await _staffLogin(staff, staffEmail, mailbox);
        await _staffLogin(ownerClient, ownerEmail, mailbox);
        await binding.convertFlutterSurfaceToImage();
        final requester = app.auth.currentUser!.id;

        Future<void> projectForm(String message) async {
          router.go('/proposals/$project/join');
          await _wait(
            tester,
            () => find
                .byKey(const Key('participation-message-field'))
                .evaluate()
                .isNotEmpty,
            'Project form',
          );
          await tester.enterText(
            find.byKey(const Key('participation-message-field')),
            message,
          );
          await tester.pumpAndSettle();
        }

        Future<void> resourceForm(String message) async {
          // Staff fixture changes occur outside this app. Explicitly refresh the
          // existing canonical requester cache before launching the real form;
          // the production status check is neither a poll nor an eligibility gate.
          final refreshed = await container
              .read(resourceRequestHistoryProvider.notifier)
              .load(app.auth.currentUser!.id, force: true);
          if (!refreshed) {
            throw StateError(
              'Native canonical Resource history refresh failed.',
            );
          }
          router.go('/resources/$listing');
          await _wait(
            tester,
            () => find
                .byKey(const Key('resource-request-action'))
                .evaluate()
                .isNotEmpty,
            'Resource detail',
          );
          await _tap(tester, 'resource-request-action');
          await tester.enterText(
            find.byKey(const Key('resource-request-message')),
            message,
          );
          await tester.pumpAndSettle();
        }

        Future<void> explanation(bool active) async {
          final error = find.byKey(
            const Key('own-request-restriction-explanation'),
          );
          if (active) {
            await _wait(
              tester,
              () => error.evaluate().isNotEmpty,
              'verified own explanation',
            );
          } else {
            await _wait(
              tester,
              () =>
                  find
                      .byKey(const Key('participation-join-error'))
                      .evaluate()
                      .isNotEmpty ||
                  find
                      .byKey(const Key('resource-request-composer-error'))
                      .evaluate()
                      .isNotEmpty,
              'generic denial',
            );
            await tester.pumpAndSettle();
            expect(error, findsNothing);
          }
          // Staff-written user reason stays in notices, never composer error copy.
          expect(
            find.text('Synthetic local request restriction.'),
            findsNothing,
          );
        }

        expect(
          await _rpc(app, 'get_own_interaction_restriction_status', {
            'p_expected_profile_id': requester,
          }),
          false,
        );
        await projectForm('Synthetic baseline Project request');
        await _tap(tester, 'participation-send-request');
        await _wait(
          tester,
          () => router.routerDelegate.state.uri.path == '/proposals/$project',
          'unrestricted Project success',
        );
        await resourceForm('Synthetic baseline Resource request');
        await _tap(tester, 'resource-request-submit');
        await _wait(
          tester,
          () => find
              .byKey(const Key('resource-request-message'))
              .evaluate()
              .isEmpty,
          'unrestricted Resource success',
        );
        final baselineProject = (await _rpc(
          app,
          'list_own_project_join_requests',
          {'p_expected_requester_profile_id': requester},
        )) as List;
        final baselineResource = (await _rpc(
          app,
          'list_own_resource_listing_requests',
          {'p_expected_requester_profile_id': requester},
        )) as List;
        expect(baselineProject, hasLength(1));
        expect(baselineResource, hasLength(1));

        restriction = await restrict();
        expect(
          await _rpc(app, 'get_own_interaction_restriction_status', {
            'p_expected_profile_id': requester,
          }),
          true,
        );
        await projectForm('Synthetic retained Project draft');
        await _tap(tester, 'participation-send-request');
        await explanation(true);
        await tester.ensureVisible(
          find.byKey(const Key('own-request-restriction-notices')),
        );
        await tester.pumpAndSettle();
        await binding.takeScreenshot('09c2b2-project-en');
        await container
            .read(languagePreferenceProvider.notifier)
            .select(LanguagePreference.italian);
        await tester.pumpAndSettle();
        await binding.takeScreenshot('09c2b2-project-it');
        await _tap(tester, 'own-request-restriction-notices');
        await _wait(
          tester,
          () => find
              .text('Synthetic local request restriction.')
              .evaluate()
              .isNotEmpty,
          'own notices',
        );
        // Tap the native Material control; pageBack's English tooltip lookup
        // does not find the localized Italian Back button.
        await tester.tap(find.byType(BackButton).hitTestable());
        await _wait(
          tester,
          () => find
              .byKey(const Key('participation-message-field'))
              .evaluate()
              .isNotEmpty,
          'Project notices Back',
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const Key('participation-message-field')),
              )
              .controller!
              .text,
          'Synthetic retained Project draft',
        );

        await resourceForm('Synthetic retained Resource draft');
        await _tap(tester, 'resource-request-submit');
        await explanation(true);
        await tester.ensureVisible(
          find.byKey(const Key('own-request-restriction-notices')),
        );
        await tester.pumpAndSettle();
        await binding.takeScreenshot('09c2b2-resource-it');
        await container
            .read(languagePreferenceProvider.notifier)
            .select(LanguagePreference.english);
        await tester.pumpAndSettle();
        await binding.takeScreenshot('09c2b2-resource-en');
        await _tap(tester, 'own-request-restriction-notices');
        await _wait(
          tester,
          () => find
              .text('Synthetic local request restriction.')
              .evaluate()
              .isNotEmpty,
          'Resource own notices',
        );
        expect(
          find.byKey(const Key('resource-request-message')).hitTestable(),
          findsNothing,
        );
        await tester.tap(find.byType(BackButton).hitTestable());
        await _wait(
          tester,
          () => find
              .byKey(const Key('resource-request-message'))
              .hitTestable()
              .evaluate()
              .isNotEmpty,
          'Resource modal Back',
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('resource-request-message')),
              )
              .controller!
              .text,
          'Synthetic retained Resource draft',
        );

        await revokeRestriction();
        final withdrawnProject = (await _rpc(
          app,
          'list_own_project_join_requests',
          {'p_expected_requester_profile_id': requester},
        )) as List;
        final withdrawnResource = (await _rpc(
          app,
          'list_own_resource_listing_requests',
          {'p_expected_requester_profile_id': requester},
        )) as List;
        expect(withdrawnProject.single['status'], 'withdrawn');
        expect(withdrawnResource.single['status'], 'withdrawn');
        await _tap(tester, 'resource-request-submit');
        await _wait(
          tester,
          () => find
              .byKey(const Key('resource-request-message'))
              .evaluate()
              .isEmpty,
          'explicit Resource retry',
        );
        await projectForm('Synthetic deliberate Project retry');
        await _tap(tester, 'participation-send-request');
        await _wait(
          tester,
          () => router.routerDelegate.state.uri.path == '/proposals/$project',
          'explicit Project retry',
        );
        for (final name in [
          'list_own_project_join_requests',
          'list_own_resource_listing_requests',
        ]) {
          final rows = (await _rpc(app, name, {
            'p_expected_requester_profile_id': requester,
          })) as List;
          expect(rows, hasLength(2));
          expect(rows.where((r) => r['status'] == 'pending'), hasLength(1));
          expect(rows.where((r) => r['status'] == 'withdrawn'), hasLength(1));
        }
        debugPrint(
          '09C2B2 native both canonical baselines, own explanations, notices/back and deliberate fresh episodes passed.',
        );

        // An inbound-only block keeps the applicant's UI direction-neutral.
        // The owner authenticates normally; no staff/service bypass is used.
        await _rpc(ownerClient, 'block_user', {
          'p_expected_blocker_profile_id': owner,
          'p_blocked_profile_id': requester,
        });
        blockedRequester = requester;
        for (final resource in [false, true]) {
          if (resource) {
            await resourceForm('Synthetic generic Resource denial');
          } else {
            await projectForm('Synthetic generic Project denial');
          }
          await _tap(
            tester,
            resource ? 'resource-request-submit' : 'participation-send-request',
          );
          await explanation(false);
          if (resource) {
            await tester.tap(find.text('Cancel'));
            await tester.pumpAndSettle();
          }
        }
        restriction = await restrict();
        for (final resource in [false, true]) {
          if (resource) {
            await resourceForm('Synthetic coexisting Resource denial');
          } else {
            await projectForm('Synthetic coexisting Project denial');
          }
          await _tap(
            tester,
            resource ? 'resource-request-submit' : 'participation-send-request',
          );
          await explanation(true);
          if (resource) {
            await tester.tap(find.text('Cancel'));
            await tester.pumpAndSettle();
          }
        }
        debugPrint(
          '09C2B2 native generic block denial and independently verified coexisting own restriction passed.',
        );

        await _signOut(tester, router);
        await _wait(
          tester,
          () =>
              container.read(authSessionProvider).phase ==
              AuthSessionPhase.signedOut,
          'requester sign-out',
        );
        await _uiLogin(tester, unrelatedEmail, mailbox);
        await _wait(
          tester,
          () =>
              container.read(authSessionProvider).phase ==
              AuthSessionPhase.ready,
          'unrelated OTP',
        );
        expect(
          await _rpc(app, 'get_own_interaction_restriction_status', {
            'p_expected_profile_id': app.auth.currentUser!.id,
          }),
          false,
        );
        final mismatch = await app
            .rpc(
              'get_own_interaction_restriction_status',
              params: {'p_expected_profile_id': requester},
            )
            .then<String?>(
              (_) => null,
              onError: (Object e) =>
                  e is PostgrestException ? e.code : 'unknown',
            );
        expect(mismatch, '42501');
        router.go('/settings/notices');
        await _wait(
          tester,
          () => find.byKey(const Key('notices-empty')).evaluate().isNotEmpty,
          'unrelated private notices',
        );
        expect(find.text('Synthetic local request restriction.'), findsNothing);
        await _signOut(tester, router);
        await _wait(
          tester,
          () =>
              container.read(authSessionProvider).phase ==
              AuthSessionPhase.signedOut,
          'unrelated sign-out',
        );
        await _uiLogin(tester, email, mailbox);
        await _wait(
          tester,
          () =>
              container.read(authSessionProvider).phase ==
              AuthSessionPhase.ready,
          'same-ID new session',
        );
        for (final resource in [false, true]) {
          if (resource) {
            await resourceForm('Synthetic suspension Resource draft');
          } else {
            await projectForm('Synthetic suspension Project draft');
          }
          suspension = (await staffCommand('apply_account_suspension', {
            'p_case_id': caseId,
            'p_user_reason': 'Synthetic local suspension.',
            'p_internal_note': 'Synthetic private fixture note',
          })) as String;
          await _tap(
            tester,
            resource ? 'resource-request-submit' : 'participation-send-request',
          );
          await _wait(
            tester,
            () =>
                container.read(authSessionProvider).phase ==
                AuthSessionPhase.suspended,
            'canonical suspension routing',
          );
          expect(router.routerDelegate.state.uri.path, '/account/suspended');
          expect(
            find.byKey(const Key('own-request-restriction-explanation')),
            findsNothing,
          );
          await revokeSuspension();
          await _tap(tester, 'account-status-check');
          await _wait(
            tester,
            () =>
                container.read(authSessionProvider).phase ==
                AuthSessionPhase.ready,
            'fresh access restoration',
          );
        }
        debugPrint(
          '09C2B2 native unrelated isolation, same-ID session and both PT403 Auth routes passed.',
        );
        expect(tester.takeException(), isNull);
      } finally {
        if (suspension != null) await revokeSuspension();
        if (restriction != null) await revokeRestriction();
        if (blockedRequester != null) {
          await _rpc(ownerClient, 'unblock_user', {
            'p_expected_blocker_profile_id': owner,
            'p_blocked_profile_id': blockedRequester,
          });
        }
        await app.auth.signOut();
        await container
            .read(languagePreferenceProvider.notifier)
            .select(originalLanguage);
        await tester.pumpWidget(const SizedBox.shrink());
        await staff.dispose();
        await ownerClient.dispose();
        storage.clear();
        ownerStorage.clear();
      }
    },
  );
}

Future<Object?> _rpc(
  SupabaseClient client,
  String name,
  Map<String, dynamic> params,
) async {
  try {
    return await client
        .rpc<Object?>(name, params: params)
        .timeout(const Duration(seconds: 15));
  } on PostgrestException catch (error) {
    throw StateError('Native canonical RPC $name failed (code ${error.code}).');
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _signOut(WidgetTester tester, GoRouter router) async {
  router.go('/settings');
  await tester.pumpAndSettle();
  // Reach the real lower action before ensureVisible; lazy Settings children
  // are not mounted outside the small phone's initial viewport.
  await tester.scrollUntilVisible(
    find.byKey(const Key('account-sign-out-button')),
    240,
    scrollable: find.byType(Scrollable),
    maxScrolls: 10,
  );
  await _tap(tester, 'account-sign-out-button');
}

Future<void> _wait(
  WidgetTester tester,
  bool Function() ready,
  String step,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Native request smoke timed out: $step.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

Future<void> _uiLogin(WidgetTester tester, String email, String url) async {
  if (find.byKey(const Key('auth-email-field')).evaluate().isEmpty) {
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
  }
  final mailbox = _Mailbox(url);
  try {
    final before = await mailbox.ids(email);
    await tester.enterText(find.byKey(const Key('auth-email-field')), email);
    await tester.tap(find.byKey(const Key('auth-request-button')));
    await _wait(
      tester,
      () => find.byKey(const Key('auth-code-field')).evaluate().isNotEmpty,
      'real OTP request',
    );
    final code = await mailbox.freshOtp(email, before);
    await tester.enterText(find.byKey(const Key('auth-code-field')), code);
    await tester.tap(find.byKey(const Key('auth-verify-button')));
    await tester.pump();
  } finally {
    mailbox.close();
  }
}

Future<void> _staffLogin(
  SupabaseClient client,
  String email,
  String url,
) async {
  final mailbox = _Mailbox(url);
  try {
    final before = await mailbox.ids(email);
    await client.auth.signInWithOtp(email: email, shouldCreateUser: false);
    final response = await client.auth.verifyOTP(
      email: email,
      token: await mailbox.freshOtp(email, before),
      type: OtpType.email,
    );
    if (response.user == null || response.session == null) {
      throw StateError('Synthetic staff OTP missing session.');
    }
  } finally {
    mailbox.close();
  }
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
      throw StateError('Local mailbox HTTP ${response.statusCode}.');
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
        final message = await get(
          '/api/v1/message/${Uri.encodeComponent(fresh.first['ID'] as String)}',
        );
        final code = RegExp(r'(?:^|\D)(\d{6})(?:\D|$)')
            .firstMatch('${message['Text'] ?? ''} ${message['HTML'] ?? ''}')
            ?.group(1);
        if (code == null) {
          throw StateError('Synthetic OTP has no numeric code.');
        }
        return code;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('Synthetic OTP delivery timed out.');
  }
}
