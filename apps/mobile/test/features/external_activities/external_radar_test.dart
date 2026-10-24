import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/external_activities/domain/external_activity.dart';
import 'package:planets_mobile/features/external_activities/presentation/external_activity_filters.dart';
import 'package:planets_mobile/features/external_activities/presentation/external_activity_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_external_activities.dart';
import '../../support/rendered_evidence.dart';

void main() {
  setUpAll(() async {
    await RenderedEvidence.loadFonts(force: true);
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
  });
  test(
    'RADAR01 activity type is strict and survives List/Map and area changes',
    () {
      const filter = ExternalActivityFilter(
        category: 'culture',
        query: 'source',
        activityType: 'workshops',
      );
      expect(filter.forMap().activityType, 'workshops');
      expect(filter.withArea(null).activityType, 'workshops');
      expect(
        filter,
        isNot(
          const ExternalActivityFilter(category: 'culture', query: 'source'),
        ),
      );
      final payload = externalActivityPayload()
        ..['activity_type'] = 'workshops';
      expect(ExternalActivity.parse(payload).activityType, 'workshops');
      payload['activity_type'] = 'unsupported';
      expect(() => ExternalActivity.parse(payload), throwsFormatException);
    },
  );
  for (final language in ['en', 'it']) {
    for (final width in [320.0, 360.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'RADAR01 $language ${width.toInt()}dp 2x dark=$dark source-backed filters',
          (tester) async {
            tester.view.physicalSize = Size(width, 1000);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            ExternalActivityFilter? selected;
            final item = ExternalActivity.parse(
              externalActivityPayload()
                ..['title'] = 'Synthetic creative workshop'
                ..['activity_type'] = 'workshops'
                ..['cost'] = null
                ..['access'] = 'Synthetic registration and membership conditions; check publisher.'
                ..['geometry'] = null,
            );
            await tester.pumpWidget(
              RenderedEvidence.wrap(
                MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: dark ? AppTheme.dark : AppTheme.light,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: ListView(
                      children: [
                        ExternalActivityFilters(
                          filter: const ExternalActivityFilter(
                            category: 'culture',
                            query: 'source',
                            activityType: 'workshops',
                          ),
                          disciplines: const [],
                          activityTypes: const [
                            'music',
                            'workshops',
                            'exhibitions',
                          ],
                          onChanged: (value) => selected = value,
                        ),
                        ExternalActivityCard(item: item, onTap: () {}),
                        Text(item.access!),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.text(language == 'it' ? 'Laboratori' : 'Workshops'),
              findsWidgets,
            );
            expect(
              find.text(language == 'it' ? 'Escursioni' : 'Outings'),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
            await RenderedEvidence.capture(
              tester,
              'radar01-$language-${width.toInt()}-${dark ? 'dark' : 'light'}-filters',
            );
            await tester.tap(find.byKey(const Key('activities-refine')));
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byKey(const Key('activities-today')),
            );
            await tester.tap(find.byKey(const Key('activities-today')));
            await tester.pumpAndSettle();
            expect(selected?.activityType, 'workshops');
            expect(selected?.query, 'source');
            expect(
              DateTime.parse(selected!.to!)
                  .difference(DateTime.parse(selected!.from!))
                  .inDays,
              1,
            );
            await tester.ensureVisible(
              find.byKey(const Key('activities-weekend')),
            );
            await tester.tap(find.byKey(const Key('activities-weekend')));
            expect(selected?.activityType, 'workshops');
            expect(
              DateTime.parse(selected!.to!)
                  .difference(DateTime.parse(selected!.from!))
                  .inDays,
              inInclusiveRange(1, 2),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
