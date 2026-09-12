import '../../../l10n/generated/app_localizations.dart';
import '../domain/notification_models.dart';

String notificationCopy(AppLocalizations l10n, AppNotification notification) {
  if (notification.category != NotificationCategory.participation) {
    return l10n.notificationsGeneric;
  }
  final actor = notification.actorDisplayName;
  final project = notification.projectTitle;
  return switch (notification.kind) {
    NotificationKind.participationRequestReceived =>
      actor != null && project != null
          ? l10n.notificationRequestReceived(actor, project)
          : l10n.notificationRequestReceivedGeneric,
    NotificationKind.participationRequestWithdrawn =>
      actor != null && project != null
          ? l10n.notificationRequestWithdrawn(actor, project)
          : l10n.notificationRequestWithdrawnGeneric,
    NotificationKind.participationRequestAccepted =>
      project != null
          ? l10n.notificationRequestAccepted(project)
          : l10n.notificationRequestAcceptedGeneric,
    NotificationKind.participationRequestRejected =>
      project != null
          ? l10n.notificationRequestRejected(project)
          : l10n.notificationRequestRejectedGeneric,
    NotificationKind.participantLeft =>
      actor != null && project != null
          ? l10n.notificationParticipantLeft(actor, project)
          : l10n.notificationParticipantLeftGeneric,
    NotificationKind.participantRemoved =>
      project != null
          ? l10n.notificationParticipantRemoved(project)
          : l10n.notificationParticipantRemovedGeneric,
    NotificationKind.unknown => l10n.notificationsGeneric,
  };
}
