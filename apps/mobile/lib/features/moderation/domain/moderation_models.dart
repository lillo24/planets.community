const moderationExplanationMinLength = 10;
const moderationExplanationMaxLength = 4000;

enum ModerationCategory {
  safetyConcern('safety_concern'),
  harassmentAbuse('harassment_abuse'),
  fraudScam('fraud_scam'),
  inappropriateContentConduct('inappropriate_content_conduct'),
  spam('spam'),
  other('other');

  const ModerationCategory(this.wireValue);

  final String wireValue;

  static ModerationCategory fromWire(String value) => switch (value) {
    'safety_concern' => ModerationCategory.safetyConcern,
    'harassment_abuse' => ModerationCategory.harassmentAbuse,
    'fraud_scam' => ModerationCategory.fraudScam,
    'inappropriate_content_conduct' =>
      ModerationCategory.inappropriateContentConduct,
    'spam' => ModerationCategory.spam,
    'other' => ModerationCategory.other,
    _ => throw const FormatException('Unsupported moderation category.'),
  };
}

enum ModerationTargetKind {
  profile('profile'),
  project('project'),
  projectChatMessage('project_chat_message'),
  resourceListing('resource_listing'),
  resourceRequest('resource_request'),
  resourceChatMessage('resource_chat_message');

  const ModerationTargetKind(this.wireValue);

  final String wireValue;

  static ModerationTargetKind fromWire(String value) => switch (value) {
    'profile' => ModerationTargetKind.profile,
    'project' => ModerationTargetKind.project,
    'project_chat_message' => ModerationTargetKind.projectChatMessage,
    'resource_listing' => ModerationTargetKind.resourceListing,
    'resource_request' => ModerationTargetKind.resourceRequest,
    'resource_chat_message' => ModerationTargetKind.resourceChatMessage,
    _ => throw const FormatException('Unsupported moderation target kind.'),
  };
}

enum ModerationContextKind {
  project('project'),
  resourceRequest('resource_request');

  const ModerationContextKind(this.wireValue);

  final String wireValue;
}

enum ModerationReviewState {
  received('received'),
  underReview('under_review'),
  completed('completed');

  const ModerationReviewState(this.wireValue);

  final String wireValue;

  static ModerationReviewState fromWire(String value) => switch (value) {
    'received' => ModerationReviewState.received,
    'under_review' => ModerationReviewState.underReview,
    'completed' => ModerationReviewState.completed,
    _ => throw const FormatException('Unsupported moderation review state.'),
  };
}

class ModerationReportTarget {
  const ModerationReportTarget({
    required this.kind,
    required this.id,
    required this.label,
    this.contextKind,
    this.contextId,
  }) : assert(
         (contextKind == null) == (contextId == null),
         'Context kind and identifier must be provided together.',
       );

  final ModerationTargetKind kind;
  final String id;
  final String label;
  final ModerationContextKind? contextKind;
  final String? contextId;

  String get submissionScope =>
      '${kind.wireValue}:$id:${contextKind?.wireValue ?? ''}:${contextId ?? ''}';

  bool get hasProjectContext =>
      kind == ModerationTargetKind.project ||
      kind == ModerationTargetKind.projectChatMessage ||
      contextKind == ModerationContextKind.project;
}

class ModerationReportReceipt {
  const ModerationReportReceipt({
    required this.reportId,
    required this.caseId,
    required this.state,
    required this.createdAt,
  });

  final String reportId;
  final String caseId;
  final ModerationReviewState state;
  final DateTime createdAt;
}

class OwnModerationReport {
  const OwnModerationReport({
    required this.reportId,
    required this.caseId,
    required this.category,
    required this.explanation,
    required this.targetKind,
    required this.targetSummary,
    required this.contextSummary,
    required this.state,
    required this.createdAt,
  });

  final String reportId;
  final String caseId;
  final ModerationCategory category;
  final String explanation;
  final ModerationTargetKind targetKind;
  final String targetSummary;
  final String? contextSummary;
  final ModerationReviewState state;
  final DateTime createdAt;
}

bool isValidModerationExplanation(String value) {
  final length = value.trim().length;
  return length >= moderationExplanationMinLength &&
      length <= moderationExplanationMaxLength;
}
