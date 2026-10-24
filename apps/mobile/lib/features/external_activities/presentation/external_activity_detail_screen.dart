import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/backend/public_external_link.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/application/activities_split_preference_controller.dart';
import '../application/external_activities_controller.dart';
import '../domain/external_activity.dart';
import 'external_activity_widgets.dart';
import 'external_activity_filters.dart';
import '../../co_creation/presentation/co_creation_event_widgets.dart';
import 'external_activity_share_actions.dart';

class ExternalActivityDetailScreen extends ConsumerWidget {
  const ExternalActivityDetailScreen({required this.activityId, super.key});
  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(activitiesSplitPreferenceProvider).enabled ||
        !TickerMode.valuesOf(context).enabled ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final detail = ref.watch(externalActivityDetailProvider(activityId));
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l.activitiesExternalDetail)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: detail.when(
              loading: () => Center(child: Text(l.activitiesExternalLoading)),
              error: (_, _) => ListView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  Text(l.activitiesExternalReadFailed),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      externalActivityDetailProvider(activityId),
                    ),
                    child: Text(l.retryAction),
                  ),
                ],
              ),
              data: (item) => ListView(
                key: const Key('external-activity-detail'),
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: item == null
                    ? [Text(l.activitiesExternalMissing)]
                    : [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(externalKindLabel(item.kind, l)),
                        Text(l.activitiesSourceLabel(item.sourceName)),
                        if (item.activityType != null)
                          Text(
                            externalActivityTypeLabel(item.activityType!, l),
                          ),
                        if (item.discipline != null)
                          Text(externalDisciplineLabel(item.discipline!, l)),
                        // The existing D03 handoff revalidates the event-only V1
                        // reader. Courses/places have no event participation.
                        if (item.kind == ExternalActivityKind.event)
                          CoEventPeopleAction(item: item),
                        const SizedBox(height: AppSpacing.medium),
                        if (item.status == 'cancelled')
                          Text(l.activitiesExternalCancelled),
                        if (item.stale)
                          Text(
                            item.kind == ExternalActivityKind.place
                                ? l.activitiesPlaceStale
                                : l.activitiesExternalStaleRecord,
                          ),
                        if (item.nextOccurrence != null &&
                            !item.occurrences.any(
                              (occurrence) => occurrence.startInstant
                                  .isAtSameMomentAs(item.nextAt!),
                            ))
                          Text(
                            externalOccurrenceLabel(
                              item.nextOccurrence!,
                              locale,
                              l,
                            ),
                          ),
                        for (final occurrence in item.occurrences)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.small,
                            ),
                            child: Text(
                              externalOccurrenceLabel(occurrence, locale, l),
                            ),
                          ),
                        if (item.kind == ExternalActivityKind.course) ...[
                          Text(externalCourseLabel(item.schedule, locale, l)),
                          if (item.nextOccurrence == null)
                            Text(l.activitiesNextSessionUnknown),
                        ],
                        if (item.kind == ExternalActivityKind.event &&
                            item.occurrences.isEmpty &&
                            item.nextOccurrence == null)
                          Text(l.activitiesExternalScheduleUnknown),
                        if (item.venue != null || item.city != null)
                          Text([item.venue, item.city].nonNulls.join(' · ')),
                        for (final text in [
                          item.address,
                          item.organizer,
                          item.audience,
                          item.cost,
                          item.level,
                          item.access,
                        ].nonNulls)
                          Text(text),
                        const SizedBox(height: AppSpacing.medium),
                        if (item.description != null) Text(item.description!),
                        if (item.sourceCategories.isNotEmpty)
                          Text(item.sourceCategories.join(' · ')),
                        const SizedBox(height: AppSpacing.large),
                        Text(item.attribution),
                        Text(
                          l.activitiesObservedAt(
                            '${DateFormat.yMMMd(locale).add_Hm().format(item.observedAt.toUtc())} UTC',
                          ),
                        ),
                        TextButton(
                          key: const Key('external-activity-official-link'),
                          onPressed: () =>
                              _open(context, ref, item.officialLink),
                          child: Text(
                            item.linkScope == ExternalActivityLinkScope.dataset
                                ? l.activitiesDatasetLink
                                : l.activitiesOfficialInformation,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              _open(context, ref, item.licenseLink),
                          child: Text(l.activitiesSourceLicense),
                        ),
                        ExternalActivityShareActions(activity: item),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    PublicExternalLink link,
  ) async {
    final opened = await ref
        .read(publicExternalLinkLauncherProvider)
        .open(link);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).activitiesLinkFailed),
        ),
      );
    }
  }
}
