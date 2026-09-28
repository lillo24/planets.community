import 'dart:async';

import 'package:planets_mobile/features/moderation/data/moderation_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_models.dart';

class FakeModerationGateway implements ModerationGateway {
  Object? submitError;
  Object? listError;
  Future<void>? submitDelay;
  Future<void>? listDelay;
  List<OwnModerationReport> items = [];
  int submitCount = 0;
  String? expectedProfileId;
  String? clientSubmissionId;
  ModerationCategory? category;
  String? explanation;
  ModerationReportTarget? target;

  @override
  Future<ModerationReportReceipt> submit({
    required String expectedProfileId,
    required String clientSubmissionId,
    required ModerationCategory category,
    required String explanation,
    required ModerationReportTarget target,
  }) async {
    submitCount++;
    this.expectedProfileId = expectedProfileId;
    this.clientSubmissionId = clientSubmissionId;
    this.category = category;
    this.explanation = explanation;
    this.target = target;
    if (submitDelay case final delay?) await delay;
    if (submitError case final error?) throw error;
    return moderationReceiptFixture();
  }

  @override
  Future<List<OwnModerationReport>> listOwn({
    required String expectedProfileId,
  }) async {
    this.expectedProfileId = expectedProfileId;
    if (listDelay case final delay?) await delay;
    if (listError case final error?) throw error;
    return List.unmodifiable(items);
  }
}

ModerationReportReceipt moderationReceiptFixture() => ModerationReportReceipt(
  reportId: '00000000-0000-4000-8000-000000000901',
  caseId: '00000000-0000-4000-8000-000000000902',
  state: ModerationReviewState.received,
  createdAt: DateTime.utc(2026, 9, 28, 10),
);

OwnModerationReport ownModerationReportFixture({
  String reportId = '00000000-0000-4000-8000-000000000901',
  ModerationReviewState state = ModerationReviewState.received,
}) => OwnModerationReport(
  reportId: reportId,
  caseId: '00000000-0000-4000-8000-000000000902',
  category: ModerationCategory.safetyConcern,
  explanation: 'A clear and bounded explanation.',
  targetKind: ModerationTargetKind.project,
  targetSummary: 'Community garden',
  contextSummary: 'Community garden',
  state: state,
  createdAt: DateTime.utc(2026, 9, 28, 10),
);
