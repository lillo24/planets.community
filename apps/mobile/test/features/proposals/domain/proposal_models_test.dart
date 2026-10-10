import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';

import '../../../support/fake_proposal.dart';

void main() {
  test(
    'defined publication needs a city and schedule but no precise details',
    () {
      expect(
        isPublishableProposalInput(proposalInputFixture(exactMeetingText: '')),
        isTrue,
      );
      expect(
        isPublishableProposalInput(
          proposalInputFixture(locality: '', exactMeetingText: ''),
        ),
        isFalse,
      );
      expect(
        isPublishableProposalInput(
          proposalInputFixture(countryCode: 'ITA', exactMeetingText: ''),
        ),
        isFalse,
      );
      expect(
        isPublishableProposalInput(
          proposalInputFixture(
            endsAt: DateTime.utc(2026, 9, 1),
            exactMeetingText: '',
          ),
        ),
        isFalse,
      );
    },
  );

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
    final input = proposalInputFixture(registrationCapacity: null);

    expect(isValidProposalDraft(input), isTrue);
    expect(isPublishableProposalInput(input), isFalse);
  });
}
