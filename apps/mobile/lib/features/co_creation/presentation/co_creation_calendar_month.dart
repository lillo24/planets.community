import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/co_creation_calendar.dart';

/// Markers describe only supplied, authorized rows; pagination is disclosed by
/// the owner. A mixed day keeps both available and full markers.
class CoCalendarMonth extends StatelessWidget {
  const CoCalendarMonth({
    required this.selected,
    required this.meetings,
    required this.onSelect,
    super.key,
  });
  final DateTime selected;
  final List<CoCalendarMeeting> meetings;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final l = AppLocalizations.of(context);
    final first = DateTime(selected.year, selected.month);
    final offset = (first.weekday % 7 - material.firstDayOfWeekIndex + 7) % 7;
    final days = DateTime(selected.year, selected.month + 1, 0).day;
    final colors = Theme.of(context).colorScheme;
    final green = colors.brightness == Brightness.dark
        ? const Color(0xff8cdb9e)
        : const Color(0xff176b32);
    final red = colors.error;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / 7;
        return Wrap(
          children: [
            for (var i = 0; i < 7; i++)
              SizedBox(
                width: width,
                height: 36,
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      material.narrowWeekdays[(i +
                              material.firstDayOfWeekIndex) %
                          7],
                    ),
                  ),
                ),
              ),
            for (var i = 0; i < ((offset + days + 6) ~/ 7) * 7; i++)
              if (i < offset || i >= offset + days)
                SizedBox(width: width, height: 52)
              else
                Builder(
                  builder: (context) {
                    final date = DateTime(
                      selected.year,
                      selected.month,
                      i - offset + 1,
                    );
                    final rows = meetings.where(
                      (m) => coCalendarSameDay(m.startsAt.toLocal(), date),
                    );
                    final open = rows.any(
                      (m) =>
                          m.state == 'scheduled' && m.available && !m.attending,
                    );
                    final full = rows.any(
                      (m) => m.state == 'scheduled' && m.full && !m.attending,
                    );
                    final other = rows.any(
                      (m) =>
                          m.attending ||
                          !m.available && !m.full ||
                          m.state != 'scheduled',
                    );
                    final chosen = coCalendarSameDay(date, selected);
                    return SizedBox(
                      width: width,
                      height: 52,
                      child: Semantics(
                        button: true,
                        selected: chosen,
                        label: [
                          material.formatFullDate(date),
                          if (open) l.coCalendarAvailable,
                          if (full) l.coGroupsFull,
                          if (other) l.coCalendarTitle,
                        ].join(', '),
                        child: ExcludeSemantics(
                          child: InkWell(
                            key: ValueKey('co-calendar-day-${date.day}'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onSelect(date),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: chosen ? colors.primaryContainer : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Broad font metrics must not split a date
                                  // into two lines; full dates stay in semantics
                                  // and the agenda keeps unrestricted text scale.
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      material.formatDecimal(date.day),
                                      maxLines: 1,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: chosen
                                            ? colors.onPrimaryContainer
                                            : colors.onSurface,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (final color in [
                                        if (open) green,
                                        if (full) red,
                                        if (other) colors.onSurfaceVariant,
                                      ])
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const SizedBox(
                                              width: 5,
                                              height: 5,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ],
        );
      },
    );
  }
}
