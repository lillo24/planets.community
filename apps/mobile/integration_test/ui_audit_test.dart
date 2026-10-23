import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/bootstrap/bootstrap.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/mock_mode/application/mock_mode_coordinator.dart';

// Explicit, local-only audit target. Product bootstrap, router, account selector,
// Auth, gateways and widgets are unchanged. The host records Android screenshots,
// including system chrome and the real IME; no rendered fixture substitutes.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('UIAUDIT01 native review session', (tester) async {
    final config = AppConfig.fromCompileTime();
    expect(config.environment, AppEnvironment.local);
    expect(config.supabaseUrl.host, '127.0.0.1');
    await bootstrapApplication();
    final product = find.byType(PlanetsApp, skipOffstage: false);
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (product.evaluate().isNotEmpty) break;
    }
    ProviderContainer scope() =>
        ProviderScope.containerOf(tester.element(product), listen: false);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    Future<dynamic> exchange(String endpoint, [Object? value]) async {
      final req = await client.openUrl(
        value == null ? 'GET' : 'POST',
        Uri.parse('http://127.0.0.1:58420$endpoint'),
      );
      if (value != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(value));
      }
      final res = await req.close();
      if (res.statusCode != 200) {
        throw StateError('Audit host: ${res.statusCode}');
      }
      return jsonDecode(await utf8.decodeStream(res));
    }

    Finder target(Map<String, dynamic> command) {
      final Finder finder;
      if (command['key'] != null) {
        finder = find.byKey(Key(command['key'] as String));
      } else if (command['type'] == 'TextField') {
        finder = find.byType(TextField);
      } else if (command['tooltip'] != null) {
        finder = find.byTooltip(command['tooltip'] as String);
      } else {
        finder = find.text(command['text'] as String);
      }
      return finder.at((command['index'] as int?) ?? 0);
    }

    final deadline = DateTime.now().add(const Duration(hours: 8));
    while (DateTime.now().isBefore(deadline)) {
      final command = await tester.runAsync(() => exchange('/next'));
      if (command == null || command['action'] == 'idle') {
        await tester.pump(const Duration(milliseconds: 150));
        continue;
      }
      if (command['action'] == 'finish') {
        await tester.runAsync(
          () => exchange('/result', {'id': command['id'], 'ok': true}),
        );
        break;
      }
      String? error;
      try {
        switch (command['action']) {
          case 'route':
            scope().read(appRouterProvider).go(command['route'] as String);
          case 'tap':
            final finder = target(command);
            if (finder.evaluate().isEmpty) throw StateError('Target absent');
            await tester.ensureVisible(finder);
            await tester.pump(const Duration(milliseconds: 200));
            await tester.tap(finder);
          case 'scroll':
            final finder = find.byType(Scrollable);
            if (finder.evaluate().isEmpty) throw StateError('No scrollable');
            await tester.drag(
              finder.at((command['index'] as int?) ?? 0),
              Offset(0, (command['dy'] as num?)?.toDouble() ?? -550),
            );
          case 'back':
            final router = scope().read(appRouterProvider);
            if (router.canPop()) {
              router.pop();
            } else {
              router.go('/');
            }
          case 'unfocus':
            FocusManager.instance.primaryFocus?.unfocus();
          case 'status':
            break;
          default:
            throw StateError('Unsupported audit action');
        }
        for (var i = 0; i < ((command['wait'] as int?) ?? 12); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } catch (failure) {
        // An explicit host operation boundary, never a successful domain result.
        error = failure.runtimeType.toString();
      }
      // Realm replacement deliberately hides or unmounts the product root.
      // Recovery is itself auditable UI, not a reason to fail this driver.
      for (var i = 0; i < 200; i++) {
        if (product.evaluate().isNotEmpty &&
            scope().read(mockModeCoordinatorProvider)?.busy != true) {
          break;
        }
        if (find.text('Riprova').evaluate().isNotEmpty ||
            find.text('Retry').evaluate().isNotEmpty) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      final container = product.evaluate().isEmpty ? null : scope();
      final router = container?.read(appRouterProvider);
      final identity = container?.read(authSessionProvider).identity;
      final coordinator = container?.read(mockModeCoordinatorProvider);
      final view = tester.view;
      final texts = find
          .byType(Text)
          .evaluate()
          .map((element) {
            final text = element.widget as Text;
            return text.data ?? text.textSpan?.toPlainText() ?? '';
          })
          .where((text) => text.isNotEmpty)
          .toSet()
          .toList();
      final keys = find
          .byWidgetPredicate((w) => w.key is ValueKey<String>)
          .evaluate()
          .map((e) => (e.widget.key! as ValueKey<String>).value)
          .toSet()
          .toList();
      final exception = tester.takeException();
      await tester.runAsync(
        () => exchange('/result', {
          'id': command['id'],
          'ok': error == null,
          'error': error,
          'route':
              router?.routeInformationProvider.value.uri.toString() ??
              '(Mock root boundary)',
          'persona': coordinator?.active?.personaKey,
          'realm': container == null
              ? 'local-boundary'
              : container.read(activeMockRealmProvider)
              ? 'local-mock'
              : 'local-normal',
          'profileId': identity?.id,
          'texts': texts,
          'keys': keys,
          'physicalSize': [view.physicalSize.width, view.physicalSize.height],
          'devicePixelRatio': view.devicePixelRatio,
          'padding': [
            view.padding.left,
            view.padding.top,
            view.padding.right,
            view.padding.bottom,
          ],
          'viewInsetsBottom': view.viewInsets.bottom,
          'frameworkException': exception?.runtimeType.toString(),
        }),
      );
    }
    client.close(force: true);
  }, timeout: const Timeout(Duration(hours: 4)));
}
