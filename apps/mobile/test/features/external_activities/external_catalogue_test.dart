import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/external_activities/domain/external_activity.dart';
import 'package:planets_mobile/features/external_activities/presentation/external_activity_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_external_activities.dart';
import '../../support/rendered_evidence.dart';

Map<String, dynamic> listing(String kind) => externalActivityPayload()
  ..['kind'] = kind
  ..['title'] = kind == 'place'
      ? 'Synthetic basketball court'
      : 'Synthetic weekly yoga'
  ..['description'] = null
  ..['occurrences'] = []
  ..['next_at'] = null
  ..['schedule'] = kind == 'course'
      ? {
          'season_start': '2026-10-01',
          'season_end': '2026-11-30',
          'timezone': 'Europe/Rome',
          'text': null,
        }
      : null;
Map<String, dynamic> page(Map<String, dynamic> item) => {
  'state': 'healthy',
  'as_of': '2026-10-22T12:00:00Z',
  'items': [item],
  'disciplines': [],
  'next_cursor': null,
  'last_success_at': '2026-10-21T12:00:00Z',
};

void main() {
  setUpAll(() async {
    await RenderedEvidence.loadFonts(force: true);
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
  });
  test(
    'undated places and current no-session courses retain unknown values',
    () {
      for (final kind in ['place', 'course']) {
        final item = ExternalActivityPage.parse(page(listing(kind)))
            .items
            .single;
        expect(item.kind.name, kind);
        expect(item.nextAt, isNull);
        expect(item.nextOccurrence, isNull);
        expect(item.description, isNull);
        expect(item.cost, isNull);
        expect(item.occurrences, isEmpty);
      }
      expect(
        ExternalActivity.parse(externalActivityPayload()).kind,
        ExternalActivityKind.event,
      );
    },
  );
  test('next weekly session is supplied by the canonical backend without expanding the source list', () {
    final item = listing('course')
      ..['next_at'] = '2026-10-25T09:00:00Z'
      ..['next_occurrence'] = {
        'kind': 'timed',
        'start': '2026-10-25T10:00:00+01:00',
        'end': null,
        'timezone': 'Europe/Rome',
      };
    final parsed = ExternalActivityPage.parse(page(item)).items.single;
    expect(parsed.occurrences, isEmpty);
    expect(parsed.nextOccurrence!.end, isNull);
    expect(parsed.nextOccurrence!.startInstant, DateTime.utc(2026, 10, 25, 9));
    item['next_at'] = '2026-10-25T08:00:00Z';
    expect(() => ExternalActivityPage.parse(page(item)), throwsFormatException);
  });
  test('catalogue facets are server-owned, typed and distinct from the loaded page', () {
    final payload = page(listing('place'))
      ..['facets'] = {
        'kinds': ['event', 'course', 'place'],
        'categories': ['sports', 'culture'],
        'disciplines': ['basketball', 'yoga'],
      };
    final parsed = ExternalActivityPage.parse(payload);
    expect(parsed.kinds, ExternalActivityKind.values);
    expect(parsed.categories, ['sports', 'culture']);
    expect(parsed.items, hasLength(1));
    payload['facets'] = {
      'kinds': ['facility'],
      'categories': ['sports'],
    };
    expect(() => ExternalActivityPage.parse(payload), throwsFormatException);
    expect(
      () => ExternalActivityPage.parse(
        page(listing('place')..['status'] = 'cancelled'),
      ),
      throwsFormatException,
    );
  });
  test('expired or unknown seasons, invented place appointments and invalid geometry fail', () {
    for (final schedule in [
      null,
      {'text': 'Unknown'},
      {'season_start': '2026-09-01', 'season_end': '2026-09-30'},
    ]) {
      expect(
        () => ExternalActivityPage.parse(
          page(listing('course')..['schedule'] = schedule),
        ),
        throwsFormatException,
      );
    }
    expect(
      () => ExternalActivityPage.parse(
        page(listing('place')..['next_at'] = '2026-10-24T08:00:00Z'),
      ),
      throwsFormatException,
    );
    for (final geometry in [
      {
        'latitude': 91,
        'longitude': 11,
        'precision': 'venue',
        'provenance_url': 'https://calendar.example.org/data',
      },
      {
        'latitude': 46,
        'longitude': 11,
        'precision': 'inferred',
        'provenance_url': 'https://calendar.example.org/data',
      },
      {
        'latitude': double.nan,
        'longitude': 11,
        'precision': 'venue',
        'provenance_url': 'https://calendar.example.org/data',
      },
    ]) {
      expect(
        () => ExternalActivity.parse(listing('place')..['geometry'] = geometry),
        throwsFormatException,
      );
    }
    final locality = ExternalActivity.parse(
      listing('place')
        ..['geometry'] = {
          'latitude': 46.07,
          'longitude': 11.12,
          'precision': 'locality',
          'provenance_url': 'https://calendar.example.org/data',
        },
    );
    expect(locality.geometry!.precision, 'locality');
  });
  test('bounded rules reject impossible dates, unsupported fields and incomplete recurrence', () {
    for (final schedule in [
      {'season_start': '2026-02-30', 'season_end': '2026-12-01'},
      {
        'weekly': {
          'days': [7],
          'start_time': '10:00',
        },
      },
      {'rrule': 'FREQ=DAILY'},
      {
        'season_start': '2026-10-01',
        'season_end': '2026-12-01',
        'timezone': 'Europe/Rome',
        'weekly': {
          'days': [7],
          'start_time': '24:00',
        },
      },
    ]) {
      expect(
        () => ExternalCourseSchedule.parse(schedule),
        throwsFormatException,
      );
    }
    expect(
      const ExternalActivityFilter(kind: ExternalActivityKind.place),
      isNot(const ExternalActivityFilter(kind: ExternalActivityKind.event)),
    );
    expect(
      const ExternalActivityFilter(from: '2026-10-23', to: '2026-10-24'),
      isNot(const ExternalActivityFilter()),
    );
  });
  for (final locale in ['en', 'it']) {
    for (final width in [320.0, 360.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          '$locale ${width.toInt()}dp 2x dark=$dark all kinds render without fabricated dates',
          (tester) async {
            tester.view.physicalSize = Size(width, 950);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              RenderedEvidence.wrap(
                MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: Locale(locale),
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
                        for (final kind in ['course', 'place'])
                          ExternalActivityCard(
                            item: ExternalActivity.parse(listing(kind)),
                            onTap: () {},
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(ExternalActivityCard), findsNWidgets(2));
            await RenderedEvidence.capture(
              tester,
              'actcat02-$locale-${width.toInt()}-${dark ? 'dark' : 'light'}',
            );
          },
        );
      }
    }
  }
}
