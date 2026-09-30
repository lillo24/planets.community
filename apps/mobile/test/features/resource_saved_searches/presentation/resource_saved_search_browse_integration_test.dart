import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/resource_listings/application/resource_listing_controllers.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/features/resource_saved_searches/data/resource_saved_search_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_resource_listing.dart';
import '../../../support/fake_resource_saved_search.dart';

void main() {
  testWidgets('signed-out Browse remains public with no private actions', (
    tester,
  ) async {
    final listings = FakeResourceListingGateway();
    final saved = FakeResourceSavedSearchGateway();
    final app = await _pump(
      tester,
      listings: listings,
      saved: saved,
      signedIn: false,
    );
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resource-save-search')), findsNothing);
    expect(
      find.byKey(const Key('resource-saved-searches-action')),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const Key('resource-query-filter')),
      'tools',
    );
    await tester.tap(find.byKey(const Key('resource-apply-filters')));
    await tester.pumpAndSettle();
    expect(listings.lastQuery, 'tools');
    expect(saved.calls, isEmpty);
  });

  testWidgets('Save uses the current controls for Browse and create', (
    tester,
  ) async {
    final listings = FakeResourceListingGateway();
    final saved = FakeResourceSavedSearchGateway();
    final app = await _pump(tester, listings: listings, saved: saved);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();

    final save = find.byKey(const Key('resource-save-search'));
    expect(tester.widget<OutlinedButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('resource-query-filter')),
      '  garden tools  ',
    );
    await tester.enterText(
      find.byKey(const Key('resource-locality-filter')),
      '  Bologna  ',
    );
    await tester.tap(find.text('Scambia').first);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(listings.lastMode, ResourceListingMode.exchange);
    expect(listings.lastQuery, 'garden tools');
    expect(listings.lastLocality, 'Bologna');
    expect(saved.lastInput?.mode, ResourceListingMode.exchange);
    expect(saved.lastInput?.query, 'garden tools');
    expect(saved.lastInput?.locality, 'Bologna');
    expect(find.text('Search saved.'), findsOneWidget);
  });

  testWidgets(
    'private save failure does not roll back applied Browse filters',
    (tester) async {
      final listings = FakeResourceListingGateway();
      final saved = FakeResourceSavedSearchGateway()
        ..mutationError = const PostgrestException(
          message: 'private duplicate detail',
          code: 'PT409',
        );
      final app = await _pump(tester, listings: listings, saved: saved);
      app.read(appRouterProvider).go('/resources');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('resource-query-filter')),
        'bicycle',
      );
      await tester.pump();
      final save = find.byKey(const Key('resource-save-search'));
      expect(tester.widget<OutlinedButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      for (var index = 0; index < 10; index++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('This search is already saved.'), findsOneWidget);
      expect(saved.lastInput?.query, 'bicycle');
      expect(app.read(publicResourceListingsProvider).query, 'bicycle');
      expect(listings.lastQuery, 'bicycle');
    },
  );

  testWidgets(
    'phase-only changes preserve unsent controls; external tuple changes sync',
    (tester) async {
      final listings = FakeResourceListingGateway();
      final saved = FakeResourceSavedSearchGateway();
      final app = await _pump(tester, listings: listings, saved: saved);
      app.read(appRouterProvider).go('/resources');
      await tester.pumpAndSettle();
      await app
          .read(publicResourceListingsProvider.notifier)
          .applyFilters(mode: null, locality: '', query: 'canonical');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('resource-query-filter')),
        'unsent local edit',
      );
      await app.read(publicResourceListingsProvider.notifier).load(force: true);
      await tester.pumpAndSettle();
      expect(_text(tester, 'resource-query-filter'), 'unsent local edit');

      await app
          .read(publicResourceListingsProvider.notifier)
          .applyFilters(
            mode: ResourceListingMode.donate,
            locality: 'Modena',
            query: 'external',
          );
      await tester.pumpAndSettle();
      expect(_text(tester, 'resource-query-filter'), 'external');
      expect(_text(tester, 'resource-locality-filter'), 'Modena');
      expect(
        tester
            .widget<SegmentedButton<Object>>(
              find.byKey(const Key('resource-mode-filter')),
            )
            .selected
            .single
            .toString(),
        contains('donate'),
      );

      await tester.enterText(
        find.byKey(const Key('resource-query-filter')),
        'manual',
      );
      await tester.tap(find.byKey(const Key('resource-apply-filters')));
      await tester.pumpAndSettle();
      expect(app.read(publicResourceListingsProvider).query, 'manual');
    },
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeResourceListingGateway listings,
  required FakeResourceSavedSearchGateway saved,
  bool signedIn = true,
}) async {
  final auth = FakeAuthGateway(
    snapshot: signedIn
        ? const AuthSnapshot(identity: AuthIdentity(id: resourceOwnerProfileId))
        : const AuthSnapshot(),
  );
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'test-key',
          ),
        ),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = ProfileAnchorReadiness.complete,
        ),
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(data: profileFixture()),
        ),
        resourceListingGatewayProvider.overrideWithValue(listings),
        resourceSavedSearchGatewayProvider.overrideWithValue(saved),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
