import '../../../l10n/generated/app_localizations.dart';
import '../application/resource_chat_controller.dart';

String resourceChatFailureMessage(
  AppLocalizations l10n,
  ResourceChatFailureKind failure,
) => switch (failure) {
  ResourceChatFailureKind.invalidInput => l10n.resourceChatInvalidInput,
  ResourceChatFailureKind.forbidden => l10n.resourceChatForbidden,
  ResourceChatFailureKind.notFound => l10n.resourceChatNotFound,
  ResourceChatFailureKind.conflict => l10n.resourceChatSendConflict,
  ResourceChatFailureKind.sendUnavailable => l10n.resourceChatUnableSend,
  ResourceChatFailureKind.unavailable => l10n.resourceChatUnavailable,
};
