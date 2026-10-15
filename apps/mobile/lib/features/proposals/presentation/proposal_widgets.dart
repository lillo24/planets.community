import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../group_projects/presentation/group_project_widgets.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../locations/presentation/location_attribution.dart';
import '../../locations/presentation/public_location_label.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'proposal_card_cover.dart';
import '../../participation/presentation/project_capacity_label.dart';
import '../../participation/presentation/project_capacity_presentation.dart';
import '../domain/proposal_models.dart';
import '../domain/proposal_time.dart';

class ProposalStatusBadge extends StatelessWidget {
  const ProposalStatusBadge({
    required this.status,
    this.isIdea = false,
    super.key,
  });

  final ProposalStatus? status;
  final bool isIdea;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = isIdea
        ? l10n.proposalPhaseIdea
        : switch (status) {
            null => l10n.proposalPhaseDefined,
            ProposalStatus.upcoming => l10n.proposalStatusUpcoming,
            ProposalStatus.happening => l10n.proposalStatusHappening,
            ProposalStatus.justFinished => l10n.proposalStatusJustFinished,
            ProposalStatus.completed => l10n.proposalStatusCompleted,
          };
    final scheme = Theme.of(context).colorScheme;
    final justFinished = status == ProposalStatus.justFinished;

    return Semantics(
      label: label,
      child: Chip(
        key: Key(
          'proposal-status-${isIdea ? 'idea' : status?.wireValue ?? 'defined'}',
        ),
        label: Text(label),
        backgroundColor: justFinished
            ? Colors.green.shade100
            : scheme.secondaryContainer,
        labelStyle: TextStyle(
          color: justFinished
              ? Colors.green.shade900
              : scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class ProposalCard extends StatelessWidget {
  const ProposalCard({
    required this.proposal,
    required this.onTap,
    this.isRequested = false,
    super.key,
  });

  final ProposalSummary proposal;
  final VoidCallback onTap;
  final bool isRequested;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final location = shortPublicLocationLabel(
      proposal.locality,
      proposal.publicLocationLabel,
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
        key: Key('proposal-card-${proposal.id}'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProposalCardCover(proposal: proposal, isRequested: isRequested),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceBetween,
                    spacing: AppSpacing.small,
                    overflowSpacing: AppSpacing.xSmall,
                    children: [
                      Text(
                        proposal.title,
                        key: Key('proposal-card-title-${proposal.id}'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (!proposal.isIdea)
                        ProposalStatusBadge(status: proposal.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(proposal.summary),
                  ProjectGroupBadge(proposal.groupAttribution),
                  const SizedBox(height: AppSpacing.medium),
                  _IconText(
                    icon: Icons.schedule_outlined,
                    text: proposalScheduleText(context, proposal),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  _IconText(
                    icon: location == null
                        ? Icons.help_outline
                        : Icons.location_on_outlined,
                    text:
                        location ??
                        AppLocalizations.of(context).proposalPlaceUndecided,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  ProjectCapacityLabel(
                    capacity: proposal.capacity,
                    presentation: ProjectCapacityPresentation.public,
                  ),
                  if (proposal.skills.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.medium),
                    ProposalCardSkillPreview(skills: proposal.skills),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact single-row preview. The detail retains all skills and their
/// Required/Useful metadata.
class ProposalCardSkillPreview extends StatelessWidget {
  const ProposalCardSkillPreview({required this.skills, super.key});

  final List<ProposalSkill> skills;

  static const double _gap = AppSpacing.small;
  static const double _pillHorizontalPadding = 10;

  @override
  Widget build(BuildContext context) {
    final ordered = [
      ...skills.where((s) => s.importance == ProposalSkillImportance.required),
      ...skills.where((s) => s.importance == ProposalSkillImportance.useful),
    ];
    if (ordered.isEmpty) return const SizedBox.shrink();

    final style = Theme.of(context).textTheme.labelMedium ??
        const TextStyle(fontSize: 12);
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    double pillWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: direction,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final width = painter.width + _pillHorizontalPadding * 2;
      painter.dispose();
      return width;
    }

    final moreWidth = pillWidth('...');
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final limit = math.min(3, ordered.length);
        var shown = 0;
        var used = 0.0;
        for (var i = 0; i < limit; i++) {
          final next = used +
              (shown == 0 ? 0.0 : _gap) +
              pillWidth(ordered[i].label);
          // Make space for the ellipsis if any skills remain hidden.
          final reserve = i + 1 < ordered.length ? _gap + moreWidth : 0.0;
          if (next + reserve > available) break;
          shown++;
          used = next;
        }

        // An unusually long first label is truncated instead of suppressing
        // the preview altogether.
        if (shown == 0 && available > 0) shown = 1;
        final hasMore = shown < ordered.length;
        final firstMaxWidth = math.max(
          0.0,
          available - (hasMore ? _gap + moreWidth : 0.0),
        );
        final semantics =
            '${AppLocalizations.of(context).proposalSkillsTitle}: '
            '${ordered.map((skill) => skill.label).join(', ')}';

        return Semantics(
          label: semantics,
          child: ExcludeSemantics(
            child: Row(
              key: const Key('proposal-card-skills-preview'),
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < shown; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: i == 0 && shown == 1
                          ? firstMaxWidth
                          : available,
                    ),
                    child: _CardSkillPill(
                      key: Key('proposal-card-skill-${ordered[i].id}'),
                      label: ordered[i].label,
                      style: style,
                    ),
                  ),
                ],
                if (hasMore) ...[
                  if (shown > 0) const SizedBox(width: _gap),
                  _CardSkillPill(
                    key: const Key('proposal-card-skills-more'),
                    label: '...',
                    style: style,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardSkillPill extends StatelessWidget {
  const _CardSkillPill({
    required this.label,
    required this.style,
    super.key,
  });

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ProposalCardSkillPreview._pillHorizontalPadding,
          vertical: AppSpacing.xSmall,
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}

class ProposalSkillRequirements extends StatelessWidget {
  const ProposalSkillRequirements({
    required this.skills,
    this.multiline = false,
    super.key,
  });

  final List<ProposalSkill> skills;
  // Card-only enlarged-text fallback: Chip inherits a single-line label style.
  // Keep the same inert labels and ordering while allowing complete wrapping.
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.xSmall,
      children: [
        for (final importance in ProposalSkillImportance.values)
          for (final skill in skills.where((s) => s.importance == importance))
            _SkillLabel(
              label:
                  '${importance == ProposalSkillImportance.required ? l10n.proposalSkillRequired : l10n.proposalSkillUseful}: ${skill.label}',
              multiline: multiline,
            ),
      ],
    );
  }
}

class _SkillLabel extends StatelessWidget {
  const _SkillLabel({required this.label, required this.multiline});
  final String label;
  final bool multiline;
  @override
  Widget build(BuildContext context) {
    if (!multiline) return Chip(label: Text(label));
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(label, style: theme.textTheme.labelLarge),
      ),
    );
  }
}

/// Display-only Project schedule, formatted in its canonical event timezone.
class ProposalSchedulePanel extends StatelessWidget {
  const ProposalSchedulePanel({required this.proposal, super.key});

  final ProposalSummary proposal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final start = proposal.startsAt;
    final end = proposal.endsAt;
    final zone = proposal.eventTimezone;
    final hasSchedule = start != null && end != null && zone != null;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Card(
      key: const Key('proposal-schedule-panel'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: !hasSchedule
            ? Row(
                children: [
                  const Icon(Icons.event_outlined, size: 24),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(child: Text(l10n.proposalDateUndecided)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ScheduleMoment(
                    key: const Key('proposal-schedule-start'),
                    icon: Icons.event_available_outlined,
                    title: l10n.proposalStartLabel,
                    instant: start,
                    zone: zone,
                    locale: locale,
                  ),
                  const Divider(height: AppSpacing.large),
                  _ScheduleMoment(
                    key: const Key('proposal-schedule-end'),
                    icon: Icons.event_outlined,
                    title: l10n.proposalEndLabel,
                    instant: end,
                    zone: zone,
                    locale: locale,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Row(
                    children: [
                      Icon(
                        Icons.public_outlined,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Expanded(
                        child: Text(
                          zone,
                          key: const Key('proposal-schedule-timezone'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _ScheduleMoment extends StatelessWidget {
  const _ScheduleMoment({
    required this.icon,
    required this.title,
    required this.instant,
    required this.zone,
    required this.locale,
    super.key,
  });

  final IconData icon;
  final String title;
  final DateTime instant;
  final String zone;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wallTime = proposalUtcToWallTime(instant, zone);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadii.medium,
            color: scheme.primaryContainer,
          ),
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, color: scheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: AppSpacing.medium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                DateFormat.MMMEd(locale).add_y().format(wallTime),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                DateFormat.Hm(locale).format(wallTime),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProposalLocation extends StatelessWidget {
  const ProposalLocation({required this.detail, super.key});

  final ProposalDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final instructions = detail.exactLocationRestricted
        ? l10n.proposalExactLocationRestricted
        : detail.exactMeetingText?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.proposalLocationTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.small),
        Text(detail.summary.publicLocationLabel ?? l10n.proposalPlaceUndecided),
        if (instructions != null && instructions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.small),
          Text(
            instructions,
            key: Key(
              detail.exactLocationRestricted
                  ? 'proposal-location-restricted'
                  : 'proposal-location-public',
            ),
          ),
        ],
        const LocationAttribution(),
      ],
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});

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

/// Idea dates are official only after confirmation; phase stays non-operational.
String proposalScheduleText(BuildContext context, ProposalSummary proposal) {
  final l10n = AppLocalizations.of(context);
  final start = proposal.startsAt;
  final end = proposal.endsAt;
  final zone = proposal.eventTimezone;
  if (start == null || end == null || zone == null) {
    return l10n.proposalDateUndecided;
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  final schedule =
      '${formatProposalDateTime(start, zone, locale)} – ${formatProposalDateTime(end, zone, locale)}';
  // CHECK01: only explicitly confirmed canonical schedules reach public reads.
  return schedule;
}
