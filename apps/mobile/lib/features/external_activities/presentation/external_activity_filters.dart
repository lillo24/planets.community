import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/external_activity.dart';

/// One server filter shared by the list and map. This widget owns no data reads.
class ExternalActivityFilters extends StatelessWidget {
  const ExternalActivityFilters({
    required this.filter,
    required this.disciplines,
    required this.onChanged,
    super.key,
  });
  final ExternalActivityFilter filter;
  final List<String> disciplines;
  final ValueChanged<ExternalActivityFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.xSmall,
          children: [
            for (final category in [null, 'sports', 'culture'])
              ChoiceChip(
                key: Key('activities-category-${category ?? 'all'}'),
                selected: filter.category == category,
                label: Text(switch (category) {
                  'sports' => l.activitiesSports,
                  'culture' => l.activitiesCulture,
                  _ => l.activitiesAll,
                }),
                onSelected: (_) => onChanged(
                  ExternalActivityFilter(
                    category: category,
                    area: filter.area,
                    query: filter.query,
                    // Discipline is sports-specific. Culture has no place lane.
                    kind:
                        category == 'culture' &&
                            filter.kind == ExternalActivityKind.place
                        ? null
                        : filter.kind,
                    from: filter.from,
                    to: filter.to,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.small),
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.xSmall,
          children: [
            for (final kind in [null, ...ExternalActivityKind.values])
              if (kind != ExternalActivityKind.place ||
                  filter.category != 'culture')
                ChoiceChip(
                  key: Key('activities-kind-${kind?.name ?? 'all'}'),
                  selected: filter.kind == kind,
                  label: Text(externalKindLabel(kind, l)),
                  onSelected: (_) => onChanged(
                    ExternalActivityFilter(
                      category: filter.category,
                      area: filter.area,
                      query: filter.query,
                      discipline: filter.discipline,
                      kind: kind,
                      from: kind == ExternalActivityKind.place
                          ? null
                          : filter.from,
                      to: kind == ExternalActivityKind.place ? null : filter.to,
                    ),
                  ),
                ),
          ],
        ),
        ExpansionTile(
          key: const Key('activities-refine'),
          tilePadding: EdgeInsets.zero,
          title: Text(l.activitiesRefine),
          children: [
            if (filter.category == 'sports' && disciplines.isNotEmpty)
              DropdownButtonFormField<String>(
                key: ValueKey('external-discipline-${filter.discipline}'),
                initialValue: disciplines.contains(filter.discipline)
                    ? filter.discipline
                    : null,
                isExpanded: true,
                itemHeight: null,
                decoration: InputDecoration(labelText: l.activitiesDiscipline),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l.activitiesAllDisciplines),
                  ),
                  for (final discipline in disciplines)
                    DropdownMenuItem(
                      value: discipline,
                      child: Text(externalDisciplineLabel(discipline, l)),
                    ),
                ],
                onChanged: (value) => onChanged(
                  ExternalActivityFilter(
                    category: filter.category,
                    area: filter.area,
                    query: filter.query,
                    kind: filter.kind,
                    discipline: value,
                    from: filter.from,
                    to: filter.to,
                  ),
                ),
              ),
            if (filter.kind != ExternalActivityKind.place) ...[
              Text(l.activitiesDatesScope),
              OutlinedButton.icon(
                key: const Key('activities-dates'),
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  filter.from == null
                      ? l.activitiesChooseDates
                      : '${DateFormat.yMMMd(locale).format(activityDate(filter.from!))}'
                            ' – ${DateFormat.yMMMd(locale).format(activityDate(filter.to!).subtract(const Duration(days: 1)))}',
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 2),
                    initialDateRange: filter.from == null
                        ? null
                        : DateTimeRange(
                            start: activityDate(filter.from!),
                            end: activityDate(filter.to!)
                                .subtract(const Duration(days: 1)),
                          ),
                  );
                  if (range == null || !context.mounted) return;
                  // Canonical API uses an exclusive end, bounded to 90 dates.
                  final from = DateTime.utc(
                    range.start.year,
                    range.start.month,
                    range.start.day,
                  );
                  final to = DateTime.utc(
                    range.end.year,
                    range.end.month,
                    range.end.day + 1,
                  );
                  if (to.difference(from).inDays > 90) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.activitiesDatesTooWide)),
                    );
                    return;
                  }
                  onChanged(
                    ExternalActivityFilter(
                      category: filter.category,
                      area: filter.area,
                      query: filter.query,
                      discipline: filter.discipline,
                      kind: filter.kind,
                      from: from.toIso8601String().substring(0, 10),
                      to: to.toIso8601String().substring(0, 10),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        if (filter.query.isNotEmpty ||
            filter.kind != null ||
            filter.discipline != null ||
            filter.from != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('activities-reset-filters'),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: Text(l.activitiesResetFilters),
              onPressed: () =>
                  onChanged(ExternalActivityFilter(category: filter.category)),
            ),
          ),
      ],
    );
  }
}

String externalKindLabel(ExternalActivityKind? kind, AppLocalizations l) =>
    switch (kind) {
      ExternalActivityKind.event => l.activitiesKindEvents,
      ExternalActivityKind.course => l.activitiesKindCourses,
      ExternalActivityKind.place => l.activitiesKindPlaces,
      null => l.activitiesAll,
    };

/// Only server-provided facets are displayed; unknown source slugs stay visible.
String externalDisciplineLabel(String value, AppLocalizations l) =>
    switch (value) {
      'basketball' => l.activitiesSportBasketball,
      'football' => l.activitiesSportFootball,
      'volleyball' => l.activitiesSportVolleyball,
      'running' => l.activitiesSportRunning,
      'fitness' => l.activitiesSportFitness,
      'skating' => l.activitiesSportSkating,
      'table-tennis' => l.activitiesSportTableTennis,
      'tennis' => l.activitiesSportTennis,
      'bocce' => l.activitiesSportBocce,
      'multi-sport' => l.activitiesSportMulti,
      'yoga' => l.activitiesSportYoga,
      'chess' => l.activitiesSportChess,
      'other-sports' => l.activitiesSportOther,
      _ => value,
    };
