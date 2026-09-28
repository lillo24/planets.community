import 'moderation_models.dart';

const counterstatementMinLength = 10;
const counterstatementMaxLength = 4000;

class ResourceCounterstatementDetail {
  const ResourceCounterstatementDetail({
    required this.requestId,
    required this.caseId,
    required this.caseState,
    required this.category,
    required this.explanation,
    required this.targetKind,
    required this.targetSummary,
    required this.contextSummary,
    required this.statement,
    required this.submittedAt,
    required this.canRespond,
    required this.createdAt,
  });

  final String requestId;
  final String caseId;
  final ModerationReviewState caseState;
  final ModerationCategory category;
  final String explanation;
  final ModerationTargetKind targetKind;
  final String targetSummary;
  final String? contextSummary;
  final String? statement;
  final DateTime? submittedAt;
  final bool canRespond;
  final DateTime createdAt;
}

class ResourceCounterstatementResponse {
  const ResourceCounterstatementResponse({
    required this.counterstatementId,
    required this.statement,
    required this.createdAt,
  });

  final String counterstatementId;
  final String statement;
  final DateTime createdAt;
}

bool isValidCounterstatement(String value) {
  final length = value.trim().length;
  return length >= counterstatementMinLength &&
      length <= counterstatementMaxLength;
}
