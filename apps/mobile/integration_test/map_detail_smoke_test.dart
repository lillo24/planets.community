import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/features/geographic_discovery/application/shared_basemap_tiles.dart';
import 'package:planets_mobile/features/geographic_discovery/data/map_provider_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/read_only_basemap.dart';
import 'package:planets_mobile/features/locations/data/location_preview_gateway.dart';
import 'package:planets_mobile/features/locations/domain/location_preview.dart';
import 'package:planets_mobile/features/locations/presentation/location_attribution.dart';

import '../test/support/fake_location_preview.dart';
import '../test_support/map05_app_fixture.dart';
import '../test_support/map_discovery_fixture.dart';

class _NoNetwork extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('MAPFIX02 synthetic detail forbids network IO.');
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native synthetic detail respects both compiled map gates', (
    tester,
  ) async {
    const tiles = bool.fromEnvironment('LOCATION_MAP_TILES_ENABLED');
    const detail = bool.fromEnvironment('LOCATION_DETAIL_TILES_ENABLED');
    final network = _NoNetwork();
    final app = Map05AppFixture(tilesEnabled: tiles);
    final previews = app.container.read(
      locationPreviewGatewayProvider,
    ) as FakePreviewGateway;
    final statics = app.container.read(
      staticPreviewGatewayProvider,
    ) as FakeStaticPreviewGateway;
    final id = mapFixtureId(1);
    var manual = false;
    previews.pending = (item, _) async => LocationPreview(
      item: item,
      revision: manual ? 2 : 1,
      isProtected: false,
      publicLabel: 'Trento',
      textSource: manual ? 'manual' : 'geoapify',
      legacy: const LegacyPreviewArea('Trento', 'IT'),
      place: manual
          ? null
          : const PreviewPlace(
              'locality',
              'Synthetic Trento area',
              46.0748,
              11.1217,
              locality: 'Trento',
            ),
    );
    HttpOverrides.global = network;
    addTearDown(() {
      HttpOverrides.global = null;
      app.dispose();
    });

    Future<void> open() async {
      app.router.go('/proposals/$id');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(Key('location-preview-$id')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> close() async {
      app.router.go('/proposals');
      await tester.pumpAndSettle();
      app.container.read(sharedBasemapTilesProvider).clear();
    }

    await tester.pumpWidget(app.app);
    await open();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    if (tiles && detail) {
      final map = find.byType(ReadOnlyBasemap);
      expect(map, findsOneWidget);
      final widget = tester.widget<ReadOnlyBasemap>(map);
      expect(widget.approximate, isTrue);
      expect(widget.protected, isFalse);
      // The action wrapper adds padding around the 144dp tile canvas.
      final canvas = find.descendant(
        of: map,
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 144,
        ),
      );
      expect(tester.getSize(canvas).height, 144);
      expect(tester.state<ReadOnlyBasemapState>(map).debugImages, isNotEmpty);
      expect(find.byKey(Key('location-open-maps-$id')), findsNothing);
      expect(app.provider.tileCalls, isNotEmpty);
    } else {
      expect(find.byType(ReadOnlyBasemap), findsNothing);
      expect(find.byKey(Key('location-open-maps-$id')), findsOneWidget);
      expect(app.provider.tileCalls, isEmpty);
    }
    await binding.takeScreenshot('map05-synthetic-detail-en-$tiles-$detail');
    await close();
    app.themeMode = ThemeMode.dark;
    app.textScale = 2;
    app.locale.value = const Locale('it');
    await open();
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('map05-synthetic-detail-it-dark-2x');

    await close();
    app.provider.failure = const MapProviderFailure('budget_exhausted');
    await open();
    expect(find.byKey(Key('location-open-maps-$id')), findsOneWidget);
    expect(find.byType(LocationAttribution), findsNothing);
    await binding.takeScreenshot('map05-synthetic-detail-budget-fallback');

    await close();
    manual = true;
    app.provider.failure = null;
    final calls = app.provider.tileCalls.length;
    await open();
    expect(find.byType(ReadOnlyBasemap), findsNothing);
    expect(app.provider.tileCalls.length, calls);
    expect(find.byKey(Key('location-open-maps-$id')), findsOneWidget);
    expect(statics.calls, 0);
    expect(network.attempts, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
