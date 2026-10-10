import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/geographic_discovery/application/shared_basemap_tiles.dart';
import 'package:planets_mobile/features/geographic_discovery/data/map_provider_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/map_discovery.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/public_point_map.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/read_only_basemap.dart';
import 'package:planets_mobile/features/locations/data/location_preview_gateway.dart';
import 'package:planets_mobile/features/locations/domain/location_preview.dart';
import 'package:planets_mobile/features/locations/presentation/location_preview_panel.dart';
import 'package:planets_mobile/features/locations/presentation/location_attribution.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/participation/application/participation_controllers.dart';
import 'package:planets_mobile/features/project_delegates/application/project_delegate_controllers.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/participation/presentation/project_participation_section.dart';
import 'package:planets_mobile/features/resource_listings/presentation/resource_listing_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../test_support/map_discovery_fixture.dart';
import '../../support/fake_location_preview.dart';
import '../../support/fake_participation.dart';

LocationPreview projection(
  PreviewItem item, {
  bool protected = false,
  bool exact = false,
  double lat = 46.0748,
  int revision = 1,
}) => LocationPreview(
  item: item,
  revision: revision,
  isProtected: protected,
  place: PreviewPlace(
    exact ? 'address' : 'locality',
    protected ? 'SECRET venue' : 'Synthetic Trento',
    lat,
    11.1217,
  ),
  imageKey: 'a' * 64,
);
Widget shell(
  ProviderContainer c,
  Widget body, {
  String language = 'en',
  double scale = 1,
  GlobalKey<NavigatorState>? navigatorKey,
}) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    navigatorKey: navigatorKey,
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (_, child) => MediaQuery(
      data: MediaQueryData(
        size: const Size(320, 800),
        textScaler: TextScaler.linear(scale),
        padding: const EdgeInsets.only(bottom: 24),
        viewInsets: const EdgeInsets.only(bottom: 80),
      ),
      child: child!,
    ),
    home: Scaffold(body: SafeArea(child: body)),
  ),
);
Widget panel(PreviewItem item, {Object? version}) => LocationPreviewPanel(
  key: ValueKey(item.key),
  item: item,
  publicLabel: 'Public area',
  legacy: const LegacyPreviewArea('Trento', 'IT'),
  detail: true,
  contentVersion: version,
);
Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  await t.pumpAndSettle();
  // Native PNG codecs complete outside the widget tester's fake clock.
  for (
    var n = 0;
    n < 100 &&
        find.byType(ReadOnlyBasemap).evaluate().isNotEmpty &&
        find.byKey(const Key('public-detail-overlay')).evaluate().isEmpty &&
        find.byKey(const Key('protected-detail-overlay')).evaluate().isEmpty;
    n++
  ) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump();
  }
}

ProviderContainer setup(
  FixtureMapProviderGateway tiles,
  LocationPreviewGateway preview,
  FakeStaticPreviewGateway static, {
  bool detailEnabled = true,
  Duration ttl = const Duration(minutes: 1),
}) => ProviderContainer(
  overrides: [
    mapProviderGatewayProvider.overrideWithValue(tiles),
    basemapCacheTtlProvider.overrideWithValue(ttl),
    detailBasemapEnabledProvider.overrideWithValue(detailEnabled),
    locationPreviewGatewayProvider.overrideWithValue(preview),
    staticPreviewGatewayProvider.overrideWithValue(static),
    previewMapsLauncherProvider.overrideWithValue(FakePreviewMapsLauncher()),
    ownParticipationProvider.overrideWith(_MutableParticipation.new),
    projectManagementRoleProvider.overrideWith(_MutableRole.new),
    participantMeetingDetailsProvider.overrideWith(_MutableMeeting.new),
  ],
);

class DelayedTiles extends FixtureMapProviderGateway {
  DelayedTiles() : super(tilesEnabled: true);
  final pending = <Completer<Uint8List>>[];
  final outputs = <Uint8List>[];
  @override
  Future<Uint8List> tile(int z, int x, int y, {Future<void>? cancellation}) {
    tileCalls.add((z, x, y));
    final complete = Completer<Uint8List>();
    pending.add(complete);
    return complete.future;
  }

  Future<void> finish() async {
    // Completing the active six jobs can start queued demand in the same frame.
    while (pending.any((p) => !p.isCompleted)) {
      for (final p in pending.where((p) => !p.isCompleted).toList()) {
        final bytes = await FixtureMapProviderGateway().tile(12, 2174, 1456);
        outputs.add(bytes);
        p.complete(bytes);
      }
      await Future<void>.value();
    }
  }
}

class _MutableParticipation extends OwnParticipationController {
  void withdraw() => state = const OwnParticipationState(
    phase: ParticipationLoadPhase.failure,
  );
}

class _MutableRole extends ProjectManagementRoleController {
  void withdraw() => state = const ProjectManagementRoleState(
    phase: ProjectDelegateLoadPhase.failure,
  );
}

class _MutableMeeting extends ParticipantMeetingDetailsController {
  void withdraw() => state = const ParticipantMeetingDetailsState(
    phase: ParticipationLoadPhase.failure,
  );
}

void main() {
  setUp(
    () => TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed),
  );
  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed),
  );
  testWidgets('public pixels survive both 15s/30s canonical lease renewals', (
    t,
  ) async {
    final tiles = FixtureMapProviderGateway(tilesEnabled: true);
    final previews = FakePreviewGateway()
      ..pending = (item, _) async => projection(item);
    final c = setup(tiles, previews, FakeStaticPreviewGateway());
    addTearDown(c.dispose);
    await t.pumpWidget(
      shell(c, ListView(children: [panel(const PreviewItem('one_time', 'A'))])),
    );
    await settle(t);
    final state = t.state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap));
    final images = state.debugImages;
    final calls = tiles.tileCalls.length;
    for (var tick = 0; tick < 2; tick++) {
      final renewal = Completer<LocationPreview?>();
      previews.pending = (_, _) => renewal.future;
      await t.pump(const Duration(seconds: 15));
      await t.pump();
      expect(images.every((image) => !image.debugDisposed), true);
      expect(find.byKey(const Key('public-detail-overlay')), findsOneWidget);
      renewal.complete(projection(const PreviewItem('one_time', 'A')));
      await settle(t);
      expect(
        t.state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap)),
        same(state),
      );
      expect(tiles.tileCalls.length, calls);
    }
    expect(previews.reads, 3);
    await t.pumpWidget(const SizedBox());
    c.read(sharedBasemapTilesProvider).clear();
  });
  testWidgets(
    'zero-retention public view survives renewal and inactive without fresh tile requests',
    (t) async {
      final tiles = FixtureMapProviderGateway(tilesEnabled: true);
      final previews = FakePreviewGateway()
        ..pending = (item, _) async => projection(item);
      final c = setup(
        tiles,
        previews,
        FakeStaticPreviewGateway(),
        ttl: Duration.zero,
      );
      addTearDown(c.dispose);
      await t.pumpWidget(
        shell(
          c,
          ListView(children: [panel(const PreviewItem('one_time', 'A'))]),
        ),
      );
      await settle(t);
      final images = t
          .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
          .debugImages;
      final calls = tiles.tileCalls.length;
      expect(c.read(sharedBasemapTilesProvider).count, 0);
      await t.pump(const Duration(seconds: 30));
      await settle(t);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(images.every((image) => !image.debugDisposed), true);
      expect(tiles.tileCalls.length, calls);
      expect(find.byKey(const Key('location-map-action-A')), findsOneWidget);
      expect(c.read(sharedBasemapTilesProvider).count, 0);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'authorized RPC public-area fallback keeps public ownership through renewals',
    (t) async {
      final tiles = FixtureMapProviderGateway(tilesEnabled: true);
      final views = <String>[];
      final gateway = RpcLocationPreviewGateway((_, args) async {
        final view = args['p_view'] as String;
        views.add(view);
        return {
          'item_kind': 'one_time',
          'item_id': 'A',
          'revision': 1,
          'scope': 'area',
          'audience': view == 'protected_detail' ? 'protected' : 'public',
          'image_key': 'a' * 64,
          'place': {
            'kind': 'locality',
            'label': 'Synthetic area',
            'latitude': 46,
            'longitude': 11,
          },
          'legacy': {'locality': 'Trento', 'country_code': 'IT'},
        };
      });
      final c = setup(tiles, gateway, FakeStaticPreviewGateway());
      addTearDown(c.dispose);
      c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'Alice'));
      await t.pumpWidget(
        shell(
          c,
          ListView(children: [panel(const PreviewItem('one_time', 'A'))]),
        ),
      );
      await settle(t);
      final images = t
          .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
          .debugImages;
      final calls = tiles.tileCalls.length;
      for (var n = 0; n < 2; n++) {
        await t.pump(const Duration(seconds: 15));
        await settle(t);
        expect(images.every((image) => !image.debugDisposed), true);
      }
      expect(views, [
        'protected_detail',
        'public_detail',
        'protected_detail',
        'public_detail',
        'protected_detail',
        'public_detail',
      ]);
      expect(find.byKey(const Key('public-detail-overlay')), findsOneWidget);
      expect(tiles.tileCalls.length, calls);
      await t.pumpWidget(const SizedBox());
      c.read(sharedBasemapTilesProvider).clear();
    },
  );
  for (final signal in ['participation', 'role', 'meeting']) {
    testWidgets('public pixels remain stable during $signal revalidation', (
      t,
    ) async {
      final tiles = FixtureMapProviderGateway(tilesEnabled: true);
      final previews = FakePreviewGateway()
        ..pending = (item, _) async => projection(item);
      final c = setup(tiles, previews, FakeStaticPreviewGateway());
      addTearDown(c.dispose);
      await t.pumpWidget(
        shell(
          c,
          ListView(children: [panel(const PreviewItem('one_time', 'A'))]),
        ),
      );
      await settle(t);
      final images = t
          .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
          .debugImages;
      final calls = tiles.tileCalls.length;
      if (signal == 'participation') {
        (c.read(ownParticipationProvider.notifier) as _MutableParticipation)
            .withdraw();
      } else if (signal == 'role') {
        (c.read(projectManagementRoleProvider.notifier) as _MutableRole)
            .withdraw();
      } else {
        (c.read(participantMeetingDetailsProvider.notifier) as _MutableMeeting)
            .withdraw();
      }
      expect(images.every((image) => !image.debugDisposed), true);
      await settle(t);
      expect(find.byKey(const Key('location-map-action-A')), findsOneWidget);
      expect(previews.reads, 2);
      expect(tiles.tileCalls.length, calls);
      await t.pumpWidget(const SizedBox());
      c.read(sharedBasemapTilesProvider).clear();
    });
  }
  for (final changed in [false, true]) {
    testWidgets(
      'public canonical ${changed ? 'change' : 'failure'} ends the old rendered scope',
      (t) async {
        final tiles = FixtureMapProviderGateway(tilesEnabled: true);
        const item = PreviewItem('one_time', 'A');
        final previews = FakePreviewGateway()
          ..pending = (item, _) async => projection(item);
        final c = setup(tiles, previews, FakeStaticPreviewGateway());
        addTearDown(c.dispose);
        await t.pumpWidget(shell(c, ListView(children: [panel(item)])));
        await settle(t);
        final images = t
            .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
            .debugImages;
        previews.pending = (_, _) async => changed
            ? projection(item, lat: 47, revision: 2)
            : throw const PreviewUnavailable();
        await t.pump(const Duration(seconds: 15));
        await settle(t);
        expect(images.every((image) => image.debugDisposed), true);
        expect(
          find.byKey(const Key('location-map-action-A')),
          changed ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Map preview unavailable'),
          changed ? findsNothing : findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
        c.read(sharedBasemapTilesProvider).clear();
      },
    );
  }
  testWidgets(
    'screenshot-like inactive/resumed keeps public decoded pixels and tile requests',
    (t) async {
      final tiles = FixtureMapProviderGateway(tilesEnabled: true);
      final previews = FakePreviewGateway()
        ..pending = (item, _) async => projection(item);
      final c = setup(tiles, previews, FakeStaticPreviewGateway());
      addTearDown(c.dispose);
      await t.pumpWidget(
        shell(
          c,
          ListView(children: [panel(const PreviewItem('one_time', 'A'))]),
        ),
      );
      await settle(t);
      final images = t
          .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
          .debugImages;
      final calls = tiles.tileCalls.length;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(images.every((image) => !image.debugDisposed), true);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(find.byKey(const Key('public-detail-overlay')), findsOneWidget);
      expect(tiles.tileCalls.length, calls);
      await t.pumpWidget(const SizedBox());
      c.read(sharedBasemapTilesProvider).clear();
    },
  );
  test(
    'normal registrations keep detail, tile, center, static and retention off',
    () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(detailBasemapEnabledProvider), false);
      expect(c.read(basemapCacheTtlProvider), Duration.zero);
      expect(c.read(staticPreviewGatewayProvider).enabled, false);
      expect(c.read(mapProviderGatewayProvider).tilesEnabled, false);
      expect(c.read(mapProviderGatewayProvider).centerEnabled, false);
      await expectLater(
        c
            .read(sharedBasemapTilesProvider)
            .openScope()
            .tile(const BasemapTileId(12, 2174, 1456)),
        throwsA(isA<MapProviderFailure>()),
      );
    },
  );
  testWidgets(
    'learned provider shutoff destroys warm detail pixels without static fallback',
    (t) async {
      final tiles = FixtureMapProviderGateway(tilesEnabled: true),
          static = FakeStaticPreviewGateway();
      final previews = FakePreviewGateway()
        ..pending = (item, _) async => projection(item);
      final c = setup(tiles, previews, static);
      addTearDown(c.dispose);
      await t.pumpWidget(
        shell(
          c,
          ListView(children: [panel(const PreviewItem('one_time', 'A'))]),
        ),
      );
      await settle(t);
      final images = t
          .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
          .debugImages;
      expect(images, isNotEmpty);
      tiles.failure = const MapProviderFailure('disabled');
      final store = c.read(sharedBasemapTilesProvider);
      await expectLater(
        store.openScope().tile(const BasemapTileId(12, 0, 0)),
        throwsA(isA<MapProviderFailure>()),
      );
      expect(images.every((image) => image.debugDisposed), true);
      await settle(t);
      expect(find.byKey(const Key('public-detail-overlay')), findsNothing);
      expect(store.count, 0);
      expect(store.enabled, false);
      expect(static.calls, 0);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'real discovery TileLayer -> Project A/B -> Tavolo -> public precise Resource -> Map shares once',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final tiles = FixtureMapProviderGateway(tilesEnabled: true),
          static = FakeStaticPreviewGateway();
      final previews = FakePreviewGateway()
        ..pending = (item, _) async =>
            projection(item, exact: item.kind == 'resource');
      final c = setup(tiles, previews, static);
      addTearDown(c.dispose);
      final store = c.read(sharedBasemapTilesProvider);
      Future<void> map() async {
        final controller = MapController(),
            provider = GatewayTileProvider(store);
        await t.pumpWidget(
          shell(
            c,
            SizedBox(
              height: 400,
              child: PublicPointMap(
                controller: controller,
                preferences: MapDiscoveryPreferences(
                  MapDiscoveryOrigin.projects,
                ),
                clusters: const [],
                tileProvider: provider,
                onCamera: (_, _, _, _, _) {},
                onCluster: (_) {},
                onTileError: () => fail('synthetic tile failed'),
                markerLabel: (_) => '',
                clusterLabel: (_) => '',
              ),
            ),
          ),
        );
        await settle(t);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        provider.dispose();
        controller.dispose();
      }

      await map();
      final initial = tiles.tileCalls.toSet();
      expect(initial, isNotEmpty);
      for (final item in [
        const PreviewItem('one_time', 'A'),
        const PreviewItem('one_time', 'B'),
        const PreviewItem('recurring', 'T'),
        const PreviewItem('resource', 'R'),
        const PreviewItem('one_time', 'A'),
      ]) {
        final Widget detail = item.kind == 'resource'
            ? ResourceListingLocation(
                listingId: item.id,
                publicLocationLabel: 'Public area',
                locality: 'Trento',
                administrativeArea: null,
                countryCode: 'IT',
              )
            : ProjectParticipationSection(
                projectId: item.id,
                projectKind: item.kind == 'recurring'
                    ? ProjectKind.recurring
                    : ProjectKind.oneTime,
                creatorProfileId: 'creator',
                acceptsNewRequests: true,
                publicLocationLines: const ['Public area'],
                publicExactMeetingText: null,
                exactLocationRestricted: false,
                capacity: capacityFixture(),
                previewArea: const LegacyPreviewArea('Trento', 'IT'),
              );
        await t.pumpWidget(shell(c, ListView(children: [detail])));
        await settle(t);
        expect(find.byKey(const Key('public-detail-overlay')), findsOneWidget);
        expect(find.byType(LocationAttribution), findsOneWidget);
        expect(find.byKey(Key('location-open-maps-${item.id}')), findsNothing);
        expect(
          find.byKey(Key('location-map-action-${item.id}')),
          findsOneWidget,
        );
        expect(tiles.tileCalls.toSet().difference(initial), isEmpty);
        expect(tiles.tileCalls.length, initial.length);
        await t.pumpWidget(const SizedBox());
      }
      await map();
      expect(tiles.tileCalls.length, initial.length);
      expect(static.calls, 0);
      // ignore: avoid_print
      print(
        'CACHE01 actual widgets gateway=${tiles.tileCalls.length} unique=${initial.length} bytes=${store.byteCount} static=${static.calls}',
      );
      store.clear();
    },
  );
  testWidgets(
    'public overlay changes and rebuilds in the same grid issue no additional requests',
    (t) async {
      final tiles = FixtureMapProviderGateway(tilesEnabled: true),
          static = FakeStaticPreviewGateway();
      var lat = 46.0748;
      final previews = FakePreviewGateway()
        ..pending = (item, _) async => projection(item, exact: true, lat: lat);
      final c = setup(tiles, previews, static);
      addTearDown(c.dispose);
      const item = PreviewItem('resource', 'R');
      await t.pumpWidget(shell(c, ListView(children: [panel(item)])));
      await settle(t);
      final calls = tiles.tileCalls.length;
      lat += 0.00001;
      await t.pumpWidget(
        shell(c, ListView(children: [panel(item, version: 2)])),
      );
      await settle(t);
      expect(tiles.tileCalls.length, calls);
      expect(static.calls, 0);
      await t.pumpWidget(const SizedBox());
      c.read(sharedBasemapTilesProvider).clear();
    },
  );
  for (final mode in ['all-off', 'guest', 'tile-failure', 'legacy']) {
    testWidgets(
      '$mode keeps honest text/action without static fallback or blank disabled region',
      (t) async {
        final tiles = FixtureMapProviderGateway(
          tilesEnabled: mode != 'all-off',
          requiresAuthentication: mode == 'guest',
        );
        if (mode == 'tile-failure') {
          tiles.failure = const MapProviderFailure('unavailable');
        }
        final previews = FakePreviewGateway()
          ..pending = (item, _) async => mode == 'legacy'
              ? LocationPreview(
                  item: item,
                  revision: 1,
                  isProtected: false,
                  legacy: const LegacyPreviewArea('Trento', 'IT'),
                )
              : projection(item);
        final static = FakeStaticPreviewGateway();
        final c = setup(tiles, previews, static);
        addTearDown(c.dispose);
        c.read(authSessionProvider.notifier).markSignedOut();
        await t.pumpWidget(
          shell(
            c,
            ListView(children: [panel(const PreviewItem('one_time', 'A'))]),
          ),
        );
        await settle(t);
        expect(find.byKey(const Key('location-open-maps-A')), findsOneWidget);
        expect(find.byKey(const Key('location-map-action-A')), findsNothing);
        expect(find.byKey(const Key('public-detail-overlay')), findsNothing);
        if (mode != 'tile-failure') {
          expect(tiles.tileCalls, isEmpty);
          expect(find.byType(ReadOnlyBasemap), findsNothing);
        }
        expect(static.calls, 0);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language 320px 2x credits, semantics, keyboard, parent scroll and one Maps action',
      (t) async {
        await t.binding.setSurfaceSize(const Size(320, 800));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final semantics = t.ensureSemantics();
        final tiles = FixtureMapProviderGateway(tilesEnabled: true),
            static = FakeStaticPreviewGateway();
        final previews = FakePreviewGateway()
          ..pending = (item, _) async => projection(item);
        final c = setup(tiles, previews, static);
        addTearDown(c.dispose);
        final scroll = ScrollController();
        await t.pumpWidget(
          shell(
            c,
            ListView(
              controller: scroll,
              children: [
                panel(const PreviewItem('one_time', 'A')),
                const SizedBox(height: 1200),
              ],
            ),
            language: language,
            scale: 2,
          ),
        );
        await settle(t);
        expect(find.byKey(const Key('public-detail-overlay')), findsOneWidget);
        expect(find.byType(LocationAttribution), findsOneWidget);
        final maps = find.byKey(const Key('location-map-action-A'));
        expect(maps, findsOneWidget);
        expect(find.byKey(const Key('location-open-maps-A')), findsNothing);
        expect(t.getSize(maps).height, greaterThanOrEqualTo(144));
        final data = t.getSemantics(maps).getSemanticsData();
        expect(data.flagsCollection.isLink, true);
        expect(data.flagsCollection.isButton, true);
        expect(data.label, contains('Synthetic Trento'));
        expect(
          data.label,
          contains(
            language == 'en' ? 'Open in Google Maps' : 'Apri in Google Maps',
          ),
        );
        final credits = find.byKey(const Key('location-attribution'));
        expect(t.getRect(credits).top, t.getRect(maps).bottom);
        for (final provider in ['geoapify', 'osm']) {
          final link = find.byKey(Key('location-attribution-$provider'));
          expect(t.getSize(link).height, greaterThanOrEqualTo(48));
          expect(t.getRect(link).right, lessThanOrEqualTo(320));
          expect(t.getRect(link).left, greaterThanOrEqualTo(0));
        }
        // The compact credit group is centered, including at 2x text.
        final left = t
            .getRect(find.byKey(const Key('location-attribution-geoapify')))
            .left;
        final right = t
            .getRect(find.byKey(const Key('location-attribution-osm')))
            .right;
        expect((left + right) / 2, closeTo(160, 0.1));
        final launcher =
            c.read(previewMapsLauncherProvider) as FakePreviewMapsLauncher;
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(t);
        expect(launcher.urls.length, 1);
        expect(previews.reads, 2);
        expect(launcher.urls.single.queryParameters['map_action'], 'map');
        // IgnorePointer deliberately lets the parent ListView receive this drag.
        await t.dragFrom(
          t.getCenter(find.byType(ReadOnlyBasemap)),
          const Offset(0, -100),
        );
        await settle(t);
        expect(scroll.offset, greaterThan(0));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        scroll.dispose();
        semantics.dispose();
        c.read(sharedBasemapTilesProvider).clear();
      },
    );
  }
  for (final reason in [
    'lease',
    'background',
    'account-ABA',
    'sign-out',
    'route',
  ]) {
    testWidgets(
      'protected $reason drops pixels and private buffers; late tile cannot resurrect',
      (t) async {
        final tiles = DelayedTiles(), static = FakeStaticPreviewGateway();
        var entitled = true;
        final previews = FakePreviewGateway()
          ..pending = (item, _) async =>
              entitled ? projection(item, protected: true, exact: true) : null;
        final c = setup(tiles, previews, static);
        addTearDown(c.dispose);
        final auth = c.read(authSessionProvider.notifier);
        auth.markProfileReady(const AuthIdentity(id: 'Alice'));
        await t.pumpWidget(
          shell(
            c,
            ListView(children: [panel(const PreviewItem('one_time', 'A'))]),
          ),
        );
        await settle(t);
        expect(find.text('SECRET venue'), findsOneWidget);
        expect(tiles.pending, isNotEmpty);
        entitled = false;
        if (reason == 'lease') {
          await t.pump(const Duration(seconds: 15));
        }
        if (reason == 'background') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          await t.pump();
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          await t.pump();
        }
        if (reason == 'account-ABA') {
          auth.markProfileReady(const AuthIdentity(id: 'Bob'));
          await t.pump();
          auth.markProfileReady(const AuthIdentity(id: 'Alice'));
          await t.pump();
        }
        if (reason == 'sign-out') {
          auth.markSignedOut();
          await t.pump();
        }
        if (reason == 'route') await t.pumpWidget(const SizedBox());
        await tiles.finish();
        await settle(t);
        expect(find.text('SECRET venue'), findsNothing);
        expect(find.byKey(const Key('protected-detail-overlay')), findsNothing);
        expect(c.read(sharedBasemapTilesProvider).count, 0);
        expect(
          tiles.outputs.every((bytes) => bytes.every((n) => n == 0)),
          true,
        );
        expect(static.calls, 0);
        if (reason == 'background') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'displayed protected pixels revoke immediately; fresh entitlement needed on resume',
    (t) async {
      final tiles = FixtureMapProviderGateway(tilesEnabled: true),
          static = FakeStaticPreviewGateway();
      final previews = FakePreviewGateway()
        ..pending = (item, _) async =>
            projection(item, protected: true, exact: true);
      final c = setup(tiles, previews, static);
      addTearDown(c.dispose);
      c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'Alice'));
      await t.pumpWidget(
        shell(
          c,
          ListView(children: [panel(const PreviewItem('recurring', 'T'))]),
        ),
      );
      await settle(t);
      expect(find.byKey(const Key('protected-detail-overlay')), findsOneWidget);
      expect(c.read(sharedBasemapTilesProvider).count, 0);
      final images = t
          .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
          .debugImages;
      expect(images, isNotEmpty);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(images.every((image) => image.debugDisposed), true);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      expect(find.byKey(const Key('protected-detail-overlay')), findsNothing);
      final reads = previews.reads;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(previews.reads, greaterThan(reads));
      expect(find.byKey(const Key('protected-detail-overlay')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      c.read(sharedBasemapTilesProvider).clear();
    },
  );
  testWidgets(
    'protected 15s/30s renewals destroy pixels before either delayed canonical read',
    (t) async {
      final tiles = FixtureMapProviderGateway(tilesEnabled: true);
      const item = PreviewItem('one_time', 'A');
      final previews = FakePreviewGateway()
        ..pending = (item, _) async =>
            projection(item, protected: true, exact: true);
      final c = setup(tiles, previews, FakeStaticPreviewGateway());
      addTearDown(c.dispose);
      c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'Alice'));
      await t.pumpWidget(shell(c, ListView(children: [panel(item)])));
      await settle(t);
      for (var n = 0; n < 2; n++) {
        final images = t
            .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
            .debugImages;
        final renewal = Completer<LocationPreview?>();
        previews.pending = (_, _) => renewal.future;
        await t.pump(const Duration(seconds: 15));
        expect(images.every((image) => image.debugDisposed), true);
        await t.pump();
        expect(find.byKey(const Key('location-map-action-A')), findsNothing);
        renewal.complete(projection(item, protected: true, exact: true));
        await settle(t);
        expect(
          find.byKey(const Key('protected-detail-overlay')),
          findsOneWidget,
        );
        expect(c.read(sharedBasemapTilesProvider).count, 0);
      }
      expect(previews.reads, 3);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final event in [
    'leaving',
    'removal',
    'demotion',
    'meeting-revocation',
  ]) {
    testWidgets(
      '$event synchronously disposes exact images and canonical denial prevents redisplay',
      (t) async {
        final tiles = FixtureMapProviderGateway(tilesEnabled: true),
            static = FakeStaticPreviewGateway();
        var entitled = true;
        final previews = FakePreviewGateway()
          ..pending = (item, _) async =>
              entitled ? projection(item, protected: true, exact: true) : null;
        final c = setup(tiles, previews, static);
        addTearDown(c.dispose);
        c
            .read(authSessionProvider.notifier)
            .markProfileReady(const AuthIdentity(id: 'Alice'));
        await t.pumpWidget(
          shell(
            c,
            ListView(children: [panel(const PreviewItem('one_time', 'A'))]),
          ),
        );
        await settle(t);
        final images = t
            .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
            .debugImages;
        expect(images, isNotEmpty);
        entitled = false;
        if (event == 'demotion') {
          (c.read(projectManagementRoleProvider.notifier) as _MutableRole)
              .withdraw();
        } else if (event == 'meeting-revocation') {
          (c.read(
            participantMeetingDetailsProvider.notifier,
          ) as _MutableMeeting).withdraw();
        } else {
          (c.read(ownParticipationProvider.notifier) as _MutableParticipation)
              .withdraw();
        }
        expect(images.every((image) => image.debugDisposed), true);
        await settle(t);
        expect(find.text('SECRET venue'), findsNothing);
        expect(find.byKey(const Key('protected-detail-overlay')), findsNothing);
        expect(c.read(sharedBasemapTilesProvider).count, 0);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  for (final protected in [false, true]) {
    for (final interruption in ['sibling route', 'scroll', 'TickerMode']) {
      testWidgets(
        '$interruption return revalidates, retaining only public pixels protected=$protected',
        (t) async {
          final tiles = FixtureMapProviderGateway(tilesEnabled: true);
          const item = PreviewItem('one_time', 'A');
          final previews = FakePreviewGateway()
            ..pending = (item, _) async =>
                projection(item, protected: protected, exact: protected);
          final c = setup(tiles, previews, FakeStaticPreviewGateway());
          addTearDown(c.dispose);
          c
              .read(authSessionProvider.notifier)
              .markProfileReady(const AuthIdentity(id: 'Alice'));
          final navigator = GlobalKey<NavigatorState>(),
              scroll = ScrollController();
          Widget body({bool ticking = true}) => TickerMode(
            enabled: ticking,
            child: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [panel(item), const SizedBox(height: 1600)],
              ),
            ),
          );
          await t.pumpWidget(shell(c, body(), navigatorKey: navigator));
          await settle(t);
          final images = t
              .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
              .debugImages;
          final calls = tiles.tileCalls.length, reads = previews.reads;
          if (interruption == 'sibling route') {
            unawaited(
              navigator.currentState!.push<void>(
                MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('Sibling')),
                ),
              ),
            );
          } else if (interruption == 'scroll') {
            scroll.jumpTo(1000);
          } else {
            await t.pumpWidget(
              shell(c, body(ticking: false), navigatorKey: navigator),
            );
          }
          await t.pumpAndSettle();
          expect(
            images.every((image) => image.debugDisposed == protected),
            true,
          );
          final renewal = Completer<LocationPreview?>();
          previews.pending = (_, _) => renewal.future;
          if (interruption == 'sibling route') {
            navigator.currentState!.pop();
          } else if (interruption == 'scroll') {
            scroll.jumpTo(0);
          } else {
            await t.pumpWidget(shell(c, body(), navigatorKey: navigator));
          }
          await t.pumpAndSettle();
          expect(previews.reads, reads + 1);
          expect(
            find.byKey(const Key('location-map-action-A')),
            protected ? findsNothing : findsOneWidget,
          );
          renewal.complete(
            projection(item, protected: protected, exact: protected),
          );
          await settle(t);
          expect(
            find.byKey(const Key('location-map-action-A')),
            findsOneWidget,
          );
          if (!protected) expect(tiles.tileCalls.length, calls);
          await t.pumpWidget(const SizedBox());
          scroll.dispose();
          c.read(sharedBasemapTilesProvider).clear();
        },
      );
    }
  }
  testWidgets(
    'public paused/resumed clears old pixels and promptly loads a fresh scope',
    (t) async {
      final tiles = FixtureMapProviderGateway(tilesEnabled: true);
      final previews = FakePreviewGateway()
        ..pending = (item, _) async => projection(item);
      final c = setup(tiles, previews, FakeStaticPreviewGateway());
      addTearDown(c.dispose);
      await t.pumpWidget(
        shell(
          c,
          ListView(children: [panel(const PreviewItem('one_time', 'A'))]),
        ),
      );
      await settle(t);
      final images = t
          .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
          .debugImages;
      final calls = tiles.tileCalls.length;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(images.every((image) => image.debugDisposed), true);
      expect(c.read(sharedBasemapTilesProvider).count, 0);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(find.byKey(const Key('location-map-action-A')), findsOneWidget);
      expect(previews.reads, 2);
      expect(tiles.tileCalls.length, calls * 2);
      await t.pumpWidget(const SizedBox());
      c.read(sharedBasemapTilesProvider).clear();
    },
  );
  testWidgets(
    'inactive during public tile load completes once without restarting transport',
    (t) async {
      final tiles = DelayedTiles();
      final previews = FakePreviewGateway()
        ..pending = (item, _) async => projection(item);
      final c = setup(tiles, previews, FakeStaticPreviewGateway());
      addTearDown(c.dispose);
      await t.pumpWidget(
        shell(
          c,
          ListView(children: [panel(const PreviewItem('one_time', 'A'))]),
        ),
      );
      await settle(t);
      final calls = tiles.tileCalls.length;
      expect(calls, greaterThan(0));
      expect(find.byKey(const Key('location-map-action-A')), findsNothing);
      expect(find.byKey(const Key('location-open-maps-A')), findsOneWidget);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tiles.finish();
      await settle(t);
      final completedCalls = tiles.tileCalls.length;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(find.byKey(const Key('location-map-action-A')), findsOneWidget);
      expect(tiles.tileCalls.length, completedCalls);
      expect(tiles.tileCalls.toSet().length, completedCalls);
      await t.pumpWidget(const SizedBox());
      c.read(sharedBasemapTilesProvider).clear();
    },
  );
  testWidgets(
    'late private image decode is disposed and its input buffers zeroed on revoke',
    (t) async {
      final bytes = await FixtureMapProviderGateway().tile(12, 2174, 1456);
      final store = SharedBasemapTiles(
        allowed: () => true,
        load: (_, _) async => Uint8List.fromList(bytes),
      );
      addTearDown(store.dispose);
      final decoding = <Completer<ui.Image>>[], inputs = <Uint8List>[];
      final key = GlobalKey<ReadOnlyBasemapState>();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadOnlyBasemap(
              key: key,
              store: store,
              latitude: 46,
              longitude: 11,
              protected: true,
              approximate: false,
              semanticLabel: 'Private',
              failureLabel: 'Unavailable',
              decode: (bytes) {
                inputs.add(bytes);
                decoding.add(Completer<ui.Image>());
                return decoding.last.future;
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(decoding, isNotEmpty);
      key.currentState!.revoke();
      expect(inputs.every((bytes) => bytes.every((byte) => byte == 0)), true);
      final images = <ui.Image>[];
      await t.runAsync(() async {
        for (final pending in decoding) {
          final image = await decodeBasemapImage(bytes);
          images.add(image);
          pending.complete(image);
        }
      });
      await t.pumpAndSettle();
      expect(images.every((image) => image.debugDisposed), true);
      expect(find.byKey(const Key('protected-detail-overlay')), findsNothing);
      expect(store.count, 0);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final change in [
    'revision',
    'location',
    'canonical denial',
    'widget revision',
  ]) {
    testWidgets(
      '$change destroys old protected pixels before accepting replacement',
      (t) async {
        final tiles = FixtureMapProviderGateway(tilesEnabled: true);
        const item = PreviewItem('one_time', 'A');
        final previews = FakePreviewGateway()
          ..pending = (item, _) async =>
              projection(item, protected: true, exact: true);
        final c = setup(tiles, previews, FakeStaticPreviewGateway());
        addTearDown(c.dispose);
        c
            .read(authSessionProvider.notifier)
            .markProfileReady(const AuthIdentity(id: 'Alice'));
        await t.pumpWidget(shell(c, ListView(children: [panel(item)])));
        await settle(t);
        final images = t
            .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
            .debugImages;
        final renewal = Completer<LocationPreview?>();
        previews.pending = (_, _) => renewal.future;
        if (change == 'widget revision') {
          await t.pumpWidget(
            shell(c, ListView(children: [panel(item, version: 2)])),
          );
        } else {
          await t.pump(const Duration(seconds: 15));
        }
        expect(images.every((image) => image.debugDisposed), true);
        await t.pump();
        expect(find.byKey(const Key('location-map-action-A')), findsNothing);
        renewal.complete(
          change == 'canonical denial'
              ? null
              : projection(
                  item,
                  protected: true,
                  exact: true,
                  revision: change == 'revision' ? 2 : 1,
                  lat: change == 'location' ? 47 : 46.0748,
                ),
        );
        await settle(t);
        expect(
          find.byKey(const Key('protected-detail-overlay')),
          change == 'canonical denial' ? findsNothing : findsOneWidget,
        );
        expect(c.read(sharedBasemapTilesProvider).count, 0);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'rendered map tap is single-flight and uses fresh coordinates; denied tap launches nothing',
    (t) async {
      final tiles = FixtureMapProviderGateway(tilesEnabled: true);
      const item = PreviewItem('one_time', 'A');
      final previews = FakePreviewGateway()
        ..pending = (item, _) async => projection(item);
      final c = setup(tiles, previews, FakeStaticPreviewGateway());
      addTearDown(c.dispose);
      await t.pumpWidget(shell(c, ListView(children: [panel(item)])));
      await settle(t);
      final map = find.byKey(const Key('location-map-action-A'));
      final fresh = Completer<LocationPreview?>();
      previews.pending = (_, _) => fresh.future;
      await t.tap(map);
      await t.tap(map);
      expect(previews.reads, 2);
      fresh.complete(projection(item, lat: 47, revision: 2));
      await settle(t);
      final launcher =
          c.read(previewMapsLauncherProvider) as FakePreviewMapsLauncher;
      expect(launcher.urls.length, 1);
      expect(launcher.urls.single.queryParameters['center'], '47.0,11.1217');
      previews.pending = (_, _) async => null;
      await t.tap(map);
      await settle(t);
      expect(launcher.urls.length, 1);
      expect(find.byKey(const Key('location-map-action-A')), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      c.read(sharedBasemapTilesProvider).clear();
    },
  );
  testWidgets(
    'protected rendered map launches only after fresh entitlement; a later denial erases pixels',
    (t) async {
      final tiles = FixtureMapProviderGateway(tilesEnabled: true);
      const item = PreviewItem('one_time', 'A');
      final previews = FakePreviewGateway()
        ..pending = (item, _) async =>
            projection(item, protected: true, exact: true);
      final c = setup(tiles, previews, FakeStaticPreviewGateway());
      addTearDown(c.dispose);
      c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'Alice'));
      await t.pumpWidget(shell(c, ListView(children: [panel(item)])));
      await settle(t);
      final images = t
          .state<ReadOnlyBasemapState>(find.byType(ReadOnlyBasemap))
          .debugImages;
      final map = find.byKey(const Key('location-map-action-A'));
      final launcher =
          c.read(previewMapsLauncherProvider) as FakePreviewMapsLauncher;
      await t.tap(map);
      await settle(t);
      expect(previews.reads, 2);
      expect(launcher.urls.single.queryParameters['query'], '46.0748,11.1217');
      previews.pending = (_, _) async => null;
      await t.tap(map);
      await settle(t);
      expect(launcher.urls.length, 1);
      expect(images.every((image) => image.debugDisposed), true);
      expect(find.byKey(const Key('protected-detail-overlay')), findsNothing);
      expect(find.byKey(const Key('location-map-action-A')), findsNothing);
      expect(c.read(sharedBasemapTilesProvider).count, 0);
      await t.pumpWidget(const SizedBox());
    },
  );
}
