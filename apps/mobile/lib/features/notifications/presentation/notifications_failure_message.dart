import '../../../l10n/generated/app_localizations.dart';
import '../application/notifications_controllers.dart';

String notificationsFailureMessage(
  AppLocalizations l10n,
  NotificationsFailureKind failure,
) => switch (failure) {
  NotificationsFailureKind.forbidden => l10n.notificationsForbidden,
  NotificationsFailureKind.unavailable => l10n.notificationsSafeError,
};
