import '../../messages/presentation/messages_routes.dart';
import '../../participation/presentation/participation_routes.dart';
import '../domain/notification_models.dart';

String? notificationDestinationRoute(AppNotification notification) {
  if (notification.category == NotificationCategory.matching) {
    if (notification.kind != NotificationKind.matchingAvailable ||
        notification.destinationKind !=
            NotificationDestinationKind.matchingResult ||
        notification.resourceListingId == null) {
      return null;
    }
    return '/resources/${Uri.encodeComponent(notification.resourceListingId!)}';
  }
  if (notification.category == NotificationCategory.resources) {
    if (notification.resourceListingId == null ||
        notification.resourceRequestId == null) {
      return null;
    }
    if (notification.destinationKind ==
        NotificationDestinationKind.resourceRequest) {
      return switch (notification.kind) {
        NotificationKind.resourceRequestReceived ||
        NotificationKind.resourceRequestWithdrawn ||
        NotificationKind.resourceRequestRejected ||
        NotificationKind.resourceRequestListingClosed =>
          resourceRequestMessageRoute(notification.resourceRequestId!),
        _ => null,
      };
    }
    if (notification.destinationKind ==
            NotificationDestinationKind.resourceChat &&
        notification.resourceChatId != null &&
        (notification.kind == NotificationKind.resourceRequestAccepted ||
            notification.kind == NotificationKind.resourceChatMessageReceived ||
            notification.kind.isResourceExchange)) {
      return resourceChatRoute(notification.resourceChatId!);
    }
    return null;
  }
  if (notification.category == NotificationCategory.chat) {
    return switch ((notification.kind, notification.destinationKind)) {
      (
        NotificationKind.chatMessageReceived,
        NotificationDestinationKind.projectChat,
      )
          when notification.chatId != null =>
        projectChatRoute(notification.chatId!),
      _ => null,
    };
  }
  if (notification.category != NotificationCategory.participation) return null;

  return switch ((notification.kind, notification.destinationKind)) {
    (
      NotificationKind.participationRequestReceived ||
          NotificationKind.participationRequestWithdrawn ||
          NotificationKind.participationRequestAccepted ||
          NotificationKind.participationRequestRejected,
      NotificationDestinationKind.participationRequest,
    )
        when notification.requestId != null =>
      participationRequestMessageRoute(notification.requestId!),
    (
      NotificationKind.participantLeft,
      NotificationDestinationKind.projectParticipation,
    )
        when notification.projectId != null &&
            notification.projectKind != null =>
      ParticipationRoutes.participants(
        notification.projectKind!,
        notification.projectId!,
      ),
    (
      NotificationKind.participantRemoved,
      NotificationDestinationKind.projectDetail,
    )
        when notification.projectId != null &&
            notification.projectKind != null =>
      ParticipationRoutes.detail(
        notification.projectKind!,
        notification.projectId!,
      ),
    _ => null,
  };
}
