import '../../../l10n/generated/app_localizations.dart';
import '../application/messages_controllers.dart';

String messagesFailureMessage(
  AppLocalizations l10n,
  MessagesFailureKind failure,
) => switch (failure) {
  MessagesFailureKind.forbidden => l10n.messagesForbidden,
  MessagesFailureKind.conflict => l10n.messagesConflict,
  MessagesFailureKind.notFound => l10n.messagesNotFound,
  MessagesFailureKind.unavailable => l10n.messagesSafeError,
};
