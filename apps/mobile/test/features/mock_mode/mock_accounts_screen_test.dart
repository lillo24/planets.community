import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/help/presentation/help_screen.dart';
import 'package:planets_mobile/features/mock_mode/application/mock_mode_coordinator.dart';
import 'package:planets_mobile/features/mock_mode/domain/mock_models.dart';
import 'package:planets_mobile/features/mock_mode/presentation/mock_accounts_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_auth.dart';
import 'mock_mode_coordinator_test.dart' as fixtures;

class PickerAccess extends fixtures.FakeAccess {
  List<MockPersona> people = [fixtures.giulia, fixtures.marco];
  Completer<void>? catalogGate;
  @override
  Future<List<MockPersona>> catalog({String? expectedRoot}) async {
    await catalogGate?.future;
    await super.catalog(expectedRoot: expectedRoot);
    return people;
  }
}

void main() {
  late PickerAccess access;
  late MockModeCoordinator coordinator;
  late FakeAuthGateway auth;
  setUp(() async {
    access = PickerAccess();
    auth = FakeAuthGateway();
    coordinator = MockModeCoordinator(
      config: fixtures.mockConfig(),
      access: access,
      store: fixtures.MemoryModeStore(),
    );
    await coordinator.start();
    coordinator.requestSelection();
  });
  tearDown(() async {
    coordinator.dispose();
    await access.close();
    await auth.close();
  });
  Future<void> mount(
    WidgetTester tester, {
    String language = 'en',
    bool dark = false,
    bool mock = false,
    Widget child = const MockAccountsScreen(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockModeCoordinatorProvider.overrideWithValue(coordinator),
          closedTestMockCapabilityProvider.overrideWithValue(true),
          activeMockRealmProvider.overrideWithValue(mock),
          authGatewayProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          locale: Locale(language),
          theme: dark ? AppTheme.dark : AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: child,
        ),
      ),
    );
    await tester.pump();
  }

  for (final language in ['en', 'it']) {
    for (final dark in [false, true]) {
      testWidgets(
        '$language $dark selector wraps at 320dp 2x without role promises',
        (tester) async {
          tester.view.physicalSize = const Size(320, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await mount(tester, language: language, dark: dark);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('mock-shared-world')), findsOneWidget);
          await tester.scrollUntilVisible(
            find.byKey(const Key('mock-login-giulia')),
            220,
            scrollable: find.descendant(
              of: find.byKey(const Key('mock-accounts-list')),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('giulia@personas.planets.invalid'), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(auth.requestCount, 0);
        },
      );
    }
  }
  testWidgets(
    'empty and denied catalogs never become fabricated account rows',
    (tester) async {
      access.people = [];
      await mount(tester);
      await tester.pumpAndSettle();
      expect(find.text('No mock accounts are available.'), findsOneWidget);
      access.fail = MockFailureKind.denied;
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('enrollment'), findsOneWidget);
      expect(find.byKey(const Key('mock-login-giulia')), findsNothing);
      expect(access.prepared, isEmpty);
    },
  );
  testWidgets(
    'replacing control account rejects a delayed catalog and cached actions',
    (tester) async {
      access.catalogGate = Completer<void>();
      await mount(tester);
      access.id = fixtures.otherRoot;
      access.controls.add(fixtures.otherRoot);
      access.catalogGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mock-login-giulia')), findsNothing);
      expect(find.textContaining('normal PLANETS account'), findsOneWidget);
    },
  );
  testWidgets(
    'unresolved selection disables conflicting login and identifies the committed account',
    (tester) async {
      await mount(tester);
      await tester.pumpAndSettle();
      access.gate = Completer<void>();
      final action = find.byKey(const Key('mock-login-giulia'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pump();
      expect(tester.widget<FilledButton>(action).onPressed, isNull);
      access.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mock-current-giulia')), findsOneWidget);
      expect(coordinator.active?.personaKey, 'giulia');
      expect(auth.requestCount, 0);
    },
  );
  testWidgets(
    'Help account entry is conditional on active mock, using the same route',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/help',
        routes: [
          GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
          GoRoute(
            path: '/settings/mock-accounts',
            builder: (_, _) => const MockAccountsScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      Future<void> app(bool mock) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockModeCoordinatorProvider.overrideWithValue(coordinator),
              closedTestMockCapabilityProvider.overrideWithValue(true),
              activeMockRealmProvider.overrideWithValue(mock),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await app(false);
      expect(find.byKey(const Key('help-mock-accounts-action')), findsNothing);
      await app(true);
      await tester.tap(find.byKey(const Key('help-mock-accounts-action')));
      await tester.pumpAndSettle();
      expect(find.byType(MockAccountsScreen), findsOneWidget);
    },
  );
}
