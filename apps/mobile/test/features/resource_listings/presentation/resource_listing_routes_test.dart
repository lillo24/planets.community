import '../../../support/fake_policy.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_loans/data/resource_loan_gateway.dart';
import 'package:planets_mobile/features/resource_saved_searches/data/resource_saved_search_gateway.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_resource_listing.dart';
import '../../../support/fake_resource_loan.dart';
import '../../../support/fake_resource_saved_search.dart';

void main() {
  testWidgets('public list and exact detail remain signed-out Browse routes', (
    tester,
  ) async {
    const session = AuthSessionState.signedOut();
    final gateway = FakeResourceListingGateway()
      ..publicItems = [publicResourceListingFixture()]
      ..publicDetail = publicResourceListingDetailFixture();
    final app = await _pump(
      tester,
      session: session,
      gateway: gateway,
      initialLocation: '/resources',
    );
    final router = app.read(appRouterProvider);

    expect(find.byKey(const Key('auth-email-field')), findsNothing);
    expect(find.text('Garden tools'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );

    router.go('/resources/edit');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-email-field')), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/resources/edit');

    router.go('/resources/$resourceListingId');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-email-field')), findsNothing);
    expect(find.text('Listing details'), findsOneWidget);
  });

  testWidgets('signed-out management preserves each exact OTP return path', (
    tester,
  ) async {
    const session = AuthSessionState.signedOut();
    final app = await _pump(
      tester,
      session: session,
      gateway: FakeResourceListingGateway(),
    );
    final router = app.read(appRouterProvider);

    for (final destination in [
      '/resources/mine',
      '/resources/create',
      '/resources/saved-searches',
      '/resources/$resourceListingId/edit',
      '/resources/$resourceListingId/loan-schedule',
    ]) {
      router.go(destination);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['returnTo'],
        destination,
      );
    }
  });

  testWidgets('incomplete profile preserves management completion intent', (
    tester,
  ) async {
    const session = AuthSessionState.profileSetupRequired(
      AuthIdentity(id: resourceOwnerProfileId),
      hasProfileAnchor: true,
    );
    final app = await _pump(
      tester,
      session: session,
      gateway: FakeResourceListingGateway(),
      complete: false,
    );
    final router = app.read(appRouterProvider);

    for (final destination in [
      '/resources/mine',
      '/resources/create',
      '/resources/saved-searches',
      '/resources/$resourceListingId/edit',
      '/resources/$resourceListingId/loan-schedule',
    ]) {
      router.go(destination);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/profile/edit');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['returnTo'],
        destination,
      );
    }
  });

  testWidgets('ready resource routes all select the Browse branch', (
    tester,
  ) async {
    const session = AuthSessionState.ready(
      AuthIdentity(id: resourceOwnerProfileId),
    );
    final gateway = FakeResourceListingGateway()
      ..publicItems = [publicResourceListingFixture()]
      ..publicDetail = publicResourceListingDetailFixture()
      ..ownItems = [ownResourceListingFixture()];
    final app = await _pump(tester, session: session, gateway: gateway);
    final router = app.read(appRouterProvider);

    for (final destination in [
      '/resources',
      '/resources/$resourceListingId',
      '/resources/mine',
      '/resources/create',
      '/resources/saved-searches',
      '/resources/$resourceListingId/edit',
      '/resources/$resourceListingId/loan-schedule',
    ]) {
      router.go(destination);
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(router.routeInformationProvider.value.uri.path, destination);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('saved-searches is static and never parsed as a listing ID', (
    tester,
  ) async {
    const session = AuthSessionState.ready(
      AuthIdentity(id: resourceOwnerProfileId),
    );
    final app = await _pump(
      tester,
      session: session,
      gateway: FakeResourceListingGateway(),
    );

    app.read(appRouterProvider).go('/resources/saved-searches');
    await tester.pumpAndSettle();

    expect(find.text('Saved searches'), findsOneWidget);
    expect(find.text('Listing details'), findsNothing);
    expect(find.text('No saved searches yet.'), findsOneWidget);
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required AuthSessionState session,
  required FakeResourceListingGateway gateway,
  String initialLocation = '/',
  bool complete = true,
}) async {
  final snapshot = session.identity == null
      ? const AuthSnapshot()
      : AuthSnapshot(identity: session.identity);
  final auth = FakeAuthGateway(snapshot: snapshot);
  final router = createAppRouter(
    readPolicyAccepted: () => true,
    initialLocation: initialLocation,
    readAuthSession: () => session,
  );
  addTearDown(auth.close);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preacceptedPolicyFixture,
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'test-key',
          ),
        ),
        appRouterProvider.overrideWithValue(router),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = complete
                ? ProfileAnchorReadiness.complete
                : ProfileAnchorReadiness.incomplete,
        ),
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(data: profileFixture(complete: complete)),
        ),
        resourceListingGatewayProvider.overrideWithValue(gateway),
        resourceLoanGatewayProvider.overrideWithValue(
          FakeResourceLoanGateway(),
        ),
        resourceSavedSearchGatewayProvider.overrideWithValue(
          FakeResourceSavedSearchGateway(),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}
