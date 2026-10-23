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
import 'package:planets_mobile/features/auth/application/auth_command_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/mock_mode/application/mock_mode_coordinator.dart';
import 'package:planets_mobile/features/mock_mode/presentation/mock_mode_routes.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_controllers.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:planets_mobile/features/geographic_discovery/application/budget_basemap_tiles.dart';
import 'package:planets_mobile/features/geographic_discovery/application/geographic_discovery_controller.dart';
import 'package:planets_mobile/features/geographic_discovery/data/map_provider_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/data/budget_basemap_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/basemap_tile.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/budget_tile_provider.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/public_point_map.dart';

// Explicit integration target only. No synthetic session/token/Auth gateway is
// compiled: ordinary OTP and the reviewed broker install real Auth sessions.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final steps = <String>[];
  var stage = 'unknown';
  var operation = 'bootstrap';
  final errors = <String>[];
  final originalReporter = reportTestException;
  reportTestException = (details, description) {
    // Flutter's release-mode details.toString() omits assertion context. Keep a
    // bounded, redacted summary from this synthetic fixture, never a raw log.
    var summary = details
        .exceptionAsString()
        .replaceAll(
          RegExp(
            r'sb_(?:secret|publishable)_[A-Za-z0-9_-]+|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|Bearer\s+\S+',
          ),
          'redacted',
        )
        .replaceAll(RegExp(r'\b\d{6}\b'), 'redacted-code')
        .replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (summary.length > 280) summary = summary.substring(0, 280);
    if (errors.length < 4) errors.add('$operation $summary');
    originalReporter(details, description);
  };
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
        final location = RegExp(r'mock_realm_release_test\.dart:(\d+)')
            .firstMatch(failure.details ?? '');
        return wait == null
            ? 'native-assertion-line-${location?.group(1) ?? 'unknown'}'
            : wait.group(1)!;
      }).toList();
      await request('/qa/result', {
        'passed': passed,
        'stage': stage,
        'steps': steps,
        'failures': labels,
        'errors': errors,
      });
      qa.close(force: true);
    }),
  );
  testWidgets(
    'release guest entry, personas, interaction, restart, guest No, retained normal account and logout',
    (tester) async {
      expect(
        kReleaseMode,
        isTrue,
        reason: 'This gate must execute release-mode code.',
      );
      // IntegrationTest leaves the platform IME connected by default. Its
      // unregistered TestTextInput sends client -1, accepted only in debug.
      // Register the automation keyboard so release receives the real client
      // ID. This qualifies product text handling, not physical IME behavior.
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
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
        operation = 'navigate-${Uri.parse(destination).path}';
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
        await tester.tap(finder.hitTestable());
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> enterNativeText(Finder finder, String text) async {
        await tester.enterText(finder, text);
        await tester.pump(const Duration(milliseconds: 200));
        final editable = find.descendant(
          of: finder,
          matching: find.byType(EditableText),
          matchRoot: true,
        );
        expect(tester.widget<EditableText>(editable).controller.text, text);
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

      Future<void> sendChat(String body, String name) async {
        operation = 'send-chat-$name';
        final composer = find.byKey(const Key('project-chat-composer'));
        await enterNativeText(composer, body);
        // Let the real keyboard close before locating the send action at 2x.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 600));
        await tap(find.byKey(const Key('project-chat-send')));
        try {
          await wait(
            () =>
                tester.widget<TextField>(composer).controller!.text.isEmpty ||
                scope().read(projectChatDetailProvider).failure != null,
            'chat composer acknowledged $name',
          );
          final failure = scope().read(projectChatDetailProvider).failure;
          expect(failure, isNull, reason: 'Canonical send ${failure?.name}');
          await reveal(find.text(body));
        } catch (_) {
          await capture('chat-failure-$name');
          rethrow;
        }
      }

      Future<void> ready(String id) async {
        await wait(() {
          if (find.byType(PlanetsApp).evaluate().isEmpty) return false;
          final session = scope().read(authSessionProvider);
          return session.phase == AuthSessionPhase.ready &&
              session.identity?.id == id;
        }, 'ready ordinary identity');
      }

      Future<void> mapJourney(String name, {bool mock = true}) async {
        operation = 'public-basemap-$name';
        expect(scope().read(mapProviderGatewayProvider).centerEnabled, !mock);
        await navigate('/discover/map/projects');
        try {
          await wait(
            () =>
                find.byType(PublicPointMap).evaluate().isNotEmpty &&
                scope().read(budgetBasemapTilesProvider).count > 0,
            'map fixture pixels loaded',
          );
        } catch (_) {
          final current = scope();
          final geo = current.read(
            geographicDiscoveryProvider('map05:projects'),
          );
          final tiles = current.read(budgetBasemapTilesProvider);
          errors.add(
            'map path ${current.read(appRouterProvider).routerDelegate.state.uri.path} '
            'auth ${current.read(authSessionProvider).phase.name} '
            'geo ${geo.phase.name} items ${geo.items.length} '
            'canvas ${find.byType(PublicPointMap).evaluate().length} '
            'enabled ${tiles.enabled} sources ${tiles.count} '
            'mode ${current.read(mockModeCoordinatorProvider)?.phase.name}',
          );
          await capture('map-failure-$name-$stage');
          rethrow;
        }
        final canvas = tester.widget<PublicPointMap>(
          find.byType(PublicPointMap),
        );
        expect(canvas.tileProvider, isA<BudgetTileProvider>());
        final images = canvas.tileProvider! as BudgetTileProvider;
        if (mock) {
          await wait(
            () => scope()
                .read(geographicDiscoveryProvider('map05:projects'))
                .items
                .isNotEmpty,
            'mock geographic pins',
          );
          expect(
            scope()
                .read(geographicDiscoveryProvider('map05:projects'))
                .items
                .any((item) => item.title.contains('NORMAL ONLY')),
            isFalse,
          );
        }
        await tester.ensureVisible(find.byKey(const Key('public-point-map')));
        await tester.pump(const Duration(seconds: 1));
        final region = tester.getRect(
          find.byKey(const Key('public-point-map')),
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('native-mock-capture')),
        );
        final painted = await boundary.toImage(pixelRatio: 1);
        final rgba = await painted.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        // The existing radius overlay tints pixels at closer retained zooms.
        // Recognize that blend too, without resetting the user's camera.
        final tint = Color.alphaBlend(
          Theme.of(find.byType(PublicPointMap).evaluate().single)
              .colorScheme
              .primary
              .withValues(alpha: 0.08),
          const Color(0xffd2d2d2),
        ).toARGB32();
        final pixels = rgba!.buffer.asUint8List();
        bool matches(int offset, int color) =>
            (pixels[offset] - ((color >> 16) & 255)).abs() <= 1 &&
            (pixels[offset + 1] - ((color >> 8) & 255)).abs() <= 1 &&
            (pixels[offset + 2] - (color & 255)).abs() <= 1;
        var fixturePixels = 0;
        for (
          var y = region.top.ceil().clamp(0, painted.height).toInt();
          y < region.bottom.floor().clamp(0, painted.height);
          y++
        ) {
          for (
            var x = region.left.ceil().clamp(0, painted.width).toInt();
            x < region.right.floor().clamp(0, painted.width);
            x++
          ) {
            final offset = (y * painted.width + x) * 4;
            if (matches(offset, 0xffd2d2d2) || matches(offset, tint)) {
              fixturePixels++;
            }
          }
        }
        painted.dispose();
        expect(
          fixturePixels,
          greaterThan(200),
          reason:
              'Controlled provider PNG pixels must actually paint in the map',
        );
        await capture('map-fixture-$name-$stage');
        await tester.drag(
          find.byKey(const Key('public-point-map')),
          const Offset(-40, 20),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tap(find.byKey(const Key('map-zoom-in')));
        await navigate('/');
        await expectLater(
          images.scope.tile(const BasemapTileId(12, 2174, 1456)),
          throwsA(isA<BudgetBasemapFailure>()),
        );
        steps.add('map-fixture-$name-pins-pan-zoom-route-fence');
      }

      Future<void> profile(String name, {String tag = ""}) async {
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
          'profile-${name == 'NORMAL ONLY SENTINEL' ? 'normal' : name.toLowerCase()}-$stage${tag.isEmpty ? '' : '-$tag'}',
        );
      }

      Future<void> picker() async {
        await navigate('/');
        await tap(find.byKey(const Key('open-help-button')));
        await tap(find.byKey(const Key('help-mock-accounts-action')));
        await wait(
          () => find.byKey(const Key('mock-login-dario')).evaluate().isNotEmpty,
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
        await wait(
          () =>
              find.byType(PlanetsApp).evaluate().isNotEmpty &&
              !identical(scope(), old) &&
              scope().read(activeMockRealmProvider),
          'installed persona scope',
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
        await capture('home-$key-$stage');
        steps.add('persona-$key-home');
      }

      const normalId = String.fromEnvironment('MOCK_QA_NORMAL_ID');
      const giulia = '81000000-0000-4000-8000-000000000001';
      const marco = '81000000-0000-4000-8000-000000000002';
      const sara = '81000000-0000-4000-8000-000000000003';
      const chat = String.fromEnvironment('MOCK_QA_CHAT');
      DateTime? lastNormalOtp;
      Future<void> normalLogin() async {
        if (lastNormalOtp case final previous?) {
          final remaining =
              const Duration(seconds: 61) - DateTime.now().difference(previous);
          if (remaining > Duration.zero) await Future<void>.delayed(remaining);
        }
        await navigate('/auth/email?returnTo=%2Fsettings');
        operation = 'normal-email-field';
        await tap(find.byKey(const Key('auth-email-field')));
        operation = 'normal-email-input';
        await enterNativeText(
          find.byKey(const Key('auth-email-field')),
          'normal-sentinel@planets.invalid',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 600));
        operation = 'normal-request-code';
        lastNormalOtp = DateTime.now();
        await tap(find.byKey(const Key('auth-request-button')));
        operation = 'normal-await-code-form';
        await wait(() {
          final failure = scope().read(authCommandProvider).failure;
          if (failure != null) {
            fail('Native ordinary Auth failed ${failure.name}');
          }
          return find.byKey(const Key('auth-code-field')).evaluate().isNotEmpty;
        }, 'ordinary OTP requested');
        String? code;
        operation = 'normal-read-private-mailpit';
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
        operation = 'normal-code-input';
        await enterNativeText(find.byKey(const Key('auth-code-field')), code!);
        operation = 'normal-verify-code';
        await tap(find.byKey(const Key('auth-verify-button')));
        operation = 'normal-ready';
        await ready(normalId);
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
          () => find.byKey(const Key('mock-login-dario')).evaluate().isNotEmpty,
          'guest selector without normal login',
        );
        expect(find.byKey(const Key('auth-email-field')), findsNothing);
        expect(normalBackendRuntime.client.auth.currentSession, isNull);
        await tap(find.byKey(const Key('page-close')));
        expect(scope().read(activeMockRealmProvider), isFalse);
        expect(tester.widget<SegmentedButton<bool>>(setting).selected, {false});
        steps.add('guest-selector-cancel-keeps-no');
        await tap(find.descendant(of: setting, matching: find.text('Yes')));
        await wait(
          () => find.byKey(const Key('mock-login-dario')).evaluate().isNotEmpty,
          'guest selector',
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
        await mapJourney('giulia-en');
        await scope()
            .read(languagePreferenceProvider.notifier)
            .select(LanguagePreference.italian);
        await mapJourney('giulia-it');
        await scope()
            .read(languagePreferenceProvider.notifier)
            .select(LanguagePreference.english);
        expect(normalId, giulia, reason: 'Deliberate equal normal/mock UUID');
        for (final language in [
          LanguagePreference.english,
          LanguagePreference.italian,
        ]) {
          await scope()
              .read(languagePreferenceProvider.notifier)
              .select(language);
          for (final brightness in [Brightness.light, Brightness.dark]) {
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            await navigate('/settings');
            await reveal(setting);
            await capture(
              'settings-${language.name}-${brightness.name}-320-2x',
            );
            await navigate('/help');
            await reveal(find.byKey(const Key('help-mock-accounts-action')));
            await capture('help-${language.name}-${brightness.name}-320-2x');
            await navigate('/');
            await capture('home-${language.name}-${brightness.name}-320-2x');
          }
        }
        await scope()
            .read(languagePreferenceProvider.notifier)
            .select(LanguagePreference.english);
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
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
        await sendChat('Native mock hello from Giulia', 'giulia');
        await capture('giulia-message-committed');
        await picker();
        await asPerson('marco', marco);
        await mapJourney('marco-en');
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
        await sendChat('Native mock reply from Sara', 'sara');
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
        await wait(
          () =>
              find.byType(PlanetsApp).evaluate().isNotEmpty &&
              scope().read(authSessionProvider).phase ==
                  AuthSessionPhase.signedOut &&
              scope()
                      .read(appRouterProvider)
                      .routeInformationProvider
                      .value
                      .uri
                      .path ==
                  '/',
          'guest No returns guest Home',
        );
        expect(normalBackendRuntime.client.auth.currentSession, isNull);
        expect(scope().read(activeMockRealmProvider), isFalse);
        await capture('guest-no-home');
        steps.add('guest-no-returns-home-without-sign-in');
        await navigate('/help');
        expect(
          find.byKey(const Key('help-mock-accounts-action')),
          findsNothing,
        );
        await normalLogin();
        steps.add('normal-otp-real-auth');
        await mapJourney('normal-en', mock: false);
        await profile('NORMAL ONLY SENTINEL', tag: 'before-mock');
        await navigate('/settings');
        await reveal(setting);
        await tap(find.descendant(of: setting, matching: find.text('Yes')));
        await wait(
          () => find.byKey(const Key('mock-login-dario')).evaluate().isNotEmpty,
          'retained account selector',
        );
        await asPerson('dario', '81000000-0000-4000-8000-000000000004');
        await profile('Dario');
        await request('/qa/mode', {'mode': 'normal'});
        await navigate('/settings');
        await reveal(setting);
        await tap(find.descendant(of: setting, matching: find.text('No')));
        await ready(normalId);
        expect(scope().read(activeMockRealmProvider), isFalse);
        await mapJourney('normal-after-mock', mock: false);
        await profile('NORMAL ONLY SENTINEL', tag: 'after-mock');
        steps.add('return-normal-preserves-retained-account');
        await navigate('/settings');
        await reveal(setting);
        await tap(find.descendant(of: setting, matching: find.text('Yes')));
        await wait(
          () => find.byKey(const Key('mock-login-dario')).evaluate().isNotEmpty,
          'logout selector',
        );
        await asPerson('giulia', giulia);
        await navigate('/settings');
        await request('/qa/mode', {'mode': 'normal'});
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
        expect(normalBackendRuntime.client.auth.currentSession, isNull);
        expect(scope().read(activeMockRealmProvider), isFalse);
        await capture('logout-welcome');
        steps.add('explicit-logout-clears-both-sessions');
        // Only a previously retained real session can require normal login on No.
        await normalLogin();
        await navigate('/settings');
        await reveal(setting);
        await tap(find.descendant(of: setting, matching: find.text('Yes')));
        await wait(
          () => find.byKey(const Key('mock-login-dario')).evaluate().isNotEmpty,
          'expired normal selector',
        );
        await asPerson('elena', '81000000-0000-4000-8000-000000000005');
        expect((await request('/qa/expire-normal', {}))['expired'], isTrue);
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
          'expired retained normal login',
        );
        expect(scope().read(activeMockRealmProvider), isFalse);
        expect(normalBackendRuntime.client.auth.currentSession, isNull);
        await capture('expired-normal-sign-in');
        steps.add('expired-retained-account-returns-normal-sign-in');
      }
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
