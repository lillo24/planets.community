import 'moderation_models.dart';

enum ModerationEvidenceKind {
  groupCorroboration('group_corroboration'),
  resourceCounterstatement('resource_counterstatement');

  const ModerationEvidenceKind(this.wireValue);

  final String wireValue;

  static ModerationEvidenceKind fromWire(String value) => switch (value) {
    'group_corroboration' => ModerationEvidenceKind.groupCorroboration,
    'resource_counterstatement' =>
      ModerationEvidenceKind.resourceCounterstatement,
    _ => throw const FormatException('Unsupported moderation evidence kind.'),
  };
}

class ModerationEvidenceSummary {
  const ModerationEvidenceSummary({
    required this.requestId,
    required this.kind,
    required this.caseState,
    required this.targetKind,
    required this.targetSummary,
    required this.contextSummary,
    required this.respondedAt,
    required this.canRespond,
    required this.createdAt,
  });

  final String requestId;
  final ModerationEvidenceKind kind;
  final ModerationReviewState caseState;
  final ModerationTargetKind targetKind;
  final String targetSummary;
  final String? contextSummary;
  final DateTime? respondedAt;
  final bool canRespond;
  final DateTime createdAt;
}
