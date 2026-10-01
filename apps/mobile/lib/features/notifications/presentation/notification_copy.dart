import '../../../l10n/generated/app_localizations.dart';
import '../domain/notification_models.dart';

String notificationCopy(AppLocalizations l10n, AppNotification notification) {
  if (notification.category == NotificationCategory.matching) {
    if (notification.kind != NotificationKind.matchingAvailable) {
      return l10n.notificationsGeneric;
    }
    final listing = notification.resourceListingTitle;
    return listing == null
        ? l10n.notificationMatchingAvailableGeneric
        : l10n.notificationMatchingAvailable(listing);
  }
  if (notification.category == NotificationCategory.resources) {
    return _resourceCopy(l10n, notification);
  }
  if (notification.category == NotificationCategory.chat) {
    if (notification.kind != NotificationKind.chatMessageReceived) {
      return l10n.notificationsGeneric;
    }
    final actor = notification.actorDisplayName;
    final project = notification.projectTitle;
    if (actor != null && project != null) {
      return l10n.notificationChatMessage(actor, project);
    }
    if (project != null) {
      return l10n.notificationChatMessageProject(project);
    }
    return l10n.notificationChatMessageGeneric;
  }
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
    _ => l10n.notificationsGeneric,
  };
}

String _resourceCopy(AppLocalizations l10n, AppNotification notification) {
  final actor =
      notification.actorDisplayName ?? l10n.notificationResourceFallbackActor;
  final listing =
      notification.resourceListingTitle ??
      l10n.notificationResourceFallbackListing;
  return switch (notification.kind) {
    NotificationKind.resourceRequestReceived =>
      l10n.notificationResourceRequestReceived(actor, listing),
    NotificationKind.resourceRequestWithdrawn =>
      l10n.notificationResourceRequestWithdrawn(actor, listing),
    NotificationKind.resourceRequestAccepted =>
      l10n.notificationResourceRequestAccepted(listing),
    NotificationKind.resourceRequestRejected =>
      l10n.notificationResourceRequestRejected(listing),
    NotificationKind.resourceRequestListingClosed =>
      l10n.notificationResourceRequestListingClosed(listing),
    NotificationKind.resourceChatMessageReceived =>
      l10n.notificationResourceChatMessage(actor, listing),
    NotificationKind.resourceExchangeTermsProposed =>
      l10n.notificationResourceTermsProposed(actor, listing),
    NotificationKind.resourceExchangeTermsAccepted =>
      l10n.notificationResourceTermsAccepted(actor, listing),
    NotificationKind.resourceExchangeTermsRejected =>
      l10n.notificationResourceTermsRejected(actor, listing),
    NotificationKind.resourceExchangeTermsWithdrawn =>
      l10n.notificationResourceTermsWithdrawn(actor, listing),
    NotificationKind.resourceExchangeMilestoneRecorded =>
      _resourceMilestoneCopy(l10n, notification, actor, listing),
    NotificationKind.resourceExchangeCancelled =>
      l10n.notificationResourceExchangeCancelled(actor, listing),
    NotificationKind.resourceExchangeCompleted =>
      l10n.notificationResourceExchangeCompleted(listing),
    _ => l10n.notificationsGeneric,
  };
}

String _resourceMilestoneCopy(
  AppLocalizations l10n,
  AppNotification notification,
  String actor,
  String listing,
) => switch ((
  notification.resourceExchangeLegKind,
  notification.resourceExchangeEventKind,
)) {
  (
    ResourceNotificationLegKind.ownerResource,
    ResourceNotificationEventKind.resourceProvided,
  ) =>
    l10n.notificationResourceOwnerProvided(actor, listing),
  (
    ResourceNotificationLegKind.ownerResource,
    ResourceNotificationEventKind.resourceReceived,
  ) =>
    l10n.notificationResourceOwnerReceived(actor, listing),
  (
    ResourceNotificationLegKind.ownerResource,
    ResourceNotificationEventKind.resourceReturned,
  ) =>
    l10n.notificationResourceOwnerReturned(actor, listing),
  (
    ResourceNotificationLegKind.ownerResource,
    ResourceNotificationEventKind.resourceReturnReceived,
  ) =>
    l10n.notificationResourceOwnerReturnReceived(actor, listing),
  (
    ResourceNotificationLegKind.requesterResource,
    ResourceNotificationEventKind.resourceProvided,
  ) =>
    l10n.notificationResourceRequesterProvided(actor),
  (
    ResourceNotificationLegKind.requesterResource,
    ResourceNotificationEventKind.resourceReceived,
  ) =>
    l10n.notificationResourceRequesterReceived(actor),
  (
    ResourceNotificationLegKind.requesterResource,
    ResourceNotificationEventKind.resourceReturned,
  ) =>
    l10n.notificationResourceRequesterReturned(actor),
  (
    ResourceNotificationLegKind.requesterResource,
    ResourceNotificationEventKind.resourceReturnReceived,
  ) =>
    l10n.notificationResourceRequesterReturnReceived(actor),
  _ => l10n.notificationsGeneric,
};
