import 'dart:async';

import 'package:planets_mobile/features/moderation/data/counterstatement_gateway.dart';
import 'package:planets_mobile/features/moderation/data/corroboration_gateway.dart';
import 'package:planets_mobile/features/moderation/data/moderation_evidence_gateway.dart';
import 'package:planets_mobile/features/moderation/data/moderation_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/counterstatement_models.dart';
import 'package:planets_mobile/features/moderation/domain/corroboration_models.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_evidence_models.dart';
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

class FakeCorroborationGateway implements CorroborationGateway {
  Object? listError;
  Object? detailError;
  Object? submitError;
  Future<void>? listDelay;
  Future<void>? submitDelay;
  List<GroupCorroborationSummary> items = [];
  GroupCorroborationDetail? detail = corroborationDetailFixture();
  int listCount = 0;
  int submitCount = 0;
  bool? pendingOnly;
  String? expectedProfileId;
  String? requestId;
  String? clientSubmissionId;
  CorroborationChoice? choice;
  String? explanation;

  @override
  Future<List<GroupCorroborationSummary>> listOwn({
    required String expectedProfileId,
    required bool pendingOnly,
  }) async {
    listCount++;
    this.expectedProfileId = expectedProfileId;
    this.pendingOnly = pendingOnly;
    if (listDelay case final delay?) await delay;
    if (listError case final error?) throw error;
    return List.unmodifiable(items);
  }

  @override
  Future<GroupCorroborationDetail?> getOwn({
    required String expectedProfileId,
    required String requestId,
  }) async {
    this.expectedProfileId = expectedProfileId;
    this.requestId = requestId;
    if (detailError case final error?) throw error;
    return detail;
  }

  @override
  Future<GroupCorroborationResponse> submit({
    required String expectedProfileId,
    required String requestId,
    required String clientSubmissionId,
    required CorroborationChoice choice,
    required String explanation,
  }) async {
    submitCount++;
    this.expectedProfileId = expectedProfileId;
    this.requestId = requestId;
    this.clientSubmissionId = clientSubmissionId;
    this.choice = choice;
    this.explanation = explanation;
    if (submitDelay case final delay?) await delay;
    if (submitError case final error?) throw error;
    return GroupCorroborationResponse(
      responseId: '00000000-0000-4000-8000-000000000915',
      choice: choice,
      explanation: explanation.trim().isEmpty ? null : explanation.trim(),
      createdAt: DateTime.utc(2026, 9, 28, 10, 5),
    );
  }
}

GroupCorroborationSummary corroborationSummaryFixture({
  bool canRespond = true,
  CorroborationChoice? responseChoice,
}) => GroupCorroborationSummary(
  requestId: '00000000-0000-4000-8000-000000000911',
  caseId: '00000000-0000-4000-8000-000000000912',
  caseState: ModerationReviewState.received,
  targetKind: ModerationTargetKind.profile,
  targetSummary: 'Reported profile',
  contextSummary: 'Community garden',
  responseChoice: responseChoice,
  respondedAt: responseChoice == null ? null : DateTime.utc(2026, 9, 28, 10, 5),
  canRespond: canRespond,
  createdAt: DateTime.utc(2026, 9, 28, 10),
);

GroupCorroborationDetail corroborationDetailFixture({
  bool canRespond = true,
  CorroborationChoice? responseChoice,
}) => GroupCorroborationDetail(
  requestId: '00000000-0000-4000-8000-000000000911',
  caseId: '00000000-0000-4000-8000-000000000912',
  caseState: ModerationReviewState.received,
  category: ModerationCategory.harassmentAbuse,
  explanation: 'The original reporter wording.',
  targetKind: ModerationTargetKind.profile,
  targetSummary: 'Reported profile',
  contextSummary: 'Community garden',
  responseChoice: responseChoice,
  responseExplanation: null,
  respondedAt: null,
  canRespond: canRespond,
  createdAt: DateTime.utc(2026, 9, 28, 10),
);

class FakeModerationEvidenceGateway implements ModerationEvidenceGateway {
  Object? listError;
  Future<void>? listDelay;
  List<ModerationEvidenceSummary> items = [];
  int listCount = 0;
  String? expectedProfileId;
  bool? pendingOnly;
  int? limit;

  @override
  Future<List<ModerationEvidenceSummary>> listOwn({
    required String expectedProfileId,
    required bool pendingOnly,
    int limit = moderationEvidencePageSize,
  }) async {
    listCount++;
    this.expectedProfileId = expectedProfileId;
    this.pendingOnly = pendingOnly;
    this.limit = limit;
    if (listDelay case final delay?) await delay;
    if (listError case final error?) throw error;
    return List.unmodifiable(items.take(limit));
  }
}

ModerationEvidenceSummary moderationEvidenceSummaryFixture({
  String requestId = '00000000-0000-4000-8000-000000000921',
  ModerationEvidenceKind kind = ModerationEvidenceKind.resourceCounterstatement,
  bool canRespond = true,
  DateTime? respondedAt,
  DateTime? createdAt,
}) => ModerationEvidenceSummary(
  requestId: requestId,
  kind: kind,
  caseState: ModerationReviewState.received,
  targetKind: ModerationTargetKind.resourceRequest,
  targetSummary: 'Shared ladder request',
  contextSummary: 'Shared ladder',
  respondedAt: respondedAt,
  canRespond: canRespond,
  createdAt: createdAt ?? DateTime.utc(2026, 9, 28, 10),
);

class FakeCounterstatementGateway implements CounterstatementGateway {
  Object? detailError;
  Object? submitError;
  Future<void>? detailDelay;
  Future<void>? submitDelay;
  ResourceCounterstatementDetail? detail = counterstatementDetailFixture();
  int detailCount = 0;
  int submitCount = 0;
  String? expectedProfileId;
  String? requestId;
  String? clientSubmissionId;
  String? statement;

  @override
  Future<ResourceCounterstatementDetail?> getOwn({
    required String expectedProfileId,
    required String requestId,
  }) async {
    detailCount++;
    this.expectedProfileId = expectedProfileId;
    this.requestId = requestId;
    if (detailDelay case final delay?) await delay;
    if (detailError case final error?) throw error;
    return detail;
  }

  @override
  Future<ResourceCounterstatementResponse> submit({
    required String expectedProfileId,
    required String requestId,
    required String clientSubmissionId,
    required String statement,
  }) async {
    submitCount++;
    this.expectedProfileId = expectedProfileId;
    this.requestId = requestId;
    this.clientSubmissionId = clientSubmissionId;
    this.statement = statement;
    if (submitDelay case final delay?) await delay;
    if (submitError case final error?) throw error;
    return ResourceCounterstatementResponse(
      counterstatementId: '00000000-0000-4000-8000-000000000925',
      statement: statement.trim(),
      createdAt: DateTime.utc(2026, 9, 28, 10, 5),
    );
  }
}

ResourceCounterstatementDetail counterstatementDetailFixture({
  bool canRespond = true,
  String? statement,
}) => ResourceCounterstatementDetail(
  requestId: '00000000-0000-4000-8000-000000000921',
  caseId: '00000000-0000-4000-8000-000000000922',
  caseState: canRespond
      ? ModerationReviewState.received
      : ModerationReviewState.completed,
  category: ModerationCategory.safetyConcern,
  explanation: 'The original Resource request report wording.',
  targetKind: ModerationTargetKind.resourceRequest,
  targetSummary: 'Shared ladder request',
  contextSummary: 'Shared ladder',
  statement: statement,
  submittedAt: statement == null ? null : DateTime.utc(2026, 9, 28, 10, 5),
  canRespond: canRespond && statement == null,
  createdAt: DateTime.utc(2026, 9, 28, 10),
);
