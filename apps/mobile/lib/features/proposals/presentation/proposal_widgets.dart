import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/requested_badge.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../cover_media/presentation/project_cover_image.dart';
import '../domain/proposal_models.dart';
import '../domain/proposal_time.dart';

class ProposalStatusBadge extends StatelessWidget {
  const ProposalStatusBadge({required this.status, super.key});

  final ProposalStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (status) {
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
        key: Key('proposal-status-${status.wireValue}'),
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
            ProjectCoverImage(
              key: Key('proposal-cover-${proposal.id}'),
              title: proposal.title,
              objectPath: proposal.coverObjectPath,
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
                          proposal.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Wrap(
                        spacing: AppSpacing.xSmall,
                        runSpacing: AppSpacing.xSmall,
                        children: [
                          if (isRequested) const RequestedBadge(),
                          ProposalStatusBadge(status: proposal.status),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(proposal.summary),
                  const SizedBox(height: AppSpacing.medium),
                  _IconText(
                    icon: Icons.schedule_outlined,
                    text:
                        '${formatProposalDateTime(proposal.startsAt, proposal.eventTimezone, Localizations.localeOf(context).toLanguageTag())} – '
                        '${formatProposalDateTime(proposal.endsAt, proposal.eventTimezone, Localizations.localeOf(context).toLanguageTag())}',
                  ),
                  const SizedBox(height: AppSpacing.small),
                  _IconText(
                    icon: Icons.location_on_outlined,
                    text: proposal.publicLocationLabel,
                  ),
                  if (proposal.skills.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.medium),
                    ProposalSkillRequirements(skills: proposal.skills),
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
  const ProposalSkillRequirements({required this.skills, super.key});

  final List<ProposalSkill> skills;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.xSmall,
      children: [
        for (final importance in ProposalSkillImportance.values)
          for (final skill in skills.where((s) => s.importance == importance))
            Chip(
              label: Text(
                '${importance == ProposalSkillImportance.required ? l10n.proposalSkillRequired : l10n.proposalSkillUseful}: ${skill.label}',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.proposalLocationTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.small),
        Text(detail.summary.publicLocationLabel),
        const SizedBox(height: AppSpacing.small),
        Text(
          detail.exactLocationRestricted
              ? l10n.proposalExactLocationRestricted
              : detail.exactMeetingText ?? l10n.proposalExactLocationRestricted,
          key: Key(
            detail.exactLocationRestricted
                ? 'proposal-location-restricted'
                : 'proposal-location-public',
          ),
        ),
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
