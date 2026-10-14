import '../../../l10n/generated/app_localizations.dart';
import '../domain/project_workspace_models.dart';

String projectWorkspaceFailureMessage(
  AppLocalizations l10n,
  ProjectWorkspaceFailureKind? failure,
) => switch (failure) {
  ProjectWorkspaceFailureKind.conflict => l10n.projectWorkspaceConflict,
  ProjectWorkspaceFailureKind.removed => l10n.projectWorkspaceRemovedElsewhere,
  ProjectWorkspaceFailureKind.policyRequired =>
    l10n.projectWorkspacePolicyRequired,
  ProjectWorkspaceFailureKind.forbidden => l10n.projectWorkspaceForbidden,
  ProjectWorkspaceFailureKind.invalidName => l10n.projectWorkspaceNameInvalid,
  ProjectWorkspaceFailureKind.invalidUrl => l10n.projectWorkspaceUrlInvalid,
  _ => l10n.projectWorkspaceUnavailable,
};
