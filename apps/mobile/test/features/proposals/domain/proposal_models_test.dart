import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';

import '../../../support/fake_proposal.dart';

void main() {
  test('requested deduplication never mutates raw public page state', () {
    final state = PublicProposalsState(
      items: [
        proposalSummaryFixture(id: 'requested'),
        proposalSummaryFixture(id: 'ordinary'),
      ],
      requestedItems: [requestedProposalFixture(proposalId: 'requested')],
      hasMore: true,
    );

    expect(state.items.map((item) => item.id), ['requested', 'ordinary']);
    expect(state.ordinaryItems.single.id, 'ordinary');
    expect(state.hasMore, isTrue);
  });

  test('capacity may be omitted in a draft but is required to publish', () {
    final input = proposalInputFixture(peopleCapacity: null);

    expect(isValidProposalDraft(input), isTrue);
    expect(isPublishableProposalInput(input), isFalse);
  });
}
