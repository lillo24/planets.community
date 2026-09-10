import '../../messages/presentation/messages_routes.dart';
import '../../participation/presentation/participation_routes.dart';
import '../domain/notification_models.dart';

String? notificationDestinationRoute(AppNotification notification) {
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
