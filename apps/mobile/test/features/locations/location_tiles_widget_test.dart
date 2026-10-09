import 'dart:async';

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
}) => LocationPreview(
  item: item,
  revision: 1,
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
}) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
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
  FakePreviewGateway preview,
  FakeStaticPreviewGateway static, {
  bool detailEnabled = true,
}) => ProviderContainer(
  overrides: [
    mapProviderGatewayProvider.overrideWithValue(tiles),
    basemapCacheTtlProvider.overrideWithValue(const Duration(minutes: 1)),
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
    for (final p in pending.where((p) => !p.isCompleted)) {
      final bytes = await FixtureMapProviderGateway().tile(12, 2174, 1456);
      outputs.add(bytes);
      p.complete(bytes);
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
        expect(
          find.byKey(Key('location-open-maps-${item.id}')),
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
        final maps = find.byKey(const Key('location-open-maps-A'));
        expect(maps, findsOneWidget);
        expect(t.getSize(maps).height, greaterThanOrEqualTo(48));
        expect(
          t.getSemantics(find.byType(ReadOnlyBasemap)).label,
          contains('Synthetic Trento'),
        );
        // IgnorePointer deliberately lets the parent ListView receive this drag.
        await t.dragFrom(
          t.getCenter(find.byType(ReadOnlyBasemap)),
          const Offset(0, -100),
        );
        await settle(t);
        expect(scroll.offset, greaterThan(0));
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        scroll.dispose();
        semantics.dispose();
        c.read(sharedBasemapTilesProvider).clear();
      },
    );
  }
  for (final reason in ['lease', 'background', 'account-ABA', 'route']) {
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
}
