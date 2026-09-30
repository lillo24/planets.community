import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/moderation/data/corroboration_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/corroboration_models.dart';

void main() {
  const contract = CorroborationRpcContract();
  const parser = CorroborationPayloadParser();

  test('contracts bind expected recipient and canonical private response', () {
    expect(
      contract.listParams(expectedProfileId: 'profile-id', pendingOnly: true),
      {
        'p_expected_recipient_profile_id': 'profile-id',
        'p_pending_only': true,
        'p_limit': groupCorroborationPageSize,
        'p_before_created_at': null,
        'p_before_request_id': null,
      },
    );
    expect(
      contract.submitParams(
        expectedProfileId: 'profile-id',
        requestId: 'request-id',
        clientSubmissionId: 'submission-id',
        choice: CorroborationChoice.unsure,
        explanation: '  ',
      ),
      {
        'p_expected_recipient_profile_id': 'profile-id',
        'p_request_id': 'request-id',
        'p_client_submission_id': 'submission-id',
        'p_choice': 'unsure',
        'p_explanation': null,
      },
    );
  });

  test('parses only the recipient-owned projection', () {
    final detail = parser.detail([
      {
        'request_id': '00000000-0000-4000-8000-000000000911',
        'case_id': '00000000-0000-4000-8000-000000000912',
        'case_state': 'received',
        'category': 'harassment_abuse',
        'explanation': 'Original wording.',
        'target_kind': 'profile',
        'target_summary': 'Reported profile',
        'context_summary': 'Community garden',
        'response_choice': null,
        'response_explanation': null,
        'responded_at': null,
        'can_respond': true,
        'created_at': '2026-09-28T10:00:00Z',
      },
    ]);
    expect(detail?.canRespond, isTrue);
    expect(detail?.explanation, 'Original wording.');
  });

  test('rejects unknown choices and malformed identity values', () {
    expect(
      () => parser.response([
        {
          'response_id': 'not-a-uuid',
          'choice': 'vote',
          'explanation': null,
          'created_at': '2026-09-28T10:00:00Z',
        },
      ]),
      throwsFormatException,
    );
  });
}
