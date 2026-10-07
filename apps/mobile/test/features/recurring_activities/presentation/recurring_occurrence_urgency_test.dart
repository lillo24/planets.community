import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/recurring_activities/domain/recurring_activity_models.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/recurring_occurrence_urgency.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

RecurringActivityOccurrence _occurrence(
  DateTime startsAt, {
  String zone = 'Europe/Rome',
}) => RecurringActivityOccurrence(
  startsAt: startsAt,
  endsAt: startsAt.add(const Duration(hours: 1)),
  eventTimezone: zone,
);

void main() {
  for (final language in ['en', 'it']) {
    group(language, () {
      late AppLocalizations l10n;
      setUpAll(() async {
        l10n = await AppLocalizations.delegate.load(Locale(language));
      });

      for (final days in [0, 1, 2, 6, 7, 28]) {
        test('$days local calendar days away', () {
          final now = DateTime.utc(2026, 9, 7, 10);
          final startsAt = DateTime.utc(2026, 9, 7 + days, 17);
          final expected = switch (days) {
            0 => language == 'it' ? 'Oggi' : 'Today',
            1 => language == 'it' ? 'Domani' : 'Tomorrow',
            2 || 6 => language == 'it' ? 'Tra $days giorni' : 'In $days days',
            _ => null,
          };
          expect(
            formatRecurringOccurrenceUrgency(
              _occurrence(startsAt),
              l10n,
              now: now,
            ),
            expected,
          );
        });
      }

      test('Rome local midnight can be tomorrow within ten minutes', () {
        expect(
          formatRecurringOccurrenceUrgency(
            _occurrence(DateTime.utc(2026, 9, 8, 22, 5)),
            l10n,
            now: DateTime.utc(2026, 9, 8, 21, 55),
          ),
          language == 'it' ? 'Domani' : 'Tomorrow',
        );
      });

      test('UTC midnight does not advance the New York calendar date', () {
        expect(
          formatRecurringOccurrenceUrgency(
            _occurrence(
              DateTime.utc(2026, 9, 9, 0, 30),
              zone: 'America/New_York',
            ),
            l10n,
            now: DateTime.utc(2026, 9, 8, 23, 30),
          ),
          language == 'it' ? 'Oggi' : 'Today',
        );
      });

      test('spring DST makes 47 hours two calendar days', () {
        expect(
          formatRecurringOccurrenceUrgency(
            _occurrence(DateTime.utc(2026, 3, 30, 10)),
            l10n,
            now: DateTime.utc(2026, 3, 28, 11),
          ),
          language == 'it' ? 'Tra 2 giorni' : 'In 2 days',
        );
      });

      test('autumn DST still compares calendar dates', () {
        expect(
          formatRecurringOccurrenceUrgency(
            _occurrence(DateTime.utc(2026, 10, 26, 10)),
            l10n,
            now: DateTime.utc(2026, 10, 24, 10),
          ),
          language == 'it' ? 'Tra 2 giorni' : 'In 2 days',
        );
      });

      test('UTC alias and exact start remain valid', () {
        final now = DateTime.utc(2026, 9, 7, 10);
        expect(
          formatRecurringOccurrenceUrgency(
            _occurrence(now, zone: 'UTC'),
            l10n,
            now: now,
          ),
          language == 'it' ? 'Oggi' : 'Today',
        );
      });

      test('already started today and older stale occurrences are hidden', () {
        final now = DateTime.utc(2026, 9, 7, 10);
        for (final past in [
          now.subtract(const Duration(minutes: 1)),
          now.subtract(const Duration(days: 2)),
        ]) {
          expect(
            formatRecurringOccurrenceUrgency(_occurrence(past), l10n, now: now),
            isNull,
          );
        }
      });
    });
  }
}
