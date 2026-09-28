import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_models.dart';
import 'package:planets_mobile/features/moderation/presentation/moderation_routes.dart';

void main() {
  test('explanations are trimmed and bounded', () {
    expect(isValidModerationExplanation(' short '), isFalse);
    expect(isValidModerationExplanation(' enough detail '), isTrue);
    expect(
      isValidModerationExplanation(List.filled(4001, 'x').join()),
      isFalse,
    );
  });

  test('surface target helpers preserve canonical target kinds', () {
    const id = '00000000-0000-4000-8000-000000000901';
    expect(
      projectReportTarget(id, 'Project').kind,
      ModerationTargetKind.project,
    );
    expect(projectReportTarget(id, 'Project').hasProjectContext, isTrue);
    expect(
      projectMessageReportTarget(id, 'Message').kind,
      ModerationTargetKind.projectChatMessage,
    );
    expect(
      resourceListingReportTarget(id, 'Listing').kind,
      ModerationTargetKind.resourceListing,
    );
    expect(
      resourceMessageReportTarget(id, 'Message').kind,
      ModerationTargetKind.resourceChatMessage,
    );
  });

  test('submission scope distinguishes target type and context', () {
    const profileId = '00000000-0000-4000-8000-000000000901';
    const projectId = '00000000-0000-4000-8000-000000000902';
    const direct = ModerationReportTarget(
      kind: ModerationTargetKind.profile,
      id: profileId,
      label: 'Profile',
    );
    const contextual = ModerationReportTarget(
      kind: ModerationTargetKind.profile,
      id: profileId,
      label: 'Profile',
      contextKind: ModerationContextKind.project,
      contextId: projectId,
    );
    const project = ModerationReportTarget(
      kind: ModerationTargetKind.project,
      id: profileId,
      label: 'Project',
    );

    expect(direct.submissionScope, isNot(contextual.submissionScope));
    expect(direct.submissionScope, isNot(project.submissionScope));
  });
}
