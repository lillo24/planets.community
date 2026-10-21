import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/bootstrap/bootstrap.dart';
import 'package:planets_mobile/core/backend/supabase_backend.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/mock_mode/application/mock_mode_coordinator.dart';
import 'package:planets_mobile/features/mock_mode/presentation/mock_mode_routes.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

// Explicit integration target only. No synthetic session/token/Auth gateway is
// compiled: ordinary OTP and the reviewed broker install real Auth sessions.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final steps = <String>[];
  var stage = 'unknown';
  final qa = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, Object>? value,
  ]) async {
    final req = await qa.openUrl(
      value == null ? 'GET' : 'POST',
      Uri.parse('http://127.0.0.1:57420$path'),
    );
    if (value != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(value));
    }
    final response = await req.close();
    if (response.statusCode != 200) {
      await response.drain<void>();
      if (path == '/qa/otp' && response.statusCode == 404) return {};
      throw StateError(
        'Native QA request failed: $path (${response.statusCode})',
      );
    }
    return jsonDecode(await utf8.decodeStream(response))
        as Map<String, dynamic>;
  }

  unawaited(
    binding.allTestsPassed.future.then((passed) async {
      final labels = binding.failureMethodsDetails.map((failure) {
        final wait = RegExp(r'Native wait failed: ([a-zA-Z0-9 _-]{2,70})')
            .firstMatch(failure.details ?? '');
        return wait == null
            ? 'native-assertion-or-framework-failure'
            : wait.group(1)!;
      }).toList();
      await request('/qa/result', {
        'passed': passed,
        'stage': stage,
        'steps': steps,
        'failures': labels,
      });
      qa.close(force: true);
    }),
  );
  testWidgets(
    'release two-realm ordinary login, three personas, interaction, restart and logout',
    (tester) async {
      expect(
        kReleaseMode,
        isTrue,
        reason: 'This gate must execute release-mode code.',
      );
      final config = AppConfig.fromCompileTime();
      expect(config.environment, AppEnvironment.local);
      expect(config.supabaseUrl.origin, 'http://127.0.0.1:57421');
      expect(config.mockEnvironment?.origin.origin, 'http://127.0.0.1:57422');
      expect(config.closedTestMockEnabled, isTrue);
      expect(config.demoToolsEnabled, isFalse);
      stage = (await request('/qa/stage'))['stage'] as String;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await bootstrapApplication(
        applicationLauncher: (app) {
          runApp(
            RepaintBoundary(key: const Key('native-mock-capture'), child: app),
          );
        },
      );
      ProviderContainer scope() => ProviderScope.containerOf(
        tester.element(find.byType(PlanetsApp)),
        listen: false,
      );
      Future<void> wait(bool Function() ready, String label) async {
        for (var i = 0; i < 600; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (ready()) return;
        }
        fail('Native wait failed: $label');
      }

      await wait(
        () => find.byType(PlanetsApp).evaluate().isNotEmpty,
        'product root',
      );
      Future<void> navigate(String destination) async {
        scope().read(appRouterProvider).go(destination);
        await tester.pump(const Duration(milliseconds: 800));
      }

      Future<void> reveal(Finder finder) async {
        for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
          final scroll = find.byType(Scrollable).last;
          await tester.drag(scroll, const Offset(0, -260));
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(finder, findsOneWidget);
        await tester.ensureVisible(finder);
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> tap(Finder finder) async {
        await reveal(finder);
        await tester.tap(finder);
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> capture(String name) async {
        await tester.pump(const Duration(milliseconds: 500));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('native-mock-capture')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final upload = await qa.postUrl(
          Uri.parse('http://127.0.0.1:57420/qa/png/$name.png'),
        );
        upload.headers.contentType = ContentType('image', 'png');
        upload.add(bytes!.buffer.asUint8List());
        final response = await upload.close();
        expect(response.statusCode, 200);
        await response.drain<void>();
      }

      Future<void> ready(String id) async {
        await wait(() {
          if (find.byType(PlanetsApp).evaluate().isEmpty) return false;
          final session = scope().read(authSessionProvider);
          return session.phase == AuthSessionPhase.ready &&
              session.identity?.id == id;
        }, 'ready ordinary identity');
      }

      Future<void> profile(String name) async {
        await navigate('/profile');
        await wait(
          () => find.text(name).evaluate().isNotEmpty,
          'actual profile $name',
        );
        expect(
          find.text('NORMAL ONLY SENTINEL'),
          name == 'NORMAL ONLY SENTINEL' ? findsOneWidget : findsNothing,
        );
        await capture(
          'profile-${name == 'NORMAL ONLY SENTINEL' ? 'normal' : name.toLowerCase()}-$stage',
        );
      }

      Future<void> picker() async {
        await navigate('/');
        await tap(find.byKey(const Key('open-help-button')));
        await tap(find.byKey(const Key('help-mock-accounts-action')));
        await wait(
          () =>
              find.byKey(const Key('mock-login-giulia')).evaluate().isNotEmpty,
          'authorized picker',
        );
      }

      Future<void> asPerson(String key, String id) async {
        final old = scope();
        final coordinator = old.read(mockModeCoordinatorProvider)!;
        final previousRevision = coordinator.scopeRevision;
        await tap(find.byKey(Key('mock-login-$key')));
        await wait(
          () =>
              coordinator.phase == MockModePhase.mock &&
              coordinator.active?.personaKey == key &&
              coordinator.scopeRevision > previousRevision,
          'committed realm generation',
        );
        await ready(id);
        expect(
          scope()
              .read(appRouterProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/',
        );
        expect(scope().read(activeMockRealmProvider), isTrue);
        expect(
          scope().read(supabaseClientProvider),
          isNot(same(normalBackendRuntime.client)),
        );
        expect(
          scope().read(appConfigProvider).supabaseUrl.origin,
          config.mockEnvironment!.origin.origin,
        );
        expect(() => old.read(appConfigProvider), throwsStateError);
        await request('/qa/mode', {'mode': 'mock'});
        steps.add('persona-$key-home');
      }

      const control = String.fromEnvironment('MOCK_QA_CONTROL_ID');
      const giulia = '81000000-0000-4000-8000-000000000001';
      const marco = '81000000-0000-4000-8000-000000000002';
      const sara = '81000000-0000-4000-8000-000000000003';
      const chat = String.fromEnvironment('MOCK_QA_CHAT');
      Future<void> normalLogin() async {
        await navigate('/auth/email?returnTo=%2Fsettings');
        await tap(find.byKey(const Key('auth-email-field')));
        await tester.enterText(
          find.byKey(const Key('auth-email-field')),
          'normal-sentinel@planets.invalid',
        );
        await tap(find.byKey(const Key('auth-request-button')));
        await wait(
          () => find.byKey(const Key('auth-code-field')).evaluate().isNotEmpty,
          'ordinary OTP requested',
        );
        String? code;
        for (var i = 0; i < 30 && code == null; i++) {
          code = (await request('/qa/otp'))['code'] as String?;
          if (code == null) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        }
        expect(
          code != null,
          isTrue,
          reason: 'Mailpit captured ordinary local OTP',
        );
        await tester.enterText(find.byKey(const Key('auth-code-field')), code!);
        await tap(find.byKey(const Key('auth-verify-button')));
        await ready(control);
      }

      if (stage == 'first') {
        await wait(
          () =>
              scope().read(authSessionProvider).phase ==
              AuthSessionPhase.signedOut,
          'fresh normal guest',
        );
        expect(scope().read(activeMockRealmProvider), isFalse);
        await navigate('/help');
        expect(
          find.byKey(const Key('help-mock-accounts-action')),
          findsNothing,
        );
        await navigate('/settings');
        final setting = find.byKey(const Key('mock-mode-setting'));
        await reveal(setting);
        expect(tester.widget<SegmentedButton<bool>>(setting).selected, {false});
        await tap(find.descendant(of: setting, matching: find.text('Yes')));
        await wait(
          () =>
              find.byKey(const Key('auth-close-button')).evaluate().isNotEmpty,
          'guest normal sign in',
        );
        await tap(find.byKey(const Key('auth-close-button')));
        expect(scope().read(activeMockRealmProvider), isFalse);
        steps.add('guest-enable-cancel-keeps-no');
        await normalLogin();
        steps.add('normal-otp-real-auth');
        await profile('NORMAL ONLY SENTINEL');
        await navigate('/settings');
        await reveal(setting);
        await tap(find.descendant(of: setting, matching: find.text('Yes')));
        await wait(
          () =>
              find.byKey(const Key('mock-login-giulia')).evaluate().isNotEmpty,
          'first selector',
        );
        for (final language in [
          LanguagePreference.english,
          LanguagePreference.italian,
        ]) {
          await scope()
              .read(languagePreferenceProvider.notifier)
              .select(language);
          for (final brightness in [Brightness.light, Brightness.dark]) {
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            await tester.pump(const Duration(milliseconds: 600));
            await capture('picker-${language.name}-${brightness.name}-320-2x');
          }
        }
        await scope()
            .read(languagePreferenceProvider.notifier)
            .select(LanguagePreference.english);
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        await asPerson('giulia', giulia);
        expect(control, giulia, reason: 'Deliberate equal normal/mock UUID');
        await profile('Giulia');
        await navigate(
          '/proposals/${const String.fromEnvironment('MOCK_QA_PROJECT')}',
        );
        await wait(
          () => find
              .text('Costruiamo le cassette per le erbe')
              .evaluate()
              .isNotEmpty,
          'mock Project detail',
        );
        steps.add('project-detail-and-media');
        await navigate(
          '/messages/chats/group-contact/${const String.fromEnvironment('MOCK_QA_GROUP_CONTACT')}',
        );
        await wait(
          () => find
              .text('Proponiamo un incontro per scegliere i materiali.')
              .evaluate()
              .isNotEmpty,
          'representative contact history',
        );
        steps.add('group-contact-canonical-history');
        await navigate('/messages/chats/$chat');
        await wait(
          () => find
              .byKey(const Key('project-chat-composer'))
              .evaluate()
              .isNotEmpty,
          'Giulia genuine chat',
        );
        await tester.enterText(
          find.byKey(const Key('project-chat-composer')),
          'Native mock hello from Giulia',
        );
        await tap(find.byKey(const Key('project-chat-send')));
        await wait(
          () =>
              find.text('Native mock hello from Giulia').evaluate().isNotEmpty,
          'message committed',
        );
        await capture('giulia-message-committed');
        await picker();
        await asPerson('marco', marco);
        await profile('Marco');
        await navigate(
          '/tavoli/${const String.fromEnvironment('MOCK_QA_TAVOLO')}',
        );
        await wait(
          () => find.text('Repair Café del sabato').evaluate().isNotEmpty,
          'mock Tavolo detail',
        );
        await navigate(
          '/resources/${const String.fromEnvironment('MOCK_QA_LISTING')}',
        );
        await wait(
          () => find.text('Vasi per nuove piante').evaluate().isNotEmpty,
          'mock Scambio detail',
        );
        steps.add('tavolo-scambio-detail-and-media');
        for (final route in [
          '/tavoli',
          '/resources',
          '/groups',
          '/messages',
          '/proposals/workshop',
        ]) {
          await navigate(route);
          steps.add(
            'marco-${route.substring(1).replaceAll('/', '-')}-native-route',
          );
        }
        await picker();
        await asPerson('sara', sara);
        await profile('Sara');
        await navigate('/messages/chats/$chat');
        await wait(
          () =>
              find.text('Native mock hello from Giulia').evaluate().isNotEmpty,
          'Sara reads Giulia message',
        );
        await tester.enterText(
          find.byKey(const Key('project-chat-composer')),
          'Native mock reply from Sara',
        );
        await tap(find.byKey(const Key('project-chat-send')));
        await wait(
          () => find.text('Native mock reply from Sara').evaluate().isNotEmpty,
          'Sara reply committed',
        );
        await capture('sara-cross-person-reply');
        steps.add('cross-person-chat-canonical');
        final garden = const String.fromEnvironment('MOCK_QA_GARDEN');
        await navigate('/messages/discussions/groups/$garden');
        await reveal(find.text('General'));
        await reveal(find.text('Progettiamo le cassette per le erbe'));
        steps.add('sara-group-general-ideas');
        await navigate(
          '/messages/chats/member-contact/${const String.fromEnvironment('MOCK_QA_MEMBER_CONTACT')}',
        );
        await wait(
          () => find
              .text('Porterò il disegno delle cassette.')
              .evaluate()
              .isNotEmpty,
          'member contact canonical history',
        );
        steps.add('member-contact-canonical-history');
        // Native link is presented as an external URI, never looked up in mock.
        scope()
            .read(appRouterProvider)
            .go(
              'https://planets.community/proposals/${const String.fromEnvironment('MOCK_QA_PROJECT')}',
            );
        await wait(
          () =>
              scope()
                  .read(appRouterProvider)
                  .routeInformationProvider
                  .value
                  .uri
                  .path ==
              MockModeRoutes.normalLink,
          'normal link boundary',
        );
        await capture('normal-link-boundary');
        steps.add('normal-link-does-not-resolve-in-mock');
        await navigate('/');
        steps.add('restart-checkpoint-sara');
      } else {
        expect(stage, 'restart');
        await ready(sara);
        expect(scope().read(activeMockRealmProvider), isTrue);
        expect(
          scope().read(mockModeCoordinatorProvider)?.active?.personaKey,
          'sara',
        );
        steps.add('process-restart-restores-sara');
        await profile('Sara');
        await request('/qa/mode', {'mode': 'normal'});
        await navigate('/settings');
        final setting = find.byKey(const Key('mock-mode-setting'));
        await reveal(setting);
        final no = AppLocalizations.of(tester.element(setting)).mockNo;
        await tap(find.descendant(of: setting, matching: find.text(no)));
        await ready(control);
        expect(scope().read(activeMockRealmProvider), isFalse);
        expect(
          scope().read(appConfigProvider).supabaseUrl.origin,
          config.supabaseUrl.origin,
        );
        await profile('NORMAL ONLY SENTINEL');
        steps.add('return-normal-preserves-control-login');
        await navigate('/help');
        expect(
          find.byKey(const Key('help-mock-accounts-action')),
          findsNothing,
        );
        await navigate('/settings');
        await tap(find.byKey(const Key('account-sign-out-button')));
        await wait(
          () =>
              find.byType(PlanetsApp).evaluate().isNotEmpty &&
              scope()
                      .read(appRouterProvider)
                      .routeInformationProvider
                      .value
                      .uri
                      .path ==
                  '/welcome',
          'full logout Welcome',
        );
        expect(normalBackendRuntime.client.auth.currentSession == null, isTrue);
        expect(scope().read(activeMockRealmProvider), isFalse);
        await capture('logout-welcome');
        steps.add('explicit-logout-clears-both-sessions');
        // A genuine Auth authority loss while mock is active must return to the
        // normal login screen rather than adopt a missing profile or mock guest.
        await normalLogin();
        await navigate('/settings');
        await reveal(setting);
        await tap(find.descendant(of: setting, matching: find.text('Yes')));
        await wait(
          () =>
              find.byKey(const Key('mock-login-giulia')).evaluate().isNotEmpty,
          'revocation selector',
        );
        await asPerson('dario', '81000000-0000-4000-8000-000000000004');
        expect((await request('/qa/expire-control', {}))['expired'], isTrue);
        await request('/qa/mode', {'mode': 'normal'});
        await navigate('/settings');
        await reveal(setting);
        await tap(find.descendant(of: setting, matching: find.text('No')));
        await wait(
          () =>
              find.byType(PlanetsApp).evaluate().isNotEmpty &&
              scope()
                      .read(appRouterProvider)
                      .routeInformationProvider
                      .value
                      .uri
                      .path ==
                  '/auth',
          'expired normal login',
        );
        expect(scope().read(activeMockRealmProvider), isFalse);
        expect(normalBackendRuntime.client.auth.currentSession == null, isTrue);
        await capture('expired-control-normal-sign-in');
        steps.add('revoked-control-returns-normal-sign-in');
      }
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
