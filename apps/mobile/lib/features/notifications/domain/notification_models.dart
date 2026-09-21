import '../../participation/domain/participation_models.dart';

enum NotificationCategory {
  participation,
  chat,
  resources,
  unknown;

  static NotificationCategory fromWire(String value) => switch (value) {
    'participation' => NotificationCategory.participation,
    'chat' => NotificationCategory.chat,
    'resources' => NotificationCategory.resources,
    _ => NotificationCategory.unknown,
  };

  String get preferenceWireSlug => switch (this) {
    NotificationCategory.participation => 'participation',
    NotificationCategory.chat => 'chat',
    NotificationCategory.resources => 'resources',
    NotificationCategory.unknown => throw ArgumentError(
      'Unknown notification categories cannot be configured.',
    ),
  };
}

enum NotificationKind {
  participationRequestReceived,
  participationRequestWithdrawn,
  participationRequestAccepted,
  participationRequestRejected,
  participantLeft,
  participantRemoved,
  chatMessageReceived,
  resourceRequestReceived,
  resourceRequestWithdrawn,
  resourceRequestAccepted,
  resourceRequestRejected,
  resourceRequestListingClosed,
  resourceChatMessageReceived,
  resourceExchangeTermsProposed,
  resourceExchangeTermsAccepted,
  resourceExchangeTermsRejected,
  resourceExchangeTermsWithdrawn,
  resourceExchangeMilestoneRecorded,
  resourceExchangeCancelled,
  resourceExchangeCompleted,
  unknown;

  static NotificationKind fromWire(String value) => switch (value) {
    'participation_request_received' =>
      NotificationKind.participationRequestReceived,
    'participation_request_withdrawn' =>
      NotificationKind.participationRequestWithdrawn,
    'participation_request_accepted' =>
      NotificationKind.participationRequestAccepted,
    'participation_request_rejected' =>
      NotificationKind.participationRequestRejected,
    'participant_left' => NotificationKind.participantLeft,
    'participant_removed' => NotificationKind.participantRemoved,
    'chat_message_received' => NotificationKind.chatMessageReceived,
    'resource_request_received' => NotificationKind.resourceRequestReceived,
    'resource_request_withdrawn' => NotificationKind.resourceRequestWithdrawn,
    'resource_request_accepted' => NotificationKind.resourceRequestAccepted,
    'resource_request_rejected' => NotificationKind.resourceRequestRejected,
    'resource_request_listing_closed' =>
      NotificationKind.resourceRequestListingClosed,
    'resource_chat_message_received' =>
      NotificationKind.resourceChatMessageReceived,
    'resource_exchange_terms_proposed' =>
      NotificationKind.resourceExchangeTermsProposed,
    'resource_exchange_terms_accepted' =>
      NotificationKind.resourceExchangeTermsAccepted,
    'resource_exchange_terms_rejected' =>
      NotificationKind.resourceExchangeTermsRejected,
    'resource_exchange_terms_withdrawn' =>
      NotificationKind.resourceExchangeTermsWithdrawn,
    'resource_exchange_milestone_recorded' =>
      NotificationKind.resourceExchangeMilestoneRecorded,
    'resource_exchange_cancelled' => NotificationKind.resourceExchangeCancelled,
    'resource_exchange_completed' => NotificationKind.resourceExchangeCompleted,
    _ => NotificationKind.unknown,
  };

  bool get isResource => switch (this) {
    NotificationKind.resourceRequestReceived ||
    NotificationKind.resourceRequestWithdrawn ||
    NotificationKind.resourceRequestAccepted ||
    NotificationKind.resourceRequestRejected ||
    NotificationKind.resourceRequestListingClosed ||
    NotificationKind.resourceChatMessageReceived ||
    NotificationKind.resourceExchangeTermsProposed ||
    NotificationKind.resourceExchangeTermsAccepted ||
    NotificationKind.resourceExchangeTermsRejected ||
    NotificationKind.resourceExchangeTermsWithdrawn ||
    NotificationKind.resourceExchangeMilestoneRecorded ||
    NotificationKind.resourceExchangeCancelled ||
    NotificationKind.resourceExchangeCompleted => true,
    _ => false,
  };

  bool get isResourceExchange => switch (this) {
    NotificationKind.resourceExchangeTermsProposed ||
    NotificationKind.resourceExchangeTermsAccepted ||
    NotificationKind.resourceExchangeTermsRejected ||
    NotificationKind.resourceExchangeTermsWithdrawn ||
    NotificationKind.resourceExchangeMilestoneRecorded ||
    NotificationKind.resourceExchangeCancelled ||
    NotificationKind.resourceExchangeCompleted => true,
    _ => false,
  };
}

enum NotificationDestinationKind {
  participationRequest,
  projectParticipation,
  projectDetail,
  projectChat,
  resourceRequest,
  resourceChat,
  unknown;

  static NotificationDestinationKind fromWire(String value) => switch (value) {
    'participation_request' => NotificationDestinationKind.participationRequest,
    'project_participation' => NotificationDestinationKind.projectParticipation,
    'project_detail' => NotificationDestinationKind.projectDetail,
    'project_chat' => NotificationDestinationKind.projectChat,
    'resource_request' => NotificationDestinationKind.resourceRequest,
    'resource_chat' => NotificationDestinationKind.resourceChat,
    _ => NotificationDestinationKind.unknown,
  };
}

enum ResourceNotificationEventKind {
  termsProposed,
  termsAccepted,
  termsRejected,
  termsWithdrawn,
  resourceProvided,
  resourceReceived,
  resourceReturned,
  resourceReturnReceived,
  agreementCancelled,
  agreementCompleted,
  unknown;

  static ResourceNotificationEventKind fromWire(
    String value,
  ) => switch (value) {
    'terms_proposed' => ResourceNotificationEventKind.termsProposed,
    'terms_accepted' => ResourceNotificationEventKind.termsAccepted,
    'terms_rejected' => ResourceNotificationEventKind.termsRejected,
    'terms_withdrawn' => ResourceNotificationEventKind.termsWithdrawn,
    'resource_provided' => ResourceNotificationEventKind.resourceProvided,
    'resource_received' => ResourceNotificationEventKind.resourceReceived,
    'resource_returned' => ResourceNotificationEventKind.resourceReturned,
    'resource_return_received' =>
      ResourceNotificationEventKind.resourceReturnReceived,
    'agreement_cancelled' => ResourceNotificationEventKind.agreementCancelled,
    'agreement_completed' => ResourceNotificationEventKind.agreementCompleted,
    _ => ResourceNotificationEventKind.unknown,
  };

  bool get isMilestone => switch (this) {
    ResourceNotificationEventKind.resourceProvided ||
    ResourceNotificationEventKind.resourceReceived ||
    ResourceNotificationEventKind.resourceReturned ||
    ResourceNotificationEventKind.resourceReturnReceived => true,
    _ => false,
  };
}

enum ResourceNotificationLegKind {
  ownerResource,
  requesterResource,
  unknown;

  static ResourceNotificationLegKind fromWire(String value) => switch (value) {
    'owner_resource' => ResourceNotificationLegKind.ownerResource,
    'requester_resource' => ResourceNotificationLegKind.requesterResource,
    _ => ResourceNotificationLegKind.unknown,
  };
}

class AppNotification {
  const AppNotification({
    required this.notificationId,
    required this.category,
    required this.kind,
    required this.createdAt,
    required this.readAt,
    required this.destinationKind,
    required this.projectId,
    required this.projectKind,
    required this.projectTitle,
    required this.requestId,
    required this.chatId,
    required this.messageId,
    required this.actorProfileId,
    required this.actorDisplayName,
    required this.resourceListingId,
    required this.resourceListingTitle,
    required this.resourceRequestId,
    required this.resourceChatId,
    required this.resourceChatMessageId,
    required this.resourceAgreementId,
    required this.resourceAgreementEventId,
    required this.resourceExchangeEventKind,
    required this.resourceExchangeLegKind,
  });

  final String notificationId;
  final NotificationCategory category;
  final NotificationKind kind;
  final DateTime createdAt;
  final DateTime? readAt;
  final NotificationDestinationKind destinationKind;
  final String? projectId;
  final ProjectKind? projectKind;
  final String? projectTitle;
  final String? requestId;
  final String? chatId;
  final String? messageId;
  final String? actorProfileId;
  final String? actorDisplayName;
  final String? resourceListingId;
  final String? resourceListingTitle;
  final String? resourceRequestId;
  final String? resourceChatId;
  final String? resourceChatMessageId;
  final String? resourceAgreementId;
  final String? resourceAgreementEventId;
  final ResourceNotificationEventKind? resourceExchangeEventKind;
  final ResourceNotificationLegKind? resourceExchangeLegKind;

  bool get isUnread => readAt == null;

  AppNotification withReadAt(DateTime value) => AppNotification(
    notificationId: notificationId,
    category: category,
    kind: kind,
    createdAt: createdAt,
    readAt: value,
    destinationKind: destinationKind,
    projectId: projectId,
    projectKind: projectKind,
    projectTitle: projectTitle,
    requestId: requestId,
    chatId: chatId,
    messageId: messageId,
    actorProfileId: actorProfileId,
    actorDisplayName: actorDisplayName,
    resourceListingId: resourceListingId,
    resourceListingTitle: resourceListingTitle,
    resourceRequestId: resourceRequestId,
    resourceChatId: resourceChatId,
    resourceChatMessageId: resourceChatMessageId,
    resourceAgreementId: resourceAgreementId,
    resourceAgreementEventId: resourceAgreementEventId,
    resourceExchangeEventKind: resourceExchangeEventKind,
    resourceExchangeLegKind: resourceExchangeLegKind,
  );
}

class NotificationPreference {
  const NotificationPreference({
    required this.category,
    required this.sortOrder,
    required this.inAppEnabled,
    required this.pushEnabled,
    required this.hasOverride,
    required this.userConfigurable,
  });

  final NotificationCategory category;
  final int sortOrder;
  final bool inAppEnabled;
  final bool pushEnabled;
  final bool hasOverride;
  final bool userConfigurable;

  NotificationPreference withInAppEnabled(bool value) => NotificationPreference(
    category: category,
    sortOrder: sortOrder,
    inAppEnabled: value,
    pushEnabled: pushEnabled,
    hasOverride: hasOverride,
    userConfigurable: userConfigurable,
  );
}

class NotificationCursor {
  const NotificationCursor({
    required this.createdAt,
    required this.notificationId,
  });

  final DateTime createdAt;
  final String notificationId;
}

class NotificationsPage {
  const NotificationsPage({required this.items, required this.hasMore});

  final List<AppNotification> items;
  final bool hasMore;
}
