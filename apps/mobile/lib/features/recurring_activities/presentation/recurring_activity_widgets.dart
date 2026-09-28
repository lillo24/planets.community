import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/event_time.dart';
import '../../../core/widgets/requested_badge.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../cover_media/presentation/project_cover_image.dart';
import '../domain/recurring_activity_models.dart';

class RecurringActivityCard extends StatelessWidget {
  const RecurringActivityCard({
    required this.activity,
    required this.onTap,
    this.isRequested = false,
    super.key,
  });

  final PublicRecurringActivitySummary activity;
  final VoidCallback onTap;
  final bool isRequested;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: isRequested
          ? RoundedRectangleBorder(
              borderRadius: AppRadii.medium,
              side: BorderSide(color: scheme.tertiary, width: 2),
            )
          : null,
      child: InkWell(
        key: Key('tavolo-card-${activity.id}'),
        onTap: onTap,
        borderRadius: AppRadii.medium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProjectCoverImage(
              key: Key('tavolo-cover-${activity.id}'),
              title: activity.title,
              objectPath: activity.coverObjectPath,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          activity.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (isRequested) ...[
                        const SizedBox(width: AppSpacing.small),
                        const RequestedBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(activity.summary),
                  if (activity.topic case final topic?) ...[
                    const SizedBox(height: AppSpacing.xSmall),
                    Text(topic, style: Theme.of(context).textTheme.labelLarge),
                  ],
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    '${activity.publicLocationLabel} · ${activity.locality}',
                    key: Key('tavolo-public-location-${activity.id}'),
                  ),
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(formatRecurringSchedule(activity.schedule, context)),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    '${l10n.tavoliNextMeeting}: '
                    '${formatEventDateTime(activity.nextOccurrence.startsAt, activity.nextOccurrence.eventTimezone, locale)} – '
                    '${DateFormat.Hm(locale).format(eventUtcToWallTime(activity.nextOccurrence.endsAt, activity.nextOccurrence.eventTimezone))}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatRecurringSchedule(
  RecurringSchedule schedule,
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context);
  final time = _minuteTime(schedule.localStartTime);
  return switch (schedule.recurrenceType) {
    RecurrenceType.weekly => l10n.tavoliWeeklySummary(
      _weekdayName(schedule.weekday!, context),
      time,
    ),
    RecurrenceType.monthly => l10n.tavoliMonthlySummary(
      schedule.dayOfMonth!,
      time,
    ),
  };
}

String _weekdayName(int weekday, BuildContext context) {
  final monday = DateTime(2024, 1, 1);
  return DateFormat.EEEE(Localizations.localeOf(context).toLanguageTag())
      .format(monday.add(Duration(days: weekday - 1)));
}

String _minuteTime(String value) {
  final parts = value.split(':');
  return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : value;
}

class RecurringLifecycleBadge extends StatelessWidget {
  const RecurringLifecycleBadge({required this.lifecycle, super.key});
  final RecurringActivityLifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (lifecycle) {
      RecurringActivityLifecycle.draft => l10n.tavoliLifecycleDraft,
      RecurringActivityLifecycle.published => l10n.tavoliLifecycleActive,
      RecurringActivityLifecycle.paused => l10n.tavoliLifecyclePaused,
      RecurringActivityLifecycle.ended => l10n.tavoliLifecycleEnded,
    };
    return Chip(label: Text(label));
  }
}
