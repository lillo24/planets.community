import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/geographic_discovery.dart';
import 'package:planets_mobile/features/geographic_discovery/application/map_discovery_sessions.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/map_discovery.dart';
import 'package:planets_mobile/features/locations/presentation/location_attribution.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/public_recurring_activities_screen.dart';
import 'package:planets_mobile/features/resource_listings/presentation/public_resource_listings_screen.dart';

import '../test/support/fake_resource_listing.dart';
import '../test_support/map05_app_fixture.dart';
import '../test_support/map_discovery_fixture.dart';

class _NoNetwork extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('MAP05 native fixture forbids network IO.');
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'MAP05 owned Android offline journey through real List/Map/details',
    (tester) async {
      final network = _NoNetwork(), app = Map05AppFixture();
      HttpOverrides.global = network;
      addTearDown(() {
        HttpOverrides.global = null;
        app.dispose();
      });
      Future<void> tapKey(String key) async {
        final control = find.byKey(Key(key));
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        await tester.tap(control);
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        await tester.pump();
        await binding.takeScreenshot('map05-$name');
      }

      await tester.pumpWidget(app.app);
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tapKey('map-open-projects');
      expect(app.geography.calls.single.query.kinds, {GeoKind.oneTime});
      expect(app.provider.tileCalls, isNotEmpty);
      expect(find.textContaining('Synthetic tile fixture'), findsOneWidget);
      await tapKey('map-pin-one_time:${mapFixtureId(1)}');
      expect(
        find.textContaining('Choose among 2 loaded results'),
        findsOneWidget,
      );
      await capture('project-cluster');
      await tapKey('map-cluster-item-one_time:${mapFixtureId(1)}');
      await tapKey('map-open-detail');
      expect(find.byType(ProposalDetailScreen), findsOneWidget);
      app.router.pop();
      await tester.pumpAndSettle();
      await tapKey('map-family');
      await tester.tap(find.text('All').last);
      await tester.pumpAndSettle();
      expect(app.geography.calls.last.query.kinds, GeoKind.values.toSet());
      await tapKey('map-radius');
      await tester.tap(find.text('10 km').last);
      await tester.pumpAndSettle();
      expect(
        (app.geography.calls.last.query.area as GeoRadius).radiusMeters,
        10000,
      );
      await tester.ensureVisible(find.byKey(const Key('public-point-map')));
      await tester.pumpAndSettle();
      final count = app.geography.calls.length;
      await tester.drag(
        find.byKey(const Key('public-point-map')),
        const Offset(-85, 25),
      );
      await tester.pumpAndSettle();
      expect(app.geography.calls.length, count);
      await tapKey('map-search-area');
      expect(app.geography.calls.last.query.area, isA<GeoBounds>());
      await capture('all-viewport');
      await tapKey('map-back-radius');
      await tester.ensureVisible(find.byKey(const Key('map-center-input')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('map-center-input')),
        'Bolzano',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(app.provider.resolutions, isEmpty);
      await tapKey('map-suggestion-${mapFixtureId(100)}');
      expect(
        (app.geography.calls.last.query.area as GeoRadius).latitude,
        46.4983,
      );
      await tapKey('map-return-list');
      expect(find.byType(PublicProposalsScreen), findsOneWidget);
      await tapKey('map-open-projects');
      expect(app.geography.calls.last.query.kinds, GeoKind.values.toSet());
      expect(
        app.container
            .read(mapDiscoverySessionsProvider)
            .forOrigin(MapDiscoveryOrigin.projects)
            .centerLabel,
        'Synthetic Bolzano',
      );
      await tapKey('map-return-list');
      app.router.go('/tavoli');
      app.locale.value = const Locale('it');
      await tester.pumpAndSettle();
      await tapKey('map-open-tavoli');
      expect(app.geography.calls.last.query.kinds, {GeoKind.recurring});
      await tapKey('map-pin-recurring:${mapFixtureId(3)}');
      await capture('tavolo-it-card');
      await tapKey('map-open-detail');
      expect(find.byType(PublicRecurringActivityDetailScreen), findsOneWidget);
      app.router.pop();
      await tester.pumpAndSettle();
      await tapKey('map-return-list');
      app.router.go('/resources');
      app.locale.value = const Locale('en');
      await tester.pumpAndSettle();
      await tapKey('map-open-resources');
      for (final id in [4, 5]) {
        await tapKey('map-pin-resource:${mapFixtureId(id)}');
        expect(
          find.textContaining('Public address or venue reference'),
          findsOneWidget,
        );
        expect(find.text(id == 4 ? 'Dona' : 'Scambia'), findsOneWidget);
        app.resources.publicDetail = publicResourceListingDetailFixture(
          id: mapFixtureId(id),
        );
        await capture('resource-$id-card');
        await tapKey('map-open-detail');
        expect(find.byType(PublicResourceListingDetailScreen), findsOneWidget);
        expect(
          app.router.routerDelegate.state.uri.path,
          '/resources/${mapFixtureId(id)}',
        );
        app.router.pop();
        await tester.pumpAndSettle();
      }
      expect(find.byType(LocationAttribution), findsOneWidget);
      expect(network.attempts, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
