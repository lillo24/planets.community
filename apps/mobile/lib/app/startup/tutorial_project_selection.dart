import '../../features/proposals/domain/proposal_models.dart';

/// Matches the rendered sections, including phase-filtered Requested entries.
List<ProposalSummary> tutorialDisplayedProjects(PublicProposalsState state) => [
  ...state.visibleRequestedItems.map((item) => item.proposal),
  ...state.ordinaryItems,
];

/// Checks at most two covers: the third card, then the first other covered card.
/// Failed/late images retain their normal UI fallback; selection never waits for
/// every image or fetches another public page. The caller bounds each check.
Future<ProposalSummary?> selectTutorialProject(
  List<ProposalSummary> displayed, {
  required Future<bool> Function(String path) usableCover,
}) async {
  if (displayed.isEmpty) return null;
  final fallback = displayed.length >= 3 ? displayed[2] : displayed.first;
  final candidates = [
    if (displayed.length >= 3 && displayed[2].coverObjectPath != null)
      displayed[2],
    ...displayed
        .where(
          (item) =>
              item.coverObjectPath != null &&
              (displayed.length < 3 ||
                  item.coverObjectPath != displayed[2].coverObjectPath),
        )
        .take(1),
  ];
  final checked = <String>{};
  for (final candidate in candidates) {
    final path = candidate.coverObjectPath!;
    if (checked.add(path) && await usableCover(path)) return candidate;
  }
  return fallback;
}
