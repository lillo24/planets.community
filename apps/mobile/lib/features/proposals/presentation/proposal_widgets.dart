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
                    Text(
                      AppLocalizations.of(context).proposalSkillsTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    ProposalSkillRequirements(
                      skills: proposal.skills,
                      multiline:
                          MediaQuery.textScalerOf(context).scale(14) > 18,
                    ),
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
