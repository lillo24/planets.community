import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:planets_mobile/features/geographic_discovery/data/budget_basemap_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/application/budget_basemap_tiles.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/basemap_fallback.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/basemap_tile.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/geographic_discovery.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/budget_tile_provider.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/public_point_map.dart';
import 'package:planets_mobile/features/locations/presentation/location_attribution.dart';

import '../../../test_support/map05_app_fixture.dart';
import '../../../test_support/map_discovery_fixture.dart';
import '../../support/rendered_evidence.dart';

class _Server implements BudgetBasemapGateway {
  final fixture = FixtureMapProviderGateway(tilesEnabled: true);
  final ready = <BasemapTileId, Uint8List>{};
  bool exhausted = false;
  int calls = 0, upstream = 0;
  @override
  Future<BudgetBasemapFrame> tile(
    BasemapTileId id, {
    required bool cacheOnly,
    required Future<void> cancellation,
  }) async {
    calls++;
    var source = id;
    if (!ready.containsKey(id)) {
      if (exhausted || cacheOnly) {
        final parent = trentoBaselineAncestor(id);
        if (parent == null || !ready.containsKey(parent)) {
          throw BudgetBasemapFailure(
            cacheOnly ? 'cache_miss' : 'budget_exhausted',
            retryAfter: const Duration(hours: 1),
          );
        }
        source = parent;
      } else {
        upstream++;
        ready[id] = await fixture.tile(id.z, id.x, id.y);
      }
    }
    return BudgetBasemapFrame(
      source: source,
      bytes: ready[source]!,
      expiresAt: DateTime.utc(2026, 10, 27),
      validFor: const Duration(days: 7),
      budgetExhausted: exhausted && !cacheOnly,
      retryAfter: const Duration(hours: 1),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await RenderedEvidence.loadFonts(force: true);
  });
  for (final locale in ['en', 'it']) {
    for (final large in [false, true]) {
      testWidgets(
        '$locale ${large ? 'dark 2x' : 'light'} Trento to Povo keeps geographic search and partial imagery',
        (tester) async {
          tester.view.physicalSize = Size(large ? 320 : 390, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final server = _Server();
          final app = Map05AppFixture(budget: server)
            ..locale.value = Locale(locale)
            ..textScale = large ? 2 : 1
            ..themeMode = large ? ThemeMode.dark : ThemeMode.light;
          addTearDown(app.dispose);
          await tester.pumpWidget(RenderedEvidence.wrap(app.app));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('map-open-projects')));
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pumpAndSettle();
          expect(server.upstream, 12);
          expect(find.byType(LocationAttribution), findsOneWidget);
          final map = tester.widget<PublicPointMap>(
            find.byType(PublicPointMap),
          );
          expect(map.tileProvider, isA<BudgetTileProvider>());
          if (!large && locale == 'en') {
            await RenderedEvidence.capture(tester, 'synthetic-trento-normal');
          }
          server.exhausted = true;
          final searches = app.geography.calls.length;
          map.controller.move(const LatLng(46.066, 11.15), 14.5);
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pumpAndSettle();
          expect(server.upstream, 12);
          expect(app.geography.calls.length, searches);
          expect(
            find.text(
              locale == 'it'
                  ? 'Mappa a dettaglio ridotto'
                  : 'Reduced-detail map',
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(find.byKey(const Key('public-point-map')));
          await tester.drag(
            find.byKey(const Key('public-point-map')),
            const Offset(-40, 10),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const Key('map-search-area')));
          await tester.tap(find.byKey(const Key('map-search-area')));
          await tester.pumpAndSettle();
          expect(app.geography.calls.last.query.area, isA<GeoBounds>());
          expect(
            tester
                .widget<PublicPointMap>(find.byType(PublicPointMap))
                .preferences
                .cameraLongitude,
            closeTo(map.controller.camera.center.longitude, 0.00000001),
          );
          if (!large && locale == 'en') {
            await RenderedEvidence.capture(tester, 'synthetic-povo-reduced');
          }
          if (large && locale == 'it') {
            await RenderedEvidence.capture(tester, 'synthetic-povo-it-dark-2x');
          }
          // A missing child/parent cannot dispose other authorized images or pins.
          final provider = tester
              .widget<PublicPointMap>(find.byType(PublicPointMap))
              .tileProvider;
          map.controller.move(const LatLng(46.066, 11.40), 14.5);
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<PublicPointMap>(find.byType(PublicPointMap))
                .tileProvider,
            same(provider),
          );
          expect(server.upstream, 12);
          if (!large && locale == 'en') {
            await RenderedEvidence.capture(
              tester,
              'synthetic-missing-coverage',
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          app.container.read(budgetBasemapTilesProvider).clear();
        },
      );
    }
  }
}
