import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/startup/tutorial_project_selection.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';

import '../../support/fake_proposal.dart';

void main() {
  for (final count in [0, 1, 2, 3, 6]) {
    test(
      '$count uncovered cards choose third when available, otherwise first',
      () async {
        final items = [
          for (var i = 0; i < count; i++) proposalSummaryFixture(id: '$i'),
        ];
        final chosen = await selectTutorialProject(
          items,
          usableCover: (_) async => throw StateError('No cover expected'),
        );
        expect(
          chosen?.id,
          count == 0
              ? null
              : count >= 3
              ? '2'
              : '0',
        );
      },
    );
  }
  test('third usable cover wins; otherwise first other covered card, bounded to two reads', () async {
    final items = [
      for (var i = 0; i < 6; i++)
        proposalSummaryFixture(id: '$i', coverObjectPath: '$i.webp'),
    ];
    final reads = <String>[];
    Future<bool> available(String path) async {
      reads.add(path);
      return path != '2.webp';
    }

    expect(
      (await selectTutorialProject(items, usableCover: available))?.id,
      '0',
    );
    expect(reads, ['2.webp', '0.webp']);
    reads.clear();
    expect(
      (await selectTutorialProject(
        items,
        usableCover: (path) async {
          reads.add(path);
          return false;
        },
      ))?.id,
      '2',
    );
    expect(reads, ['2.webp', '0.webp']);
    expect(
      (await selectTutorialProject(items, usableCover: (_) async => true))?.id,
      '2',
    );
  });
  test(
    'first covered card can be beyond the first three already-loaded cards',
    () async {
      final items = [
        for (var i = 0; i < 5; i++)
          proposalSummaryFixture(
            id: '$i',
            coverObjectPath: i == 4 ? 'cover.webp' : null,
          ),
      ];
      expect(
        (await selectTutorialProject(
          items,
          usableCover: (_) async => true,
        ))?.id,
        '4',
      );
    },
  );
  test('candidate order matches visible Requested, deduplication and phase filters', () {
    final idea = proposalSummaryFixture(
      id: 'idea',
      definitionPhase: ProposalDefinitionPhase.idea,
    );
    final requested = proposalSummaryFixture(id: 'requested');
    final ordinary = proposalSummaryFixture(id: 'ordinary');
    final state = PublicProposalsState(
      definitionPhase: ProposalDefinitionPhase.defined,
      items: [requested, ordinary],
      requestedItems: [
        for (final item in [idea, requested])
          RequestedProposalSummary(
            requestId: 'request-${item.id}',
            requestCreatedAt: DateTime.utc(2026),
            proposal: item,
          ),
      ],
    );
    expect(tutorialDisplayedProjects(state).map((p) => p.id), [
      'requested',
      'ordinary',
    ]);
  });
}
