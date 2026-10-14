import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/project_workspace_controller.dart';
import '../application/project_workspace_launcher.dart';
import '../domain/project_workspace_models.dart';
import 'project_workspace_feedback.dart';

/// Confirm the hostname, then reread this exact item under current entitlement.
/// A changed destination requires another confirmation. Persistent changes stop
/// after three dialogs and leave an explicit retry instead of opening stale data.
Future<void> confirmAndOpenProjectWorkspace(
  BuildContext context,
  WidgetRef ref,
  ProjectWorkspace workspace,
) async {
  final actor = ref.read(authSessionProvider).identity?.id;
  if (actor == null) return;
  final controller = ref.read(projectWorkspaceProvider.notifier);
  final epoch = controller.epoch;
  final router = GoRouter.maybeOf(context);
  final origin = router?.routeInformationProvider.value.uri;
  final l10n = AppLocalizations.of(context);
  bool current() =>
      context.mounted &&
      controller.epoch == epoch &&
      router?.routeInformationProvider.value.uri == origin &&
      ref.read(authSessionProvider).identity?.id == actor &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready;
  void failure(String message) {
    if (current()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  var candidate = workspace;
  for (var attempt = 0; attempt < 3; attempt++) {
    if (!context.mounted || !current()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, dialogRef, _) {
          final session = dialogRef.watch(authSessionProvider);
          dialogRef.watch(projectWorkspaceProvider);
          final valid =
              session.identity?.id == actor &&
              session.phase == AuthSessionPhase.ready &&
              controller.epoch == epoch;
          return AlertDialog(
            scrollable: true,
            title: Text(l10n.projectWorkspaceOpenTitle),
            content: valid
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (attempt > 0)
                        Text(l10n.projectWorkspaceChangedDestination),
                      Text(
                        l10n.projectWorkspaceOpenMessage(
                          candidate.url.hostname,
                        ),
                        key: const Key('project-workspace-confirm-host'),
                      ),
                    ],
                  )
                : Text(l10n.projectWorkspaceUnavailable),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.projectWorkspaceCancelAction),
              ),
              if (valid)
                FilledButton(
                  key: const Key('project-workspace-confirm-open'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.projectWorkspaceOpenAction),
                ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || !current()) return;
    ProjectWorkspace? canonical;
    try {
      canonical = await controller.readForOpen(
        expectedProfileId: actor,
        projectId: workspace.projectId,
        linkId: workspace.id,
        expectedEpoch: epoch,
      );
    } catch (error) {
      // External-open boundary: failure is visible and never launches a cache.
      failure(
        projectWorkspaceFailureMessage(l10n, mapProjectWorkspaceFailure(error)),
      );
      return;
    }
    if (!current()) return;
    if (canonical == null) {
      failure(l10n.projectWorkspaceRemovedElsewhere);
      return;
    }
    if (canonical.url.value != candidate.url.value) {
      candidate = canonical;
      continue;
    }
    final opened = await ref
        .read(projectWorkspaceLauncherProvider)
        .open(canonical.url);
    if (!opened) failure(l10n.projectWorkspaceOpenFailure);
    return;
  }
  failure(l10n.projectWorkspaceChangedDestination);
}
