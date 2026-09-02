import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';

void main() {
  testWidgets('shows a safe localized screen for an unknown route', (
    tester,
  ) async {
    final router = createAppRouter(initialLocation: '/private/raw-path');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig()),
          appRouterProvider.overrideWithValue(router),
        ],
        child: const PlanetsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This page is not available.'), findsOneWidget);
    expect(find.textContaining('/private/raw-path'), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}

AppConfig _testConfig() => AppConfig.fromValues(
  appEnvironment: 'local',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'test-key',
);
