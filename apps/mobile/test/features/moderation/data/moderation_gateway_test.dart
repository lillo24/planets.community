import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/moderation/data/moderation_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_models.dart';

void main() {
  const contract = ModerationRpcContract();
  const parser = ModerationPayloadParser();

  test('submission contract binds identity, idempotency, and context', () {
    final params = contract.submitParams(
      expectedProfileId: 'profile-id',
      clientSubmissionId: 'submission-id',
      category: ModerationCategory.other,
      explanation: '  enough details here  ',
      target: const ModerationReportTarget(
        kind: ModerationTargetKind.profile,
        id: 'target-id',
        label: 'Profile',
        contextKind: ModerationContextKind.project,
        contextId: 'project-id',
      ),
    );

    expect(params, {
      'p_expected_reporter_profile_id': 'profile-id',
      'p_client_submission_id': 'submission-id',
      'p_category': 'other',
      'p_explanation': 'enough details here',
      'p_target_kind': 'profile',
      'p_target_id': 'target-id',
      'p_context_kind': 'project',
      'p_context_id': 'project-id',
    });
    expect(params, isNot(contains('p_subject_profile_id')));
  });

  test('parses the narrow reporter projection and rejects unknown states', () {
    final report = parser.ownReport({
      'report_id': '00000000-0000-4000-8000-000000000901',
      'case_id': '00000000-0000-4000-8000-000000000902',
      'category': 'spam',
      'explanation': 'A report explanation.',
      'target_kind': 'resource_listing',
      'target_summary': 'Shared ladder',
      'context_summary': null,
      'state': 'under_review',
      'created_at': '2026-09-28T10:00:00Z',
    });
    expect(report.state, ModerationReviewState.underReview);
    expect(report.targetSummary, 'Shared ladder');

    expect(
      () => parser.ownReport({
        'report_id': '00000000-0000-4000-8000-000000000901',
        'case_id': '00000000-0000-4000-8000-000000000902',
        'category': 'spam',
        'explanation': 'A report explanation.',
        'target_kind': 'resource_listing',
        'target_summary': 'Shared ladder',
        'context_summary': null,
        'state': 'sanctioned',
        'created_at': '2026-09-28T10:00:00Z',
      }),
      throwsFormatException,
    );
  });
}
