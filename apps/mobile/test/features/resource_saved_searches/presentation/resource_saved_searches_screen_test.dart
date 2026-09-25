import 'dart:async';

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
import 'package:planets_mobile/features/resource_saved_searches/application/resource_saved_search_controller.dart';
import 'package:planets_mobile/features/resource_saved_searches/data/resource_saved_search_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_resource_listing.dart';
import '../../../support/fake_resource_saved_search.dart';

void main() {
  testWidgets('shows loading, empty guidance, and Browse resources action', (
    tester,
  ) async {
    final delay = Completer<void>();
    final saved = FakeResourceSavedSearchGateway()..listDelay = delay.future;
    final app = await _pump(tester, saved: saved, settle: false);
    app.read(appRouterProvider).go('/resources/saved-searches');
    await tester.pump();
    await tester.pump();

    expect(find.text('Loading saved searches…'), findsOneWidget);
    delay.complete();
    await tester.pumpAndSettle();
    expect(find.text('No saved searches yet.'), findsOneWidget);
    expect(find.text('Browse resources'), findsOneWidget);

    await tester.tap(find.byKey(const Key('saved-search-empty-browse')));
    await tester.pumpAndSettle();
    expect(
      app.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/resources',
    );
  });

  testWidgets('renders explicit filters for every supported combination', (
    tester,
  ) async {
    final saved = FakeResourceSavedSearchGateway()
      ..items = [
        resourceSavedSearchFixture(),
        resourceSavedSearchFixture(
          id: secondResourceSavedSearchId,
          query: 'bicycle',
          mode: null,
          locality: null,
        ),
        resourceSavedSearchFixture(
          id: createdResourceSavedSearchId,
          query: null,
          mode: ResourceListingMode.exchange,
          locality: null,
        ),
        resourceSavedSearchFixture(
          id: '00000000-0000-4000-8000-000000000604',
          query: null,
          mode: null,
          locality: 'Modena',
        ),
      ];
    final app = await _pump(tester, saved: saved);
    app.read(appRouterProvider).go('/resources/saved-searches');
    await tester.pumpAndSettle();

    expect(find.textContaining('Mode: Dona'), findsOneWidget);
    expect(find.textContaining('Keywords: bicycle'), findsOneWidget);
    expect(find.textContaining('Mode: Scambia'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Locality: Modena'),
      200,
    );
    expect(find.textContaining('Locality: Modena'), findsOneWidget);
    expect(find.text('Open'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Open applies the saved tuple to normal public Browse', (
    tester,
  ) async {
    final saved = FakeResourceSavedSearchGateway()
      ..items = [resourceSavedSearchFixture()];
    final listings = FakeResourceListingGateway();
    final app = await _pump(tester, saved: saved, listings: listings);
    app.read(appRouterProvider).go('/resources/saved-searches');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('saved-search-open-$resourceSavedSearchId')),
    );
    await tester.pumpAndSettle();

    final browse = app.read(publicResourceListingsProvider);
    expect(browse.modeFilter, ResourceListingMode.donate);
    expect(browse.query, 'garden tools');
    expect(browse.locality, 'Bologna');
    expect(listings.lastMode, ResourceListingMode.donate);
    expect(listings.lastQuery, 'garden tools');
    expect(listings.lastLocality, 'Bologna');
    expect(
      app.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/resources',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('resource-query-filter')))
          .controller
          ?.text,
      'garden tools',
    );
  });

  testWidgets('Edit reloads canonical content and duplicate stays open', (
    tester,
  ) async {
    final saved = FakeResourceSavedSearchGateway()
      ..items = [resourceSavedSearchFixture()];
    final app = await _pump(tester, saved: saved);
    app.read(appRouterProvider).go('/resources/saved-searches');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('saved-search-edit-$resourceSavedSearchId')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('saved-search-editor-query')),
      'bicycle',
    );
    await tester.tap(find.byKey(const Key('saved-search-editor-save')));
    await tester.pumpAndSettle();
    expect(find.text('Saved search updated.'), findsOneWidget);
    expect(saved.lastInput?.query, 'bicycle');
    expect(saved.calls.takeLast(2), ['update:$resourceSavedSearchId', 'list']);

    saved.mutationError = const PostgrestException(
      message: 'private duplicate detail',
      code: 'PT409',
    );
    await tester.tap(
      find.byKey(const Key('saved-search-edit-$resourceSavedSearchId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saved-search-editor-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('Another saved search already uses these filters.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Delete requires confirmation and reloads canonical rows', (
    tester,
  ) async {
    final saved = FakeResourceSavedSearchGateway()
      ..items = [resourceSavedSearchFixture()];
    final app = await _pump(tester, saved: saved);
    app.read(appRouterProvider).go('/resources/saved-searches');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('saved-search-delete-$resourceSavedSearchId')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete this saved search?'), findsOneWidget);
    expect(saved.calls, isNot(contains('delete:$resourceSavedSearchId')));
    await tester.tap(find.byKey(const Key('saved-search-confirm-delete')));
    await tester.pumpAndSettle();

    expect(saved.calls.takeLast(2), ['delete:$resourceSavedSearchId', 'list']);
    expect(find.text('Saved search deleted.'), findsOneWidget);
    expect(find.text('No saved searches yet.'), findsOneWidget);
  });

  testWidgets('mutation progress disables duplicate edit submission', (
    tester,
  ) async {
    final delay = Completer<void>();
    final saved = FakeResourceSavedSearchGateway()
      ..items = [resourceSavedSearchFixture()]
      ..mutationDelay = delay.future;
    final app = await _pump(tester, saved: saved);
    app.read(appRouterProvider).go('/resources/saved-searches');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('saved-search-edit-$resourceSavedSearchId')),
    );
    await tester.pumpAndSettle();

    final save = find.byKey(const Key('saved-search-editor-save'));
    await tester.tap(save);
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(
      find.descendant(
        of: save,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(save);
    expect(
      saved.calls.where((call) => call.startsWith('update:')),
      hasLength(1),
    );
    delay.complete();
    await tester.pumpAndSettle();
    expect(find.text('Saved search updated.'), findsOneWidget);
  });

  testWidgets('supports load more, pull refresh, and high text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final saved = FakeResourceSavedSearchGateway()
      ..items = List.generate(
        21,
        (index) => resourceSavedSearchFixture(
          id: '00000000-0000-4000-8000-${(index + 800).toString().padLeft(12, '0')}',
          query: index == 0 ? 'q' * 120 : 'query $index',
        ),
      );
    final app = await _pump(tester, saved: saved);
    app.read(appRouterProvider).go('/resources/saved-searches');
    await tester.pumpAndSettle();
    expect(app.read(resourceSavedSearchesProvider).hasMore, isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, -10000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved-search-load-more')), findsOneWidget);
    await tester.tap(find.byKey(const Key('saved-search-load-more')));
    await tester.pumpAndSettle();
    expect(saved.calls, contains('list-more'));
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, 10000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(saved.calls.where((call) => call == 'list').length, greaterThan(1));
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeResourceSavedSearchGateway saved,
  FakeResourceListingGateway? listings,
  bool settle = true,
}) async {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(
      identity: AuthIdentity(id: resourceOwnerProfileId),
    ),
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
        resourceListingGatewayProvider.overrideWithValue(
          listings ?? FakeResourceListingGateway(),
        ),
        resourceSavedSearchGatewayProvider.overrideWithValue(saved),
      ],
      child: const PlanetsApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) => skip(length - count);
}
