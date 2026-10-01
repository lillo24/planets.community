import 'moderation_models.dart';

const corroborationExplanationMaxLength = 4000;

enum CorroborationChoice {
  agree('agree'),
  disagree('disagree'),
  unsure('unsure');

  const CorroborationChoice(this.wireValue);

  final String wireValue;

  static CorroborationChoice fromWire(String value) => switch (value) {
    'agree' => CorroborationChoice.agree,
    'disagree' => CorroborationChoice.disagree,
    'unsure' => CorroborationChoice.unsure,
    _ => throw const FormatException('Unsupported corroboration choice.'),
  };
}

class GroupCorroborationSummary {
  const GroupCorroborationSummary({
    required this.requestId,
    required this.caseId,
    required this.caseState,
    required this.targetKind,
    required this.targetSummary,
    required this.contextSummary,
    required this.responseChoice,
    required this.respondedAt,
    required this.canRespond,
    required this.createdAt,
  });

  final String requestId;
  final String caseId;
  final ModerationReviewState caseState;
  final ModerationTargetKind targetKind;
  final String targetSummary;
  final String? contextSummary;
  final CorroborationChoice? responseChoice;
  final DateTime? respondedAt;
  final bool canRespond;
  final DateTime createdAt;
}

class GroupCorroborationDetail {
  const GroupCorroborationDetail({
    required this.requestId,
    required this.caseId,
    required this.caseState,
    required this.category,
    required this.explanation,
    required this.targetKind,
    required this.targetSummary,
    required this.contextSummary,
    required this.responseChoice,
    required this.responseExplanation,
    required this.respondedAt,
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
  final CorroborationChoice? responseChoice;
  final String? responseExplanation;
  final DateTime? respondedAt;
  final bool canRespond;
  final DateTime createdAt;
}

class GroupCorroborationResponse {
  const GroupCorroborationResponse({
    required this.responseId,
    required this.choice,
    required this.explanation,
    required this.createdAt,
  });

  final String responseId;
  final CorroborationChoice choice;
  final String? explanation;
  final DateTime createdAt;
}

bool isValidCorroborationExplanation(String value) =>
    value.trim().length <= corroborationExplanationMaxLength;
