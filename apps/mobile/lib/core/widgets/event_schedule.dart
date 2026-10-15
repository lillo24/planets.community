import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_tokens.dart';
import '../time/event_time.dart';

/// Canonical public instants only; absence never borrows tentative logistics.
class EventSchedule extends StatelessWidget {
  const EventSchedule({this.startsAt, this.endsAt, this.timeZone, super.key});

  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? timeZone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final start = startsAt;
    final end = endsAt;
    final zone = timeZone;
    final theme = Theme.of(context);
    if (start == null || end == null || zone == null) {
      return ScheduleSurface(child: Text(l.proposalDateUndecided));
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sameDay = eventLocalDate(start, zone) == eventLocalDate(end, zone);
    final date = DateFormat.yMMMMd(locale);
    Widget endpoint(String label, DateTime instant) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        Text(date.format(eventUtcToWallTime(instant, zone))),
        Text(
          formatEventClock(
            instant,
            zone,
            locale,
            includeOffset: eventOffsetsDiffer(start, end, zone),
          ),
          style: theme.textTheme.titleLarge,
        ),
      ],
    );
    return ScheduleSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sameDay) ...[
            Text(date.format(eventUtcToWallTime(start, zone))),
            const SizedBox(height: AppSpacing.xSmall),
            Text(
              eventTimeRange(start, end, zone, locale),
              style: theme.textTheme.titleLarge,
            ),
          ] else ...[
            endpoint(l.proposalStartLabel, start),
            const SizedBox(height: AppSpacing.medium),
            endpoint(l.proposalEndLabel, end),
          ],
          const SizedBox(height: AppSpacing.small),
          Text(zone, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class ScheduleSurface extends StatelessWidget {
  const ScheduleSurface({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.medium),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: AppRadii.medium,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.calendar_today_outlined, size: 20),
        const SizedBox(width: AppSpacing.medium),
        Expanded(child: child),
      ],
    ),
  );
}
