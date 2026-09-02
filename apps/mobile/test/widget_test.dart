import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';

import 'support/fake_auth.dart';

void main() {
  testWidgets('renders the localized neutral foundation at the root route', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig()),
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(profile),
        ],
        child: const PlanetsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLANETS'), findsOneWidget);
    expect(find.text('Mobile foundation ready'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

AppConfig _testConfig() => AppConfig.fromValues(
  appEnvironment: 'local',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'test-publishable-key',
);
