import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/event_time.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/external_activity.dart';
import 'external_activity_filters.dart';

/// Repeat only the source's known term and rules. Never calculate a next lesson
/// on the device; cancellations/exceptions are canonical backend decisions.
String externalCourseLabel(
  ExternalCourseSchedule? schedule,
  String locale,
  AppLocalizations l,
) {
  if (schedule == null) return l.activitiesScheduleUnknown;
  final lines = <String>[
    if (schedule.seasonStart != null && schedule.seasonEnd != null)
      '${DateFormat.yMMMd(locale).format(schedule.seasonStart!)} – '
          '${DateFormat.yMMMd(locale).format(schedule.seasonEnd!)}',
    if (schedule.weekly case final weekly?)
      '${weekly.days.map((day) => DateFormat.E(locale).format(DateTime.utc(2024, 1, day))).join(', ')} '
          '${weekly.startTime}${weekly.endTime == null ? '' : '–${weekly.endTime}'} · ${schedule.timezone}',
    if (schedule.text != null) schedule.text!,
  ];
  return lines.isEmpty ? l.activitiesScheduleUnknown : lines.join('\n');
}

String externalOccurrenceLabel(
  ExternalOccurrence occurrence,
  String locale,
  AppLocalizations l,
) {
  final start = DateTime.parse(occurrence.start);
  final end = occurrence.end == null ? null : DateTime.parse(occurrence.end!);
  if (!occurrence.isTimed) {
    final firstDate = DateTime.utc(start.year, start.month, start.day);
    final first = DateFormat.yMMMd(locale).format(firstDate);
    // Subtract a calendar date in UTC, not 24 hours in the device timezone:
    // the spring daylight-saving day can have only 23 hours.
    final last = end == null
        ? null
        : DateTime.utc(end.year, end.month, end.day - 1);
    final dates = last != null && last.isAfter(firstDate)
        ? '$first – ${DateFormat.yMMMd(locale).format(last)}'
        : first;
    return '$dates · ${occurrence.kind == 'all_day' ? l.activitiesAllDay : l.activitiesTimeNotProvided}';
  }
  final offsets =
      end != null && eventOffsetsDiffer(start, end, occurrence.timezone);
  String point(DateTime instant) =>
      '${DateFormat.yMMMd(locale).format(eventUtcToWallTime(instant, occurrence.timezone))} '
      '${formatEventClock(instant, occurrence.timezone, locale, includeOffset: offsets)}';
  return '${point(start)}${end == null ? '' : ' – ${point(end)}'} · ${occurrence.timezone}';
}

String? externalHealthMessage(
  ExternalCatalogueHealth? health,
  AppLocalizations l,
) => switch (health) {
  ExternalCatalogueHealth.unconfigured => l.activitiesExternalUnconfigured,
  ExternalCatalogueHealth.neverSynchronized =>
    l.activitiesExternalNeverSynchronized,
  ExternalCatalogueHealth.stale => l.activitiesExternalStale,
  ExternalCatalogueHealth.unavailable => l.activitiesExternalUnavailable,
  ExternalCatalogueHealth.partial => l.activitiesExternalPartial,
  _ => null,
};

class ExternalActivityCard extends StatelessWidget {
  const ExternalActivityCard({
    required this.item,
    required this.onTap,
    super.key,
  });
  final ExternalActivity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final occurrence = item.nextOccurrence;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                externalKindLabel(item.kind, l),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(item.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.small),
              if (item.kind != ExternalActivityKind.place)
                Text(
                  occurrence == null
                      ? externalCourseLabel(item.schedule, locale, l)
                      : externalOccurrenceLabel(occurrence, locale, l),
                ),
              if (item.kind == ExternalActivityKind.course &&
                  occurrence != null)
                Text(externalCourseLabel(item.schedule, locale, l)),
              if (item.kind == ExternalActivityKind.place &&
                  item.sourceCategories.isNotEmpty)
                Text(item.sourceCategories.join(' · ')),
              if (item.kind == ExternalActivityKind.course &&
                  occurrence == null)
                Text(l.activitiesNextSessionUnknown),
              if (item.discipline != null)
                Text(externalDisciplineLabel(item.discipline!, l)),
              if (item.cost != null) Text(item.cost!),
              if (item.access != null) Text(item.access!),
              if (item.venue != null || item.city != null)
                Text([item.venue, item.city].nonNulls.join(' · ')),
              const SizedBox(height: AppSpacing.small),
              Text(
                l.activitiesSourceLabel(item.sourceName),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (item.stale)
                Text(
                  item.kind == ExternalActivityKind.place
                      ? l.activitiesPlaceStale
                      : l.activitiesExternalStaleRecord,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
