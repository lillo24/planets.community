import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/resource_listings/presentation/resource_listing_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_resource_listing.dart';

void main() {
  for (final copy in [
    (
      locale: 'en',
      values: [
        '0 People Interested',
        '1 person interested',
        '2 people interested',
      ],
    ),
    (
      locale: 'it',
      values: [
        '0 Persone Interessate',
        '1 persona interessata',
        '2 persone interessate',
      ],
    ),
  ]) {
    for (var count = 0; count < copy.values.length; count++) {
      testWidgets('${copy.locale} interest copy for $count', (tester) async {
        await _pump(tester, locale: Locale(copy.locale), count: count);
        expect(find.text(copy.values[count]), findsOneWidget);
      });
    }
  }

  for (final width in [280.0, 320.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('metadata wraps at width $width and text scale $scale', (
        tester,
      ) async {
        await _pump(tester, width: width, scale: scale);
        final metadata = find.byKey(
          const Key('resource-metadata-$resourceListingId'),
        );
        expect(tester.widget<Wrap>(metadata).children, hasLength(2));
        final interest = find.byKey(
          const Key('resource-interest-count-$resourceListingId'),
        );
        final location = find.byKey(
          const Key('resource-location-$resourceListingId'),
        );
        for (final group in [interest, location]) {
          final icon = find.descendant(of: group, matching: find.byType(Icon));
          final text = find.descendant(of: group, matching: find.byType(Text));
          expect(tester.getTopLeft(text).dx - tester.getTopRight(icon).dx, 8);
          expect(
            tester.getRect(group).right,
            lessThanOrEqualTo(tester.getRect(metadata).right),
          );
          expect(
            find.descendant(of: group, matching: find.byType(Expanded)),
            findsNothing,
          );
        }
        expect(
          tester.getTopLeft(location).dy,
          greaterThan(tester.getTopLeft(interest).dy),
        );
        expect(find.text('Trento'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'card falls back to public label when structured locality is empty',
    (tester) async {
      await _pump(tester, locality: ' ', publicLocation: 'Workshop district');
      expect(find.text('Workshop district'), findsOneWidget);
    },
  );
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  int count = 0,
  double width = 800,
  double scale = 1,
  String locality = 'Trento',
  String publicLocation = 'Workshop near the northern gate in Trento',
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1500));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: PublicResourceListingCard(
                listing: publicResourceListingFixture(
                  locality: locality,
                  publicLocationLabel: publicLocation,
                  activeRequestCount: count,
                ),
                now: DateTime.utc(2026, 9, 14, 15),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
