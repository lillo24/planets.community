import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:planets_mobile/core/theme/app_tokens.dart';
import 'package:planets_mobile/core/widgets/requested_badge.dart';
import 'package:planets_mobile/features/cover_media/presentation/project_cover_image.dart';
import 'package:planets_mobile/features/locations/presentation/public_location_label.dart';
import 'package:planets_mobile/features/participation/presentation/project_capacity_label.dart';
import 'package:planets_mobile/features/participation/presentation/project_capacity_presentation.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

/// A02-only comparison. No production consumer or canonical popularity field.
enum CardComposition { baseline, oppositeRibbons, quietSecondary }

/// Mirrors the current card structure using its real cover, state, schedule and
/// capacity owners. This disposable wrapper keeps candidate composition and
/// synthetic popularity out of the production card's API.
class ProposalCardComparison extends StatelessWidget {
  const ProposalCardComparison({
    required this.proposal,
    required this.composition,
    this.requested = false,
    this.syntheticPopular = false,
    required this.onTap,
    super.key,
  });
  final ProposalSummary proposal;
  final CardComposition composition;
  final bool requested;
  final bool syntheticPopular;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (composition == CardComposition.baseline) {
      return ProposalCard(
        proposal: proposal,
        isRequested: requested,
        onTap: onTap,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final location = shortPublicLocationLabel(
      proposal.locality,
      proposal.publicLocationLabel,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: requested
          ? RoundedRectangleBorder(
              borderRadius: AppRadii.medium,
              side: BorderSide(color: scheme.tertiary, width: 2),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ComparisonCover(
              proposal: proposal,
              composition: composition,
              requested: requested,
              syntheticPopular: syntheticPopular,
            ),
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
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (!proposal.isIdea)
                        ProposalStatusBadge(status: proposal.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(proposal.summary),
                  const SizedBox(height: AppSpacing.medium),
                  _Metadata(
                    Icons.schedule_outlined,
                    proposalScheduleText(context, proposal),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  _Metadata(
                    location == null
                        ? Icons.help_outline
                        : Icons.location_on_outlined,
                    location ?? l10n.proposalPlaceUndecided,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  ProjectCapacityLabel(
                    capacity: proposal.capacity,
                    presentation: ProjectCapacityPresentation.public,
                  ),
                  if (proposal.skills.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      l10n.proposalSkillsTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
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

class ComparisonCover extends StatelessWidget {
  const ComparisonCover({
    required this.proposal,
    required this.composition,
    required this.requested,
    required this.syntheticPopular,
    super.key,
  });
  final ProposalSummary proposal;
  final CardComposition composition;
  final bool requested;
  final bool syntheticPopular;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal =
          constraints.maxWidth < (requested ? 300 : 200) ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      final scheme = Theme.of(context).colorScheme;
      final opposite = composition == CardComposition.oppositeRibbons;
      final idea = ComparisonStateLabel(
        label: 'Idea',
        color: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
        labelKey: const Key('comparison-idea'),
      );
      final popular = ComparisonStateLabel(
        label: Localizations.localeOf(context).languageCode == 'it'
            ? 'Popolare'
            : 'Popular',
        color: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
        labelKey: const Key('comparison-popular'),
      );
      return ClipRect(
        child: Stack(
          children: [
            ProjectCoverImage(
              key: const Key('comparison-cover'),
              title: proposal.title,
              objectPath: proposal.coverObjectPath,
              aspectRatio: 3 / 2,
            ),
            if (horizontal && proposal.isIdea)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (requested) const RequestedBadge(),
                      if (requested && proposal.isIdea)
                        const SizedBox(height: 4),
                      if (proposal.isIdea) idea,
                    ],
                  ),
                ),
              )
            else ...[
              if (proposal.isIdea) ComparisonRibbon(right: true, child: idea),
              if (requested)
                Positioned(
                  top: opposite && proposal.isIdea && syntheticPopular
                      ? null
                      : 8,
                  bottom: opposite && proposal.isIdea && syntheticPopular
                      ? 8
                      : null,
                  left: proposal.isIdea ? 8 : null,
                  right: proposal.isIdea ? null : 8,
                  child: const IgnorePointer(child: RequestedBadge()),
                ),
            ],
            if (syntheticPopular)
              if (opposite && !horizontal)
                ComparisonRibbon(right: false, child: popular)
              else
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: IgnorePointer(child: popular),
                ),
          ],
        ),
      );
    },
  );
}

class ComparisonRibbon extends StatelessWidget {
  const ComparisonRibbon({required this.right, required this.child, super.key});
  final bool right;
  final Widget child;
  @override
  Widget build(BuildContext context) => Positioned(
    top: 24,
    right: right ? -36 : null,
    left: right ? null : -36,
    width: 164,
    child: IgnorePointer(
      child: Transform.rotate(
        angle: (right ? 1 : -1) * math.pi / 6,
        child: child,
      ),
    ),
  );
}

class ComparisonStateLabel extends StatelessWidget {
  const ComparisonStateLabel({
    required this.label,
    required this.color,
    required this.foreground,
    required this.labelKey,
    super.key,
  });
  final String label;
  final Color color;
  final Color foreground;
  final Key labelKey;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    key: labelKey,
    label: label,
    child: ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(color: color),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Metadata extends StatelessWidget {
  const _Metadata(this.icon, this.text);
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
