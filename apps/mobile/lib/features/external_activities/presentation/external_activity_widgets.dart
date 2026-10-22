import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/event_time.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/external_activity.dart';

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
              Text(item.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.small),
              Text(
                occurrence == null
                    ? l.activitiesExternalScheduleUnknown
                    : externalOccurrenceLabel(occurrence, locale, l),
              ),
              if (item.venue != null || item.city != null)
                Text([item.venue, item.city].nonNulls.join(' · ')),
              const SizedBox(height: AppSpacing.small),
              Text(
                l.activitiesSourceLabel(item.sourceName),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (item.stale) Text(l.activitiesExternalStaleRecord),
            ],
          ),
        ),
      ),
    );
  }
}
