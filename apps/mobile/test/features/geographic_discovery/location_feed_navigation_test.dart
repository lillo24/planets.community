import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/map_discovery.dart';
import 'package:planets_mobile/features/locations/data/location_preview_gateway.dart';
import 'package:planets_mobile/features/locations/presentation/location_preview_panel.dart';

import '../../../test_support/map05_app_fixture.dart';
import '../../support/fake_location_preview.dart';

void main() {
  for (final route in ['proposals', 'tavoli']) {
    for (final language in ['en', 'it']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$route $language ${scale}x balanced visible header gaps', (
          t,
        ) async {
          await t.binding.setSurfaceSize(const Size(320, 900));
          t.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() => t.binding.setSurfaceSize(null));
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          final fixture = Map05AppFixture();
          fixture.locale.value = Locale(language);
          fixture.router.go('/$route');
          await t.pumpWidget(fixture.app);
          await t.pumpAndSettle();

          final family = t.getRect(
            find.byKey(const Key('browse-activity-switcher')),
          );
          final selector = t.getRect(
            find.byKey(const Key('map-view-selector')),
          );
          final nextRow = t.getRect(
            find.byKey(
              Key(
                route == 'proposals'
                    ? 'proposal-query-filter'
                    : 'tavoli-toggle-filters',
              ),
            ),
          );
          // Material 3's family outline is inset 4dp within its tap target.
          final gapAbove = selector.top - (family.bottom - 4);
          final gapBelow = nextRow.top - selector.bottom;
          expect(gapAbove, 16);
          expect(gapBelow, gapAbove);
          expect(selector.width, family.width);
          expect(selector.center.dx, family.center.dx);
          expect(selector.height, greaterThanOrEqualTo(48));
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
          fixture.dispose();
        });
      }
    }
  }
  for (final origin in MapDiscoveryOrigin.values) {
    testWidgets(
      '$origin 320px/2x feed credits clear Create and Map return retains scroll',
      (t) async {
        await t.binding.setSurfaceSize(const Size(320, 900));
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() => t.binding.setSurfaceSize(null));
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final fixture = Map05AppFixture();
        fixture.locale.value = const Locale('it');
        fixture.router.go(switch (origin) {
          MapDiscoveryOrigin.projects => '/proposals',
          MapDiscoveryOrigin.tavoli => '/tavoli',
          MapDiscoveryOrigin.resources => '/resources',
        });
        await t.pumpWidget(fixture.app);
        await t.pumpAndSettle();
        final previews = fixture.container.read(
          locationPreviewGatewayProvider,
        ) as FakePreviewGateway;
        final images = fixture.container.read(
          staticPreviewGatewayProvider,
        ) as FakeStaticPreviewGateway;
        expect(find.byType(LocationPreviewPanel), findsNothing);
        expect(previews.reads, 0);
        expect(previews.batches, 0);
        expect(images.calls, 0);
        expect(
          t.getSize(find.byKey(const Key('map-view-selector'))).width,
          288,
        );
        final credits = find.byKey(const Key('location-attribution'));
        final scrollable = find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first;
        await t.scrollUntilVisible(credits, 250, scrollable: scrollable);
        await t.pumpAndSettle();
        expect(credits, findsOneWidget);
        final create = t.getRect(find.byType(FloatingActionButton));
        expect(t.getRect(credits).overlaps(create), false);
        final scroll = t.state<ScrollableState>(scrollable).position;
        final pixels = scroll.pixels;
        expect(pixels, greaterThan(0));
        fixture.router.push('/discover/map/${origin.name}');
        await t.pumpAndSettle();
        expect(
          t.getSize(find.byKey(const Key('map-view-selector'))).width,
          288,
        );
        await t.tap(find.byKey(const Key('map-return-list')));
        await t.pumpAndSettle();
        expect(scroll.pixels, closeTo(pixels, .1));
        expect(previews.reads, 0);
        expect(previews.batches, 0);
        expect(images.calls, 0);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        // Drain the fixture renderer's bounded tile debounce after disposal.
        await t.pump(const Duration(seconds: 1));
        fixture.dispose();
      },
    );
  }
}
