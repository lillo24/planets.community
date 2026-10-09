import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/geographic_discovery/application/geographic_discovery_controller.dart';
import 'package:planets_mobile/features/geographic_discovery/application/map_discovery_sessions.dart';
import 'package:planets_mobile/features/geographic_discovery/data/geographic_discovery_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/data/map_provider_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/geographic_discovery.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/map_discovery.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/map_discovery_screen.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/map_view_button.dart';
import 'package:planets_mobile/features/locations/presentation/location_attribution.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/application/recurring_activity_controllers.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/resource_listings/application/resource_listing_controllers.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../test_support/map_discovery_fixture.dart';
import '../../support/fake_proposal.dart';
import '../../support/fake_recurring_activity.dart';
import '../../support/fake_resource_listing.dart';

Future<
  ({ProviderContainer container, GoRouter router, FixtureGeographicGateway geo})
>
pumpMap(
  WidgetTester tester, {
  MapDiscoveryOrigin origin = MapDiscoveryOrigin.projects,
  GeographicDiscoveryGateway? geographic,
  MapProviderGateway? provider,
  Locale locale = const Locale('en'),
  double scale = 1,
  bool inheritedFilters = false,
}) async {
  final geo = geographic ?? FixtureGeographicGateway();
  final container = ProviderContainer(
    overrides: [
      geographicDiscoveryGatewayProvider.overrideWithValue(geo),
      mapProviderGatewayProvider.overrideWithValue(
        provider ?? const DisabledMapProviderGateway(),
      ),
      proposalGatewayProvider.overrideWithValue(FakeProposalGateway()),
      recurringActivityGatewayProvider.overrideWithValue(
        FakeRecurringActivityGateway(),
      ),
      resourceListingGatewayProvider.overrideWithValue(
        FakeResourceListingGateway(),
      ),
    ],
  );
  container.read(authSessionProvider.notifier).markSignedOut();
  if (inheritedFilters) {
    await container
        .read(publicProposalsProvider.notifier)
        .applyFilters(
          query: 'garden',
          locality: 'Trento',
          skillIds: {mapFixtureId(50)},
        );
    await container
        .read(publicRecurringActivitiesProvider.notifier)
        .applyLocality('Trento');
    await container
        .read(publicResourceListingsProvider.notifier)
        .applyFilters(
          query: 'tools',
          locality: 'Trento',
          mode: ResourceListingMode.exchange,
        );
  }
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ListView(
            children: [
              for (final family in MapDiscoveryOrigin.values)
                MapViewButton(origin: family),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/discover/map/:origin',
        builder: (context, state) => MapDiscoveryScreen(
          origin: MapDiscoveryOrigin.values.byName(
            state.pathParameters['origin']!,
          ),
        ),
      ),
      for (final path in ['/proposals/:id', '/tavoli/:id', '/resources/:id'])
        GoRoute(
          path: path,
          builder: (context, state) => Scaffold(
            appBar: AppBar(),
            body: Text(
              'Existing detail ${state.uri.path}',
              key: const Key('map-test-detail'),
            ),
          ),
        ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: const EdgeInsets.only(bottom: 24),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tapMapKey(tester, 'map-open-${origin.name}');
  return (
    container: container,
    router: router,
    geo: geo as FixtureGeographicGateway,
  );
}

Future<void> tapMapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> chooseFamily(WidgetTester tester, String label) async {
  await tapMapKey(tester, 'map-family');
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'large-text cluster chooser accommodates an open keyboard and credited links',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await pumpMap(tester, scale: 2);
      await tapMapKey(tester, 'map-pin-one_time:${mapFixtureId(1)}');
      expect(find.text('Choose among 2 loaded results'), findsOneWidget);
      expect(find.byType(LocationAttribution), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(Key('map-cluster-item-one_time:${mapFixtureId(1)}')),
        100,
        scrollable: find.descendant(
          of: find.byKey(const Key('map-cluster-choices')),
          matching: find.byType(Scrollable),
        ),
      );
      await tapMapKey(tester, 'map-cluster-item-one_time:${mapFixtureId(1)}');
      expect(find.byKey(const Key('map-selected-title')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final failure in [
    GeoFailureKind.tooBroad,
    GeoFailureKind.malformed,
    GeoFailureKind.unavailable,
  ]) {
    testWidgets('first-page $failure differs from a legitimate empty result', (
      tester,
    ) async {
      final geo = FixtureGeographicGateway()
        ..loader = (_, _) async => throw GeoFailure(failure);
      await pumpMap(tester, geographic: geo);
      final message = switch (failure) {
        GeoFailureKind.tooBroad => 'This area has too many candidates.',
        GeoFailureKind.malformed => 'The map response could not be verified.',
        _ => 'Geographic search is unavailable.',
      };
      expect(find.textContaining(message), findsOneWidget);
      expect(
        find.textContaining('No geographically referenced results'),
        findsNothing,
      );
      geo.loader = (_, _) async => mapFixturePage([]);
      await tapMapKey(tester, 'map-refresh');
      expect(
        find.textContaining('No geographically referenced results'),
        findsOneWidget,
      );
      expect(find.textContaining(message), findsNothing);
    });
  }
  testWidgets(
    'explicit pagination counts loaded rows; failed page retains pins and retries',
    (tester) async {
      final geo = FixtureGeographicGateway(
        items: List.generate(21, (i) => mapFixtureItem(i + 1)),
      );
      await pumpMap(tester, geographic: geo);
      expect(geo.calls.length, 1);
      expect(find.textContaining('20 loaded results.'), findsOneWidget);
      geo.loader = (_, _) async =>
          throw const GeoFailure(GeoFailureKind.unavailable);
      await tapMapKey(tester, 'map-load-more');
      expect(
        find.textContaining('Confirmed results remain visible'),
        findsOneWidget,
      );
      expect(find.textContaining('20 loaded results.'), findsOneWidget);
      final cursor = geo.calls.last.cursor;
      geo.loader = null;
      await tapMapKey(tester, 'map-load-more');
      expect(geo.calls.last.cursor, same(cursor));
      expect(find.textContaining('21 loaded results.'), findsOneWidget);
      expect(find.byKey(const Key('map-load-more')), findsNothing);
    },
  );
  testWidgets(
    'expired cursor retains confirmed rows and requires a fresh search',
    (tester) async {
      final geo = FixtureGeographicGateway(
        items: List.generate(21, (i) => mapFixtureItem(i + 1)),
      );
      await pumpMap(tester, geographic: geo);
      geo.loader = (_, _) async =>
          throw const GeoFailure(GeoFailureKind.expiredCursor);
      await tapMapKey(tester, 'map-load-more');
      expect(find.textContaining('This search expired.'), findsOneWidget);
      expect(find.textContaining('20 loaded results.'), findsOneWidget);
      expect(find.byKey(const Key('map-load-more')), findsNothing);
      geo.loader = null;
      await tapMapKey(tester, 'map-refresh');
      expect(geo.calls.last.cursor, isNull);
      expect(find.textContaining('This search expired.'), findsNothing);
    },
  );
  testWidgets(
    'background clears results, rejects late center and resumes a fresh search',
    (tester) async {
      final delayed = Completer<MapSearchCenter>();
      final provider = FixtureMapProviderGateway()..resolveDelay = delayed;
      final app = await pumpMap(tester, provider: provider);
      await tester.enterText(
        find.byKey(const Key('map-center-input')),
        'Bolzano',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.tap(find.byKey(Key('map-suggestion-${mapFixtureId(100)}')));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(
        app.container.read(geographicDiscoveryProvider('map05:projects')).items,
        isEmpty,
      );
      delayed.complete(const MapSearchCenter('Stale center', 48, 12));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(app.geo.calls.length, 2);
      expect((app.geo.calls.last.query.area as GeoRadius).latitude, 46.0748);
      expect(find.text('Stale center'), findsNothing);
    },
  );
  testWidgets(
    'account ABA clears preferences and rejects old pending geography',
    (tester) async {
      final geo = FixtureGeographicGateway();
      final app = await pumpMap(tester, geographic: geo);
      final auth = app.container.read(authSessionProvider.notifier);
      auth.markProfileReady(const AuthIdentity(id: 'Alice'));
      await tester.pumpAndSettle();
      app.container
              .read(mapDiscoverySessionsProvider)
              .forOrigin(MapDiscoveryOrigin.projects)
              .radiusKm =
          50;
      final pending = Completer<GeoPage>();
      geo.loader = (_, _) => pending.future;
      await tester.ensureVisible(find.byKey(const Key('map-refresh')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-refresh')));
      await tester.pump();
      auth.markProfileReady(const AuthIdentity(id: 'Bob'));
      await tester.pump();
      geo.loader = null;
      auth.markProfileReady(const AuthIdentity(id: 'Alice'));
      await tester.pumpAndSettle();
      pending.complete(mapFixturePage([mapFixtureItem(99)]));
      await tester.pumpAndSettle();
      expect(
        app.container
            .read(mapDiscoverySessionsProvider)
            .forOrigin(MapDiscoveryOrigin.projects)
            .radiusKm,
        5,
      );
      expect(
        app.container
            .read(geographicDiscoveryProvider('map05:projects'))
            .items
            .any((i) => i.id == mapFixtureId(99)),
        isFalse,
      );
    },
  );
  testWidgets('signed-out paid lookup remains disabled even with flags on', (
    tester,
  ) async {
    final provider = FixtureMapProviderGateway(
      requiresAuthentication: true,
      tilesEnabled: true,
    );
    await pumpMap(tester, provider: provider);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('map-center-input')))
          .enabled,
      isFalse,
    );
    expect(provider.searches, isEmpty);
    expect(provider.tileCalls, isEmpty);
    expect(find.textContaining('requires sign-in'), findsWidgets);
  });
  for (final origin in MapDiscoveryOrigin.values) {
    testWidgets(
      '${origin.name} enters its family with a truthful no-basemap canvas',
      (tester) async {
        final app = await pumpMap(tester, origin: origin);
        expect(app.geo.calls.single.query.kinds, switch (origin) {
          MapDiscoveryOrigin.projects => {GeoKind.oneTime},
          MapDiscoveryOrigin.tavoli => {GeoKind.recurring},
          MapDiscoveryOrigin.resources => {GeoKind.resource},
        });
        final radius = app.geo.calls.single.query.area as GeoRadius;
        expect(radius.latitude, 46.0748);
        expect(radius.longitude, 11.1217);
        expect(radius.radiusMeters, 5000);
        expect(find.textContaining('Basemap unavailable'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('map-center-input')))
              .enabled,
          isFalse,
        );
        expect(find.byType(LocationAttribution), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'All preserves family-scoped list filters and view preferences across List/Map',
    (tester) async {
      final app = await pumpMap(tester, inheritedFilters: true);
      await chooseFamily(tester, 'All');
      final query = app.geo.calls.last.query;
      expect(query.kinds, GeoKind.values.toSet());
      expect(query.proposalKeyword, 'garden');
      expect(query.proposalLocality, 'Trento');
      expect(query.proposalSkillIds, [mapFixtureId(50)]);
      expect(query.tavoloLocality, 'Trento');
      expect(query.resourceKeyword, 'tools');
      expect(query.resourceMode, GeoResourceMode.exchange);
      final prefs = app.container
          .read(mapDiscoverySessionsProvider)
          .forOrigin(MapDiscoveryOrigin.projects);
      prefs.radiusKm = 10;
      await tapMapKey(tester, 'map-return-list');
      expect(app.container.read(publicProposalsProvider).query, 'garden');
      expect(
        app.container.read(publicResourceListingsProvider).modeFilter,
        ResourceListingMode.exchange,
      );
      await tapMapKey(tester, 'map-open-projects');
      expect(app.geo.calls.last.query.kinds, GeoKind.values.toSet());
      expect((app.geo.calls.last.query.area as GeoRadius).radiusMeters, 10000);
      expect(find.text('All'), findsOneWidget);
    },
  );
  testWidgets(
    'pan and zoom never search automatically; Search this area switches to bounds',
    (tester) async {
      final app = await pumpMap(tester);
      await tester.ensureVisible(find.byKey(const Key('public-point-map')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('public-point-map')),
        const Offset(-80, 30),
      );
      await tester.pumpAndSettle();
      expect(app.geo.calls.length, 1);
      await tapMapKey(tester, 'map-zoom-in');
      expect(app.geo.calls.length, 1);
      await tapMapKey(tester, 'map-search-area');
      expect(app.geo.calls.length, 2);
      expect(app.geo.calls.last.query.area, isA<GeoBounds>());
      await tapMapKey(tester, 'map-back-radius');
      expect(app.geo.calls.last.query.area, isA<GeoRadius>());
    },
  );
  testWidgets(
    'identical locality cluster chooses a card and uses the existing detail route',
    (tester) async {
      final app = await pumpMap(tester);
      await tapMapKey(tester, 'map-pin-one_time:${mapFixtureId(1)}');
      expect(find.text('Choose among 2 loaded results'), findsOneWidget);
      await tapMapKey(tester, 'map-cluster-item-one_time:${mapFixtureId(1)}');
      expect(find.byKey(const Key('map-selected-title')), findsOneWidget);
      expect(
        find.textContaining('meeting venue may be elsewhere'),
        findsOneWidget,
      );
      await tapMapKey(tester, 'map-open-detail');
      expect(
        app.router.routerDelegate.state.uri.path,
        '/proposals/${mapFixtureId(1)}',
      );
      expect(
        app.container.read(geographicDiscoveryProvider('map05:projects')).items,
        isEmpty,
      );
      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.geo.calls.length, 2);
      expect(find.byKey(const Key('map-selected-title')), findsOneWidget);
    },
  );
  testWidgets(
    'public Resource address card distinguishes Donate and Exchange',
    (tester) async {
      await pumpMap(tester, origin: MapDiscoveryOrigin.resources);
      await tapMapKey(tester, 'map-pin-resource:${mapFixtureId(5)}');
      expect(
        find.textContaining('Public address or venue reference'),
        findsOneWidget,
      );
      expect(find.text('Scambia'), findsOneWidget);
      await tapMapKey(tester, 'map-open-detail');
      expect(
        find.text('Existing detail /resources/${mapFixtureId(5)}'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'explicit center selection debounces and never treats typed text as coordinates',
    (tester) async {
      final provider = FixtureMapProviderGateway();
      final app = await pumpMap(tester, provider: provider);
      await tester.ensureVisible(find.byKey(const Key('map-center-input')));
      await tester.enterText(find.byKey(const Key('map-center-input')), 'Bol');
      await tester.pump(const Duration(milliseconds: 200));
      expect(provider.searches, isEmpty);
      expect(app.geo.calls.length, 1);
      await tester.enterText(
        find.byKey(const Key('map-center-input')),
        'Bolzano',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(provider.searches, ['Bolzano']);
      expect(app.geo.calls.length, 1);
      await tapMapKey(tester, 'map-suggestion-${mapFixtureId(100)}');
      expect(provider.resolutions, [mapFixtureId(100)]);
      expect((app.geo.calls.last.query.area as GeoRadius).latitude, 46.4983);
      expect(app.geo.calls.length, 2);
    },
  );
  testWidgets(
    'route departure discards late autocomplete without repopulating suggestions',
    (tester) async {
      final delayed = Completer<List<MapCenterSuggestion>>();
      final provider = FixtureMapProviderGateway()..searchDelay = delayed;
      final app = await pumpMap(tester, provider: provider);
      await tester.ensureVisible(find.byKey(const Key('map-center-input')));
      await tester.enterText(
        find.byKey(const Key('map-center-input')),
        'Bolzano',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      app.router.pop();
      await tester.pumpAndSettle();
      delayed.complete([
        MapCenterSuggestion(mapFixtureId(100), 'Stale label', DateTime.now()),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Stale label'), findsNothing);
      expect(
        app.container.read(geographicDiscoveryProvider('map05:projects')).items,
        isEmpty,
      );
    },
  );
  for (final locale in ['en', 'it']) {
    testWidgets(
      '$locale narrow 320px at 2x text keeps controls and attribution accessible',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await pumpMap(tester, locale: Locale(locale), scale: 2);
        expect(tester.takeException(), isNull);
        final credits = find.byType(LocationAttribution);
        final rect = tester.getRect(credits);
        expect(rect.bottom, lessThanOrEqualTo(900));
        expect(rect.top, greaterThanOrEqualTo(0));
        final semantics = tester.ensureSemantics();
        expect(
          tester
              .getSemantics(
                find.byKey(const Key('location-attribution-geoapify')),
              )
              .label,
          contains('Geoapify'),
        );
        expect(
          tester
              .getSemantics(
                find.byKey(const Key('location-attribution-geoapify')),
              )
              .getSemanticsData()
              .flagsCollection
              .isLink,
          isTrue,
        );
        semantics.dispose();
        await tester.ensureVisible(find.byKey(const Key('map-use-center')));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
