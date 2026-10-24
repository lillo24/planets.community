import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/bootstrap/bootstrap.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

// Compiles against both the exact predecessor and A1. Product bootstrap, Auth,
// secure session storage, gateways, routing, policies and widgets are real.
// Only fictional emails and public local configuration enter this test target.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('A1 real native before/after personal conversation', (
    tester,
  ) async {
    final config = AppConfig.fromCompileTime();
    expect(config.environment, AppEnvironment.local);
    expect(config.supabaseUrl.host, '127.0.0.1');
    expect(config.supabaseUrl.port, 61321);
    const before = bool.fromEnvironment('A1_BEFORE');
    const aliceEmail = String.fromEnvironment('A1_ALICE_EMAIL'),
        marcoEmail = String.fromEnvironment('A1_MARCO_EMAIL'),
        alice = String.fromEnvironment('A1_ALICE_ID'),
        marco = String.fromEnvironment('A1_MARCO_ID'),
        resource = String.fromEnvironment('A1_RESOURCE_CHAT');
    expect(aliceEmail, endsWith('@planets.invalid'));
    expect(marcoEmail, endsWith('@planets.invalid'));
    await SharedPreferencesStartupStore().complete(productionTutorial.version);
    await bootstrapApplication();
    Future<void> until(
      bool Function() ready, {
      String reason = 'native state',
    }) async {
      final end = DateTime.now().add(const Duration(seconds: 45));
      while (!ready() && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(ready(), isTrue, reason: reason);
    }

    await until(
      () => find.byType(PlanetsApp, skipOffstage: false).evaluate().isNotEmpty,
    );
    ProviderContainer scope() => ProviderScope.containerOf(
      tester.element(find.byType(PlanetsApp, skipOffstage: false)),
      listen: false,
    );
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    addTearDown(http.close);
    Future<Map<String, dynamic>> json(String url) async {
      final response = await (await http.getUrl(Uri.parse(url))).close();
      expect(response.statusCode, 200);
      return (jsonDecode(await utf8.decodeStream(response)) as Map)
          .cast<String, dynamic>();
    }

    Future<void> signIn(String email, String id) async {
      final search =
          'http://127.0.0.1:61324/api/v1/search?query=${Uri.encodeQueryComponent('to:$email')}&limit=20';
      final prior = ((await json(search))['messages'] as List)
          .map((m) => m['ID'])
          .toSet();
      await scope().read(authGatewayProvider).requestEmailOtp(email);
      String? messageId;
      for (var n = 0; n < 100 && messageId == null; n++) {
        final messages = (await json(search))['messages'] as List;
        for (final message in messages) {
          if (!prior.contains(message['ID'])) {
            messageId = message['ID'] as String;
            break;
          }
        }
        if (messageId == null) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      expect(messageId, isNotNull, reason: 'real local OTP delivery');
      final message = await json(
        'http://127.0.0.1:61324/api/v1/message/$messageId',
      );
      final code = RegExp(r'(?:^|\D)(\d{6})(?:\D|$)')
          .firstMatch('${message['Text']} ${message['HTML']}')
          ?.group(1);
      expect(code, isNotNull);
      await scope()
          .read(authGatewayProvider)
          .verifyEmailOtp(email: email, token: code!);
      await until(
        () =>
            scope().read(authSessionProvider).phase == AuthSessionPhase.ready &&
            scope().read(authSessionProvider).identity?.id == id,
        reason: 'real restored identity',
      );
      scope().read(startupFlowProvider).deferForExternalJourney();
    }

    Future<void> route(String path) async {
      scope().read(appRouterProvider).go(path);
      await tester.pump(const Duration(seconds: 2));
    }

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot(name, {'fictional': true, 'before': before});
      expect(tester.takeException(), isNull);
    }

    await signIn(aliceEmail, alice);
    expect(
      await scope()
          .read(languagePreferenceProvider.notifier)
          .select(LanguagePreference.italian),
      isTrue,
    );
    await route('/messages');
    await binding.convertFlutterSurfaceToImage();
    if (before) {
      await until(
        () => find.text('Marco').evaluate().length >= 2,
        reason: 'real predecessor separate personal rows',
      );
      await capture('before-it-dark-private');
    } else {
      await until(
        () =>
            find.byKey(ValueKey('private-pair-$marco')).evaluate().length == 1,
        reason: 'one canonical private row',
      );
      expect(find.text('Marco'), findsOneWidget);
      await capture('after-it-dark-private');
      await route('/messages/chats/resource/$resource');
      await until(
        () => find
            .byKey(const Key('private-pair-composer'))
            .evaluate()
            .isNotEmpty,
      );
      expect(find.byKey(const Key('private-pair-composer')), findsOneWidget);
      await capture('after-it-dark-thread');
      await route('/messages/chats/resource/$resource/manage');
      await until(
        () => find
            .byKey(const Key('resource-exchange-primary-action'))
            .evaluate()
            .isNotEmpty,
        reason: 'retained Resource agreement management',
      );
      expect(find.byKey(const Key('resource-chat-composer')), findsNothing);
      expect(find.byKey(const Key('private-pair-composer')), findsNothing);
      await route('/messages/chats/resource/$resource');
      await until(
        () => find
            .byKey(const Key('private-pair-composer'))
            .evaluate()
            .isNotEmpty,
      );
      final input = find.byKey(const Key('private-pair-composer'));
      await tester.tap(input);
      await tester.enterText(input, 'Ci vediamo sabato alle 10.');
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      await tester.pump(const Duration(seconds: 1));
      await capture('after-it-dark-keyboard');
      // The host now changes real Android night mode, then display/font settings
      // at explicit checkpoints. No fake Flutter theme or surface is injected.
      await until(
        () => tester.platformDispatcher.platformBrightness == Brightness.light,
        reason: 'actual Android light mode',
      );
      await tester.tap(find.byKey(const Key('private-pair-send')));
      await until(
        () =>
            find
                .byKey(const Key('private-pair-composer'))
                .evaluate()
                .isNotEmpty &&
            tester
                .widget<TextField>(
                  find.byKey(const Key('private-pair-composer')),
                )
                .controller!
                .text
                .isEmpty &&
            find.text('Ci vediamo sabato alle 10.').evaluate().isNotEmpty,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      expect(
        await scope()
            .read(languagePreferenceProvider.notifier)
            .select(LanguagePreference.english),
        isTrue,
      );
      await route('/messages');
      await until(
        () => find.byKey(ValueKey('private-pair-$marco')).evaluate().isNotEmpty,
      );
      await capture('after-en-light-private');
      await until(
        () =>
            tester.view.physicalSize.width / tester.view.devicePixelRatio < 321,
        reason: 'actual narrow Android display',
      );
      await route('/messages/chats/resource/$resource');
      await until(
        () => find
            .byKey(const Key('private-pair-composer'))
            .evaluate()
            .isNotEmpty,
      );
      final media = MediaQuery.of(
        tester.element(find.byKey(const Key('private-pair-composer'))),
      );
      expect(media.textScaler.scale(16), greaterThan(28));
      await capture('after-en-light-narrow-2x');
      await scope().read(authGatewayProvider).signOut();
      await until(() => scope().read(authSessionProvider).identity == null);
      expect(find.byKey(const Key('private-pair-composer')), findsNothing);
      await signIn(marcoEmail, marco);
      await route('/messages');
      await until(
        () => find.byKey(ValueKey('private-pair-$alice')).evaluate().isNotEmpty,
      );
      await route('/messages/chats/resource/$resource');
      await until(
        () => find.text('Ci vediamo sabato alle 10.').evaluate().isNotEmpty,
        reason: 'other real account receives the original source message in its same pair thread',
      );
      await capture('after-marco-received');
    }
    await scope().read(authGatewayProvider).signOut();
    await until(() => scope().read(authSessionProvider).identity == null);
    binding.reportData = {
      'fictional': true,
      'realOtp': true,
      'before': before,
      'passed': true,
    };
  });
}
