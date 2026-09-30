import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/moderation/data/counterstatement_gateway.dart';

void main() {
  const contract = CounterstatementRpcContract();
  const parser = CounterstatementPayloadParser();

  test(
    'contracts bind recipient identity and trim the immutable statement',
    () {
      expect(
        contract.detailParams(
          expectedProfileId: 'profile-id',
          requestId: 'request-id',
        ),
        {
          'p_expected_recipient_profile_id': 'profile-id',
          'p_request_id': 'request-id',
        },
      );
      expect(
        contract.submitParams(
          expectedProfileId: 'profile-id',
          requestId: 'request-id',
          clientSubmissionId: 'submission-id',
          statement: '  My private response.  ',
        ),
        {
          'p_expected_recipient_profile_id': 'profile-id',
          'p_request_id': 'request-id',
          'p_client_submission_id': 'submission-id',
          'p_statement': 'My private response.',
        },
      );
    },
  );

  test('parses safe recipient detail and a final response', () {
    final detail = parser.detail([
      {
        'request_id': '00000000-0000-4000-8000-000000000921',
        'case_id': '00000000-0000-4000-8000-000000000922',
        'case_state': 'received',
        'category': 'safety_concern',
        'explanation': 'Original report wording.',
        'target_kind': 'resource_request',
        'target_summary': 'Shared ladder request',
        'context_summary': 'Shared ladder',
        'statement': null,
        'submitted_at': null,
        'can_respond': true,
        'created_at': '2026-09-28T10:00:00Z',
      },
    ]);
    final response = parser.response([
      {
        'counterstatement_id': '00000000-0000-4000-8000-000000000925',
        'statement': 'My private response.',
        'created_at': '2026-09-28T10:05:00Z',
      },
    ]);

    expect(detail?.explanation, 'Original report wording.');
    expect(detail?.canRespond, isTrue);
    expect(response.statement, 'My private response.');
  });

  test('rejects untrimmed or malformed response payloads', () {
    expect(
      () => parser.response([
        {
          'counterstatement_id': '00000000-0000-4000-8000-000000000925',
          'statement': ' trailing space ',
          'created_at': '2026-09-28T10:05:00Z',
        },
      ]),
      throwsFormatException,
    );
    expect(
      () => parser.detail([
        {
          'request_id': '00000000-0000-4000-8000-000000000921',
          'case_id': '00000000-0000-4000-8000-000000000922',
          'case_state': 'received',
          'category': 'safety_concern',
          'explanation': 'Original report wording.',
          'target_kind': 'resource_request',
          'target_summary': 'Shared ladder request',
          'context_summary': 'Shared ladder',
          'statement': 'My private response.',
          'submitted_at': null,
          'can_respond': false,
          'created_at': '2026-09-28T10:00:00Z',
        },
      ]),
      throwsFormatException,
    );
  });
}
