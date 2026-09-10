import '../../participation/domain/participation_models.dart';

enum NotificationCategory {
  participation,
  unknown;

  static NotificationCategory fromWire(String value) => switch (value) {
    'participation' => NotificationCategory.participation,
    _ => NotificationCategory.unknown,
  };
}

enum NotificationKind {
  participationRequestReceived,
  participationRequestWithdrawn,
  participationRequestAccepted,
  participationRequestRejected,
  participantLeft,
  participantRemoved,
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
    _ => NotificationKind.unknown,
  };
}

enum NotificationDestinationKind {
  participationRequest,
  projectParticipation,
  projectDetail,
  unknown;

  static NotificationDestinationKind fromWire(String value) => switch (value) {
    'participation_request' => NotificationDestinationKind.participationRequest,
    'project_participation' => NotificationDestinationKind.projectParticipation,
    'project_detail' => NotificationDestinationKind.projectDetail,
    _ => NotificationDestinationKind.unknown,
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
    required this.actorProfileId,
    required this.actorDisplayName,
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
  final String? actorProfileId;
  final String? actorDisplayName;

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
    actorProfileId: actorProfileId,
    actorDisplayName: actorDisplayName,
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
