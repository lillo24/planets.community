import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_tokens.dart';
import '../time/event_time.dart';

/// Canonical public instants only; absence never borrows tentative logistics.
class EventSchedule extends StatelessWidget {
  const EventSchedule({
    this.startsAt,
    this.endsAt,
    this.timeZone,
    this.showIcon = true,
    this.viewerTimeZone,
    super.key,
  });

  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? timeZone;

  /// Optional explicit viewer zone; otherwise compare the device's UTC offsets
  /// at both endpoints. Locale is never used to guess a person's timezone.
  final String? viewerTimeZone;

  /// False when the enclosing section heading already supplies the calendar.
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final start = startsAt;
    final end = endsAt;
    final zone = timeZone;
    final theme = Theme.of(context);
    if (start == null || end == null || zone == null) {
      return ScheduleSurface(
        showIcon: showIcon,
        child: Text(l.proposalDateUndecided),
      );
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sameDay = eventLocalDate(start, zone) == eventLocalDate(end, zone);
    final offsetsDiffer = eventOffsetsDiffer(start, end, zone);
    final date = DateFormat.yMMMd(locale);
    final startDate = date.format(eventUtcToWallTime(start, zone));
    final endDate = date.format(eventUtcToWallTime(end, zone));
    String clock(DateTime instant) =>
        formatEventClock(instant, zone, locale, includeOffset: offsetsDiffer);
    final semanticRange =
        '${l.proposalStartLabel}: $startDate ${clock(start)}; '
        '${l.proposalEndLabel}: $endDate ${clock(end)}';
    final foreignZone = [start, end].any(
      (instant) =>
          eventTimeZoneOffset(instant, zone) !=
          (viewerTimeZone == null
              ? instant.toLocal().timeZoneOffset
              : eventTimeZoneOffset(instant, viewerTimeZone!)),
    );
    final zoneCue = foreignZone && !offsetsDiffer
        ? l.eventScheduleZone(eventTimeZoneLabel(start, zone))
        : '';
    Widget endpoint(DateTime instant, String text, String key) => Column(
      key: ValueKey(key),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text),
        Text(clock(instant), style: theme.textTheme.titleMedium),
      ],
    );
    return ScheduleSurface(
      showIcon: showIcon,
      child: Semantics(
        label: zoneCue.isEmpty ? semanticRange : '$semanticRange; $zoneCue',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sameDay)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$startDate · '),
                      TextSpan(
                        text: '${clock(start)}–${clock(end)}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontal =
                        constraints.maxWidth >=
                        MediaQuery.textScalerOf(context).scale(100) * 2 + 32;
                    final first = endpoint(
                      start,
                      startDate,
                      'event-schedule-start',
                    );
                    final last = endpoint(end, endDate, 'event-schedule-end');
                    return horizontal
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: first),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.arrow_forward, size: 20),
                              ),
                              Expanded(child: last),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              first,
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Icon(Icons.arrow_downward, size: 20),
                              ),
                              last,
                            ],
                          );
                  },
                ),
              // Offset changes are already explicit on each clock endpoint.
              // A foreign device zone gets one friendly abbreviation/offset cue,
              // without printing the raw IANA identifier on ordinary calendars.
              if (zoneCue.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xSmall),
                Text(zoneCue, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ScheduleSurface extends StatelessWidget {
  const ScheduleSurface({required this.child, this.showIcon = true, super.key});
  final Widget child;
  final bool showIcon;

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
        if (showIcon) ...[
          const Icon(Icons.calendar_today_outlined, size: 20),
          const SizedBox(width: AppSpacing.medium),
        ],
        Expanded(child: child),
      ],
    ),
  );
}
