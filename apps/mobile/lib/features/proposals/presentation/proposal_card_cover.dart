import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/requested_badge.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../cover_media/presentation/project_cover_image.dart';
import '../domain/proposal_models.dart';

/// A02's selected composition for real canonical Idea/Requested state only.
class ProposalCardCover extends StatelessWidget {
  const ProposalCardCover({
    required this.proposal,
    required this.isRequested,
    super.key,
  });
  final ProposalSummary proposal;
  final bool isRequested;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Compare effective label size instead of assuming linear text scaling.
      // Requested retains priority when the two essential labels cannot share
      // the upper corners. No text is shrunk to fit the diagonal.
      final horizontal =
          constraints.maxWidth < (isRequested ? 300 : 200) ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      final label = _IdeaLabel(id: proposal.id);
      return ClipRect(
        child: Stack(
          children: [
            ProjectCoverImage(
              key: Key('proposal-cover-${proposal.id}'),
              title: proposal.title,
              objectPath: proposal.coverObjectPath,
              aspectRatio: 3 / 2,
            ),
            if (proposal.isIdea && horizontal)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isRequested) const RequestedBadge(),
                      if (isRequested) const SizedBox(height: 4),
                      label,
                    ],
                  ),
                ),
              )
            else ...[
              if (proposal.isIdea)
                Positioned(
                  top: 24,
                  right: -36,
                  width: 164,
                  child: IgnorePointer(
                    child: Transform.rotate(angle: math.pi / 6, child: label),
                  ),
                ),
              if (isRequested)
                Positioned(
                  top: 8,
                  left: proposal.isIdea ? 8 : null,
                  right: proposal.isIdea ? null : 8,
                  child: const RequestedBadge(),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _IdeaLabel extends StatelessWidget {
  const _IdeaLabel({required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      key: Key('proposal-idea-ribbon-$id'),
      label: '${l10n.proposalIdeaRibbon}. ${l10n.proposalPhaseIdea}',
      child: ExcludeSemantics(
        child: ColoredBox(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              l10n.proposalIdeaRibbon,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
