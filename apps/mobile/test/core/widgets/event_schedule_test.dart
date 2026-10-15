import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:planets_mobile/core/time/event_time.dart';
import 'package:planets_mobile/core/widgets/event_schedule.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('event day can differ from UTC and the host day', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EventSchedule(
            startsAt: DateTime.utc(2027, 1, 1, 7),
            endsAt: DateTime.utc(2027, 1, 1, 8),
            timeZone: 'Pacific/Honolulu',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('December 31, 2026'), findsOneWidget);
    expect(find.text('21:00 – 22:00'), findsOneWidget);
    expect(find.text('Pacific/Honolulu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['en', 'it']) {
    testWidgets('event-zone dates, year, midnight and DST $locale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final dates in [
        (DateTime.utc(2026, 9, 10, 10), DateTime.utc(2026, 9, 10, 12)),
        (DateTime.utc(2026, 12, 31, 22), DateTime.utc(2026, 12, 31, 23, 30)),
        (DateTime.utc(2026, 1, 31, 22), DateTime.utc(2026, 2, 1, 2)),
        (DateTime.utc(2026, 10, 25, 0, 30), DateTime.utc(2026, 10, 25, 1, 30)),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: EventSchedule(
                  startsAt: dates.$1,
                  endsAt: dates.$2,
                  timeZone: 'Europe/Rome',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(EventSchedule)),
        );
        final same =
            eventLocalDate(dates.$1, 'Europe/Rome') ==
            eventLocalDate(dates.$2, 'Europe/Rome');
        expect(
          find.text(l.proposalStartLabel),
          same ? findsNothing : findsOneWidget,
        );
        expect(
          find.text(l.proposalEndLabel),
          same ? findsNothing : findsOneWidget,
        );
        expect(find.text('Europe/Rome'), findsOneWidget);
        expect(
          find.text(
            DateFormat.yMMMMd(locale)
                .format(eventUtcToWallTime(dates.$1, 'Europe/Rome')),
          ),
          findsOneWidget,
        );
        if (!same) {
          expect(
            find.text(
              DateFormat.yMMMMd(locale)
                  .format(eventUtcToWallTime(dates.$2, 'Europe/Rome')),
            ),
            findsOneWidget,
          );
        }
        if (dates.$1.month == 10) {
          expect(
            find.text('02:30 (UTC+02:00) – 02:30 (UTC+01:00)'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: EventSchedule()),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(EventSchedule)));
      expect(find.text(l.proposalDateUndecided), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    });
  }
  test(
    'compact summaries use event-local day and preserve different dates',
    () {
      expect(
        formatEventScheduleSummary(
          DateTime.utc(2026, 9, 10, 10),
          DateTime.utc(2026, 9, 10, 12),
          'Europe/Rome',
          'en',
        ),
        'Sep 10, 2026 · 12:00 – 14:00',
      );
      expect(
        formatEventScheduleSummary(
          DateTime.utc(2026, 12, 31, 22),
          DateTime.utc(2026, 12, 31, 23, 30),
          'Europe/Rome',
          'en',
        ),
        'Dec 31, 2026 23:00 – Jan 1, 2027 00:30',
      );
    },
  );
}
