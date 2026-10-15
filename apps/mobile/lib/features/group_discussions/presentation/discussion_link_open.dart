import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../project_workspace/application/project_workspace_launcher.dart';
import '../application/discussion_links_controller.dart';
import '../domain/discussion_links.dart';
import 'discussion_feedback.dart';

/// A confirmation never authorizes a cached URL: reread this exact episode/item.
Future<void> confirmAndOpenDiscussionLink(
  BuildContext context,
  WidgetRef ref,
  DiscussionLinksController c,
  DiscussionLink link,
) async {
  final epoch = c.epoch,
      admission = link.admissionId,
      route = ModalRoute.of(context),
      router = GoRouter.maybeOf(context),
      origin = GoRouter.maybeOf(context)?.routeInformationProvider.value.uri,
      l = AppLocalizations.of(context);
  bool current() =>
      context.mounted &&
      c.current(admission, epoch) &&
      ref.read(authSessionProvider).identity?.id == c.actor &&
      router?.routeInformationProvider.value.uri == origin &&
      (route?.isActive ?? true);
  void failure(String message) {
    if (current()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  var candidate = link;
  for (var attempt = 0; attempt < 3; attempt++) {
    if (!context.mounted || !current() || route?.isCurrent == false) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, dialogRef, _) {
          dialogRef.watch(authSessionProvider);
          return ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final valid = current();
              return AlertDialog(
                scrollable: true,
                title: Text(l.projectWorkspaceOpenTitle),
                content: valid
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(candidate.name),
                          if (attempt > 0)
                            Text(l.projectWorkspaceChangedDestination),
                          Text(
                            l.projectWorkspaceOpenMessage(
                              candidate.url.hostname,
                            ),
                            key: const Key('discussion-link-confirm-host'),
                          ),
                        ],
                      )
                    : Text(l.discussionUnavailable),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(l.projectWorkspaceCancelAction),
                  ),
                  if (valid)
                    FilledButton(
                      key: const Key('discussion-link-confirm-open'),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(l.projectWorkspaceOpenAction),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
    if (confirmed != true || !current() || route?.isCurrent == false) return;
    DiscussionLink fresh;
    try {
      fresh = await c.gateway.exact(c.actor, c.room, admission, link.id);
    } catch (error) {
      failure(discussionErrorText(l, error));
      return;
    }
    if (!current() || route?.isCurrent == false) return;
    if (fresh.url.value != candidate.url.value) {
      candidate = fresh;
      continue;
    }
    final opened = await ref
        .read(projectWorkspaceLauncherProvider)
        .open(fresh.url);
    if (!opened) failure(l.projectWorkspaceOpenFailure);
    return;
  }
  failure(l.projectWorkspaceChangedDestination);
}
