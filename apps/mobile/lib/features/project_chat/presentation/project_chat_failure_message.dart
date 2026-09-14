import '../../../l10n/generated/app_localizations.dart';
import '../application/project_chat_controllers.dart';

String projectChatFailureMessage(
  AppLocalizations l10n,
  ProjectChatFailureKind failure,
) => switch (failure) {
  ProjectChatFailureKind.invalidInput => l10n.projectChatInvalidMessage,
  ProjectChatFailureKind.forbidden => l10n.projectChatForbidden,
  ProjectChatFailureKind.notFound => l10n.projectChatNotFound,
  ProjectChatFailureKind.unavailable => l10n.projectChatSafeError,
};
