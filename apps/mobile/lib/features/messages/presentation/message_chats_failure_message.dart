import '../../../l10n/generated/app_localizations.dart';
import '../application/message_chats_controller.dart';

String messageChatsFailureMessage(
  AppLocalizations l10n,
  MessageChatsFailureKind failure,
) => switch (failure) {
  MessageChatsFailureKind.invalidInput => l10n.resourceChatInvalidInput,
  MessageChatsFailureKind.forbidden => l10n.resourceChatForbidden,
  MessageChatsFailureKind.notFound => l10n.resourceChatNotFound,
  MessageChatsFailureKind.unavailable => l10n.messageChatsUnavailable,
};
