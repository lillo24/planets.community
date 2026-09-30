import '../../../l10n/generated/app_localizations.dart';
import '../application/project_request_chat_controller.dart';

String projectRequestChatFailureMessage(
  AppLocalizations l10n,
  ProjectRequestChatFailureKind failure,
) => switch (failure) {
  ProjectRequestChatFailureKind.invalidInput =>
    l10n.projectRequestChatInvalidMessage,
  ProjectRequestChatFailureKind.forbidden => l10n.projectRequestChatForbidden,
  ProjectRequestChatFailureKind.conflict => l10n.projectRequestChatSendConflict,
  ProjectRequestChatFailureKind.notFound => l10n.projectRequestChatNotFound,
  ProjectRequestChatFailureKind.sendUnavailable =>
    l10n.projectRequestChatUnableSend,
  ProjectRequestChatFailureKind.unavailable =>
    l10n.projectRequestChatUnavailable,
};
