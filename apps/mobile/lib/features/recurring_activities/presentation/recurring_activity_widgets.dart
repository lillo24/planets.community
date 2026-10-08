import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../locations/domain/location_preview.dart';
import '../../locations/presentation/location_preview_panel.dart';

import '../../../core/widgets/requested_badge.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../cover_media/presentation/project_cover_image.dart';
import '../../participation/presentation/project_capacity_label.dart';
import '../../participation/presentation/project_capacity_presentation.dart';
import '../domain/recurring_activity_models.dart';
import 'recurring_occurrence_urgency.dart';

class RecurringActivityCard extends StatelessWidget {
  const RecurringActivityCard({
    required this.activity,
    required this.onTap,
    this.isRequested = false,
    this.now,
    super.key,
  });

  final PublicRecurringActivitySummary activity;
  final VoidCallback onTap;
  final bool isRequested;

  /// Optional reference instant; otherwise urgency is sampled on each build.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final urgency = formatRecurringOccurrenceUrgency(
      activity.nextOccurrence,
      l10n,
      now: now ?? DateTime.now(),
    );
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
            Stack(
              children: [
                ProjectCoverImage(
                  key: Key('tavolo-cover-${activity.id}'),
                  title: activity.title,
                  objectPath: activity.coverObjectPath,
                ),
                if (urgency != null || isRequested)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.small),
                      child: CustomMultiChildLayout(
                        delegate: _CoverBadgeLayout(),
                        children: [
                          if (urgency != null)
                            LayoutId(
                              id: _CoverBadge.urgency,
                              child: _OccurrenceUrgencyBadge(label: urgency),
                            ),
                          if (isRequested)
                            LayoutId(
                              id: _CoverBadge.requested,
                              child: const RequestedBadge(),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(activity.summary),
                  const SizedBox(height: AppSpacing.medium),
                  _MetadataRow(
                    icon: Icons.event_repeat_outlined,
                    text: formatRecurringSchedule(activity.schedule, context),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  LocationPreviewPanel(
                    item: PreviewItem('recurring', activity.id),
                    legacy: LegacyPreviewArea(
                      activity.locality,
                      activity.countryCode,
                    ),
                    publicLabel: activity.publicLocationLabel,
                    labelKey: Key('tavolo-public-location-${activity.id}'),
                  ),
                  ProjectCapacityLabel(
                    capacity: activity.capacity,
                    presentation: ProjectCapacityPresentation.public,
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

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: AppSpacing.small),
      Expanded(child: Text(text)),
    ],
  );
}

class _OccurrenceUrgencyBadge extends StatelessWidget {
  const _OccurrenceUrgencyBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('tavolo-urgency-badge'),
      label: '${AppLocalizations.of(context).tavoliNextMeeting}: $label',
      child: ExcludeSemantics(
        child: Chip(
          label: Text(label),
          avatar: Icon(
            Icons.timer_outlined,
            size: 16,
            color: scheme.onErrorContainer,
          ),
          backgroundColor: scheme.errorContainer,
          labelStyle: TextStyle(
            color: scheme.onErrorContainer,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

enum _CoverBadge { urgency, requested }

/// Measures actual badge widths. At large text sizes the right badge moves
/// below the left badge instead of colliding, retaining both cover-edge anchors.
class _CoverBadgeLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final constraints = BoxConstraints.loose(size);
    Size? urgencySize;
    if (hasChild(_CoverBadge.urgency)) {
      urgencySize = layoutChild(_CoverBadge.urgency, constraints);
      positionChild(_CoverBadge.urgency, Offset.zero);
    }
    if (hasChild(_CoverBadge.requested)) {
      final requestedSize = layoutChild(_CoverBadge.requested, constraints);
      final wrapped =
          urgencySize != null &&
          urgencySize.width + AppSpacing.small + requestedSize.width >
              size.width;
      positionChild(
        _CoverBadge.requested,
        Offset(
          size.width - requestedSize.width,
          wrapped ? urgencySize.height + AppSpacing.xSmall : 0,
        ),
      );
    }
  }

  @override
  bool shouldRelayout(_CoverBadgeLayout oldDelegate) => false;
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
