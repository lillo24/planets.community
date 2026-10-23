import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/external_activities/application/external_activities_controller.dart';
import 'package:planets_mobile/features/external_activities/application/external_map_session.dart';
import 'package:planets_mobile/features/external_activities/data/external_activity_gateway.dart';
import 'package:planets_mobile/features/external_activities/domain/external_activity.dart';
import 'package:planets_mobile/features/external_activities/presentation/external_activities_screen.dart';
import 'package:planets_mobile/features/external_activities/presentation/external_activities_map_screen.dart';
import 'package:planets_mobile/features/external_activities/presentation/external_activity_detail_screen.dart';
import 'package:planets_mobile/features/geographic_discovery/application/budget_basemap_tiles.dart';
import 'package:planets_mobile/features/geographic_discovery/data/budget_basemap_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/data/map_provider_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/basemap_fallback.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/basemap_tile.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/geographic_discovery.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/public_point_map.dart';
import 'package:planets_mobile/features/mock_mode/application/mock_mode_coordinator.dart';
import 'package:planets_mobile/features/settings/application/activities_split_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/activities_split_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/activities_split_preference.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../test_support/map_discovery_fixture.dart';
import '../../support/fake_external_activities.dart';
import '../../support/fake_settings.dart';
import '../../support/rendered_evidence.dart';

String itemId(int value) =>
    'a9530000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

class RecordingBudgetGateway implements BudgetBasemapGateway {
  final calls = <BasemapTileId>[];
  final images = FixtureMapProviderGateway();

  @override
  Future<BudgetBasemapFrame> tile(
    BasemapTileId id, {
    required bool cacheOnly,
    required Future<void> cancellation,
  }) async {
    calls.add(id);
    return BudgetBasemapFrame(
      source: id,
      bytes: await images.tile(id.z, id.x, id.y, cancellation: cancellation),
      expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 60)),
      validFor: const Duration(seconds: 60),
    );
  }
}

ExternalActivity item(
  int index, {
  String kind = 'place',
  bool geometry = true,
  String precision = 'venue',
}) {
  final payload = externalActivityPayload()
    ..['id'] = itemId(index)
    ..['kind'] = kind
    ..['category'] = 'sports'
    ..['title'] = 'Synthetic court $index'
    ..['discipline'] = 'basketball';
  if (kind != 'event') {
    payload['occurrences'] = [];
    payload['next_at'] = null;
  }
  if (kind == 'course') {
    payload['schedule'] = {
      'season_start': '2026-10-01',
      'season_end': '2026-11-30',
      'timezone': 'Europe/Rome',
    };
  }
  if (geometry) {
    payload['geometry'] = {
      'latitude': 46.0748,
      'longitude': 11.1217,
      'precision': precision,
      'provenance_url': 'https://calendar.example.org/data',
    };
  }
  return ExternalActivity.parse(payload);
}

Future<
  ({
    ProviderContainer container,
    GoRouter router,
    FakeExternalActivityGateway gateway,
    FixtureMapProviderGateway provider,
  })
>
pumpExternalMap(
  WidgetTester tester, {
  ExternalActivityFilter filter = const ExternalActivityFilter(
    category: 'sports',
    kind: ExternalActivityKind.place,
    discipline: 'basketball',
    query: 'court',
  ),
  FakeExternalActivityGateway? gateway,
  BudgetBasemapGateway? basemap,
  bool mock = false,
  String language = 'en',
  bool dark = false,
  double scale = 1,
}) async {
  final data = gateway ?? FakeExternalActivityGateway();
  if (gateway == null) {
    data.onList = (filter, cursor) async => externalPageFixture(
      items: [
        item(1),
        item(2),
        if (!filter.mappedOnly) item(3, geometry: false),
      ],
      health: ExternalCatalogueHealth.healthy,
      disciplines: ['basketball'],
    );
    data.detail = item(2);
  }
  final provider = FixtureMapProviderGateway(
    tilesEnabled: basemap != null,
    centerEnabled: false,
  );
  final container = ProviderContainer(
    overrides: [
      initialActivitiesSplitPreferenceProvider.overrideWithValue(
        const ActivitiesSplitPreferenceState(mode: ActivitiesSplitMode.on),
      ),
      activitiesSplitPreferenceStoreProvider.overrideWithValue(
        FakeActivitiesSplitPreferenceStore(),
      ),
      externalActivityGatewayProvider.overrideWithValue(data),
      mapProviderGatewayProvider.overrideWithValue(provider),
      if (basemap != null) ...[
        budgetBasemapEnabledProvider.overrideWithValue(true),
        budgetBasemapGatewayProvider.overrideWithValue(basemap),
        activeMockRealmProvider.overrideWithValue(mock),
      ],
    ],
  );
  container.read(authSessionProvider.notifier).markSignedOut();
  final hold = container.listen(
    externalActivitiesControllerProvider,
    (_, _) {},
  );
  await container
      .read(externalActivitiesControllerProvider.notifier)
      .filter(filter);
  final router = GoRouter(
    initialLocation: '/activities',
    routes: [
      GoRoute(
        path: '/activities',
        builder: (_, _) => const ExternalActivitiesScreen(),
        routes: [
          GoRoute(
            path: 'map',
            builder: (_, _) => const ExternalActivitiesMapScreen(),
          ),
          GoRoute(
            path: 'external/:id',
            builder: (_, state) => ExternalActivityDetailScreen(
              activityId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/tavoli',
        builder: (_, _) => const Scaffold(body: Text('Native Tavoli')),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    hold.close();
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RenderedEvidence.wrap(
        MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    container: container,
    router: router,
    gateway: data,
    provider: provider,
  );
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).hitTestable().first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await RenderedEvidence.loadFonts(force: true);
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
  });

  for (final mock in [false, true]) {
    testWidgets('Activities basemap warmup stays normal-only (mock=$mock)', (
      tester,
    ) async {
      final basemap = RecordingBudgetGateway();
      final app = await pumpExternalMap(tester, basemap: basemap, mock: mock);
      try {
        // Keep the public Trento reference while requesting visible z14 tiles.
        app.container.read(externalMapSessionProvider).camera.zoom = 14;
        app.router.go('/activities/map');
        await tester.pumpAndSettle();
        expect(find.byType(PublicMapCanvas), findsOneWidget);
        expect(basemap.calls.where((id) => id.z == 14), isNotEmpty);
        expect(
          basemap.calls.where((id) => id.z == 12).toSet(),
          mock ? isEmpty : unorderedEquals(trentoBaselineTiles),
        );
        expect(app.provider.tileCalls, isEmpty);
        expect(app.provider.searches, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 400));
        app.container.read(budgetBasemapTilesProvider).clear();
      }
    });
  }

  testWidgets(
    'ACTMAP01 List Sports/Places → shared cluster → external detail → Map → List retains the one filter and camera',
    (tester) async {
      final app = await pumpExternalMap(tester);
      await tapKey(tester, 'map-open-activities');
      expect(app.gateway.calls.last.mappedOnly, isTrue);
      expect(app.gateway.calls.last.kind, ExternalActivityKind.place);
      expect(app.gateway.calls.last.query, 'court');
      expect(app.gateway.calls.last.discipline, 'basketball');
      expect(find.byType(PublicMapCanvas), findsOneWidget);
      final calls = app.gateway.calls.length;
      tester
          .widget<PublicMapCanvas>(find.byType(PublicMapCanvas))
          .controller
          .move(const LatLng(46.075, 11.122), 13);
      await tester.pumpAndSettle();
      expect(
        app.gateway.calls,
        hasLength(calls),
        reason: 'Camera movement alone does not query',
      );
      await tapKey(tester, 'map-pin-external_activity:${itemId(1)}');
      expect(find.byKey(const Key('map-cluster-choices')), findsOneWidget);
      await tapKey(tester, 'map-cluster-item-external_activity:${itemId(2)}');
      await tapKey(tester, 'external-map-selected');
      expect(app.router.state.uri.path, '/activities/external/${itemId(2)}');
      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, '/activities/map');
      expect(
        app.container.read(externalMapSessionProvider).camera.cameraLatitude,
        closeTo(46.075, 0.0001),
      );
      await tapKey(tester, 'map-return-list');
      expect(app.router.state.uri.path, '/activities');
      expect(
        app.container.read(externalActivitiesControllerProvider).filter.query,
        'court',
      );
      expect(app.provider.tileCalls, isEmpty);
      expect(app.provider.searches, isEmpty);
      expect(app.provider.resolutions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ACTMAP01 explicit area search shares filters; source disable removes pins; mode OFF has no new IO',
    (tester) async {
      final app = await pumpExternalMap(tester);
      await tapKey(tester, 'map-open-activities');
      final calls = app.gateway.calls.length;
      await tester.drag(
        find.byKey(const Key('public-point-map')),
        const Offset(45, 30),
      );
      await tester.pumpAndSettle();
      expect(app.gateway.calls, hasLength(calls));
      await tapKey(tester, 'external-map-search-area');
      expect(
        app.container.read(externalActivitiesControllerProvider).filter.area,
        isA<GeoBounds>(),
      );
      expect(
        app.gateway.calls.last.area!.toJson(),
        app.container
            .read(externalActivitiesControllerProvider)
            .filter
            .area!
            .toJson(),
      );
      app.gateway.onList = (_, _) async => externalPageFixture();
      await tapKey(tester, 'external-map-refresh');
      expect(
        find.byKey(Key('map-pin-external_activity:${itemId(1)}')),
        findsNothing,
      );
      final beforeOff = app.gateway.calls.length;
      await app.container
          .read(activitiesSplitPreferenceProvider.notifier)
          .select(ActivitiesSplitMode.off);
      await tester.pumpAndSettle();
      await app.container
          .read(externalActivitiesMapControllerProvider.notifier)
          .refresh();
      expect(app.gateway.calls, hasLength(beforeOff));
      expect(app.provider.tileCalls, isEmpty);
      expect(app.provider.searches, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ACTMAP01 late map response is discarded on background and account replacement',
    (tester) async {
      final pending = Completer<ExternalActivityPage>();
      final gateway = FakeExternalActivityGateway()
        ..onList = (filter, _) => filter.mappedOnly
            ? pending.future
            : Future.value(externalPageFixture());
      final app = await pumpExternalMap(tester, gateway: gateway);
      // Avoid pumpAndSettle while an intentional progress indicator is pending.
      app.router.push('/activities/map');
      await tester.pump();
      await tester.pump();
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      final count = gateway.calls.length;
      await app.container
          .read(externalActivitiesMapControllerProvider.notifier)
          .refresh();
      expect(gateway.calls, hasLength(count));
      app.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'different-account'));
      pending.complete(
        externalPageFixture(
          items: [item(1)],
          health: ExternalCatalogueHealth.healthy,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        app.container.read(externalActivitiesMapControllerProvider).page,
        isNull,
      );
      gateway.onList = (_, _) async => externalPageFixture();
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(app.provider.tileCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ACTMAP01 mixed kinds, locality precision and explicit Load more keep loaded counts and partial source health',
    (tester) async {
      final rows = [
        item(1, kind: 'event'),
        item(2, kind: 'course'),
        item(3),
        item(4, precision: 'locality'),
      ];
      final gateway = FakeExternalActivityGateway()
        ..onList = (filter, cursor) async => externalPageFixture(
          items: !filter.mappedOnly
              ? rows
              : cursor == null
              ? rows.take(2).toList()
              : rows.skip(2).toList(),
          health: cursor == null
              ? ExternalCatalogueHealth.healthy
              : ExternalCatalogueHealth.partial,
          cursor: filter.mappedOnly && cursor == null
              ? {'as_of': '2026-10-21T12:00:00Z', 'id': rows[1].id}
              : null,
          disciplines: ['basketball'],
        );
      final app = await pumpExternalMap(
        tester,
        gateway: gateway,
        filter: const ExternalActivityFilter(category: 'sports'),
      );
      await tapKey(tester, 'map-open-activities');
      expect(
        app.container.read(externalActivitiesMapControllerProvider).page!.items,
        hasLength(2),
      );
      await tapKey(tester, 'external-map-load-more');
      expect(
        app.container.read(externalActivitiesMapControllerProvider).page!.items,
        hasLength(4),
      );
      expect(
        app.container
            .read(externalActivitiesMapControllerProvider)
            .page!
            .health,
        ExternalCatalogueHealth.partial,
      );
      await tapKey(tester, 'map-pin-external_activity:${itemId(1)}');
      expect(find.byIcon(Icons.event_outlined), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(find.byIcon(Icons.sports), findsNWidgets(2));
      expect(app.provider.tileCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ACTMAP01 retains arbitrary valid shared radius without a dropdown assertion',
    (tester) async {
      final app = await pumpExternalMap(
        tester,
        filter: const ExternalActivityFilter(
          category: 'sports',
          kind: ExternalActivityKind.place,
          area: GeoRadius(46.0748, 11.1217, 3500),
        ),
      );
      await tapKey(tester, 'map-open-activities');
      expect((app.gateway.calls.last.area as GeoRadius).radiusMeters, 3500);
      expect(
        app.container.read(externalMapSessionProvider).camera.radiusKm,
        3.5,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final status in ['empty', 'error', 'partial', 'stale']) {
        testWidgets('ACTMAP01 difficult $status $language dark=$dark 2x', (
          tester,
        ) async {
          tester.view.physicalSize = Size(language == 'it' ? 320 : 360, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final gateway = FakeExternalActivityGateway();
          gateway.page = externalPageFixture(
            items: status == 'empty' || status == 'error' ? [] : [item(1)],
            health: switch (status) {
              'empty' => ExternalCatalogueHealth.empty,
              'partial' => ExternalCatalogueHealth.partial,
              'stale' => ExternalCatalogueHealth.stale,
              _ => ExternalCatalogueHealth.healthy,
            },
            disciplines: ['basketball'],
          );
          if (status == 'error') {
            gateway.error = StateError('Synthetic backend failure');
          }
          final app = await pumpExternalMap(
            tester,
            gateway: gateway,
            language: language,
            dark: dark,
            scale: 2,
          );
          await tapKey(tester, 'map-open-activities');
          await RenderedEvidence.capture(
            tester,
            'actmap01-$status-$language-${dark ? 'dark' : 'light'}-top',
          );
          final l = AppLocalizations.of(
            tester.element(find.byType(ExternalActivitiesMapScreen)),
          );
          final message = find.text(switch (status) {
            'empty' => l.activitiesMapEmpty,
            'error' => l.activitiesExternalReadFailed,
            'partial' => l.activitiesExternalPartial,
            _ => l.activitiesExternalStale,
          });
          await tester.ensureVisible(message);
          await tester.pumpAndSettle();
          if (status == 'error') {
            expect(
              app.container
                  .read(externalActivitiesMapControllerProvider)
                  .failed,
              isTrue,
            );
          }
          await RenderedEvidence.capture(
            tester,
            'actmap01-$status-$language-${dark ? 'dark' : 'light'}-status',
          );
          expect(app.provider.tileCalls, isEmpty);
          expect(app.provider.searches, isEmpty);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final language in ['en', 'it']) {
    for (final dark in [false, true]) {
      testWidgets(
        'ACTMAP01 narrow rendered $language dark=$dark 2x no basemap',
        (tester) async {
          tester.view.physicalSize = Size(language == 'it' ? 320 : 360, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final app = await pumpExternalMap(
            tester,
            language: language,
            dark: dark,
            scale: 2,
          );
          await tapKey(tester, 'map-open-activities');
          await RenderedEvidence.capture(
            tester,
            'actmap01-$language-${dark ? 'dark' : 'light'}-top',
          );
          await tapKey(tester, 'map-pin-external_activity:${itemId(1)}');
          await RenderedEvidence.capture(
            tester,
            'actmap01-$language-${dark ? 'dark' : 'light'}-cluster',
          );
          await tapKey(
            tester,
            'map-cluster-item-external_activity:${itemId(2)}',
          );
          await RenderedEvidence.capture(
            tester,
            'actmap01-$language-${dark ? 'dark' : 'light'}-selected',
          );
          expect(app.provider.tileCalls, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
