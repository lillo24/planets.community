import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/features/resource_listings/presentation/resource_listing_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_resource_listing.dart';

void main() {
  testWidgets('relative publication age follows compact thresholds', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const SizedBox(key: Key('age-context'))));
    final context = tester.element(find.byKey(const Key('age-context')));
    final now = DateTime.utc(2026, 9, 14, 15);

    expect(
      formatResourceListingRelativeAge(
        context,
        now.subtract(const Duration(seconds: 30)),
        now: now,
      ),
      'now',
    );
    expect(
      formatResourceListingRelativeAge(
        context,
        now.subtract(const Duration(minutes: 22)),
        now: now,
      ),
      '22m ago',
    );
    expect(
      formatResourceListingRelativeAge(
        context,
        now.subtract(const Duration(hours: 3)),
        now: now,
      ),
      '3h ago',
    );
    expect(
      formatResourceListingRelativeAge(
        context,
        now.subtract(const Duration(days: 2)),
        now: now,
      ),
      '2d ago',
    );
    expect(
      formatResourceListingRelativeAge(
        context,
        now.subtract(const Duration(days: 8)),
        now: now,
      ),
      'Sep 6',
    );
  });

  testWidgets('resource card tolerates narrow large text without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final listing = publicResourceListingFixture(
      mode: ResourceListingMode.exchange,
      title: 'A very long resource listing title for a narrow phone',
      description: 'A deliberately long description that must wrap without breaking the card layout.',
      publicLocationLabel: 'A long but still public neighborhood label',
      activeRequestCount: 12,
    );
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ListView(
            children: [
              PublicResourceListingCard(
                listing: listing,
                now: DateTime.utc(2026, 9, 14, 15),
                onTap: () {},
              ),
            ],
          ),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );

    expect(find.byKey(Key('resource-age-${listing.id}')), findsOneWidget);
    expect(
      find.byKey(Key('resource-interest-count-${listing.id}')),
      findsOneWidget,
    );
    expect(find.byKey(Key('resource-location-${listing.id}')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget home, {TextScaler? textScaler}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: textScaler == null
      ? null
      : (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
  home: home,
);
