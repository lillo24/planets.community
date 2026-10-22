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
  cocreatePost('cocreate_post'),
  cocreateRoomMessage('cocreate_room_message'),
  cocreateInterest('cocreate_interest'),
  cocreateContactMessage('cocreate_contact_message'),
  profile('profile'),
  group('group'),
  project('project'),
  proposalTemplate('proposal_template'),
  projectChatMessage('project_chat_message'),
  groupDiscussionMessage('group_discussion_message'),
  resourceListing('resource_listing'),
  resourceRequest('resource_request'),
  resourceChatMessage('resource_chat_message'),
  memberContactRequest('member_contact_request'),
  memberContactMessage('member_contact_message'),
  groupContactRequest('group_contact_request'),
  groupContactMessage('group_contact_message'),
  groupCoordinationProposal('group_coordination_proposal');

  const ModerationTargetKind(this.wireValue);

  final String wireValue;

  static ModerationTargetKind fromWire(String value) => switch (value) {
    'cocreate_post' => ModerationTargetKind.cocreatePost,
    'cocreate_room_message' => ModerationTargetKind.cocreateRoomMessage,
    'cocreate_interest' => ModerationTargetKind.cocreateInterest,
    'cocreate_contact_message' => ModerationTargetKind.cocreateContactMessage,
    'profile' => ModerationTargetKind.profile,
    'group' => ModerationTargetKind.group,
    'project' => ModerationTargetKind.project,
    'proposal_template' => ModerationTargetKind.proposalTemplate,
    'project_chat_message' => ModerationTargetKind.projectChatMessage,
    'group_discussion_message' => ModerationTargetKind.groupDiscussionMessage,
    'resource_listing' => ModerationTargetKind.resourceListing,
    'resource_request' => ModerationTargetKind.resourceRequest,
    'resource_chat_message' => ModerationTargetKind.resourceChatMessage,
    'member_contact_request' => ModerationTargetKind.memberContactRequest,
    'member_contact_message' => ModerationTargetKind.memberContactMessage,
    'group_contact_request' => ModerationTargetKind.groupContactRequest,
    'group_contact_message' => ModerationTargetKind.groupContactMessage,
    'group_coordination_proposal' =>
      ModerationTargetKind.groupCoordinationProposal,
    _ => throw const FormatException('Unsupported moderation target kind.'),
  };
}

enum ModerationContextKind {
  project('project'),
  resourceRequest('resource_request'),
  memberContactChat('member_contact_chat');

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
      kind != ModerationTargetKind.proposalTemplate &&
      kind != ModerationTargetKind.group &&
      (kind == ModerationTargetKind.project ||
          kind == ModerationTargetKind.projectChatMessage ||
          contextKind == ModerationContextKind.project);
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
