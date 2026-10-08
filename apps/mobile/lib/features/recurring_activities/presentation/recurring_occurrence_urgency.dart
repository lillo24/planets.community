import '../../../core/time/event_time.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/recurring_activity_models.dart';

/// Upcoming meetings within six calendar days in the occurrence's event zone.
/// Calendar dates are compared on a UTC date axis, avoiding DST day lengths.
/// Already-started occurrences have no urgency label, even on the same day.
String? formatRecurringOccurrenceUrgency(
  RecurringActivityOccurrence occurrence,
  AppLocalizations l10n, {
  required DateTime now,
}) {
  if (occurrence.startsAt.isBefore(now)) return null;
  final today = eventLocalDate(now, occurrence.eventTimezone);
  final meeting = eventLocalDate(occurrence.startsAt, occurrence.eventTimezone);
  final days = DateTime.utc(
    meeting.year,
    meeting.month,
    meeting.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  return switch (days) {
    0 => l10n.tavoliOccurrenceToday,
    1 => l10n.tavoliOccurrenceTomorrow,
    >= 2 && <= 6 => l10n.tavoliOccurrenceInDays(days),
    _ => null,
  };
}
