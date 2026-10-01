import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/moderation/data/moderation_evidence_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_evidence_models.dart';

void main() {
  const contract = ModerationEvidenceRpcContract();
  const parser = ModerationEvidencePayloadParser();

  test('list contract binds identity, pending scope, and bounded limit', () {
    expect(
      contract.listParams(
        expectedProfileId: 'profile-id',
        pendingOnly: true,
        limit: 1,
      ),
      {
        'p_expected_recipient_profile_id': 'profile-id',
        'p_pending_only': true,
        'p_limit': 1,
      },
    );
  });

  test('parses the discriminated safe summary without report wording', () {
    final summary = parser.summary({
      'request_id': '00000000-0000-4000-8000-000000000921',
      'request_kind': 'resource_counterstatement',
      'case_state': 'received',
      'target_kind': 'resource_request',
      'target_summary': 'Shared ladder request',
      'context_summary': 'Shared ladder',
      'responded_at': null,
      'can_respond': true,
      'created_at': '2026-09-28T10:00:00Z',
    });

    expect(summary.kind, ModerationEvidenceKind.resourceCounterstatement);
    expect(summary.canRespond, isTrue);
    expect(summary.contextSummary, 'Shared ladder');
  });

  test('rejects unknown evidence kinds and malformed identifiers', () {
    expect(
      () => parser.summary({
        'request_id': 'not-a-uuid',
        'request_kind': 'vote',
        'case_state': 'received',
        'target_kind': 'profile',
        'target_summary': 'Profile',
        'context_summary': null,
        'responded_at': null,
        'can_respond': true,
        'created_at': '2026-09-28T10:00:00Z',
      }),
      throwsFormatException,
    );
  });
}
