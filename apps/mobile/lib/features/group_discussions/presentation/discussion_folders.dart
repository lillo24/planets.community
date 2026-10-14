import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../application/discussion_controllers.dart';
import '../data/discussion_gateway.dart';
import '../domain/discussion_models.dart';
import 'discussion_feedback.dart';
import 'discussion_routes.dart';
import 'discussion_widgets.dart';

class DiscussionFolders extends ConsumerStatefulWidget {
  const DiscussionFolders({super.key});
  @override
  ConsumerState<DiscussionFolders> createState() => _DiscussionFoldersState();
}

class _DiscussionFoldersState extends ConsumerState<DiscussionFolders>
    with WidgetsBindingObserver {
  DiscussionPager<DiscussionGroup>? groups;
  DiscussionPager<DiscussionInvitation>? invitations;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      groups?.invalidate();
      invitations?.invalidate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(discussionGroupsProvider),
        i = ref.watch(discussionInvitationsProvider),
        l = AppLocalizations.of(context);
    if (g == null || i == null) return const SizedBox.shrink();
    if (groups != g) {
      groups = g;
      Future.microtask(g.load);
    }
    if (invitations != i) {
      invitations = i;
      Future.microtask(i.load);
    }
    final commands = ref.watch(discussionCommandsProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([g, i, commands]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.discussionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (i.rows.isNotEmpty) ...[
            Text(l.discussionInvitations),
            for (final invitation in i.rows)
              DiscussionInvitationTile(
                invitation,
                key: ValueKey(invitation.id),
              ),
          ],
          if (i.error != null)
            DiscussionError(i.error!, retry: () => unawaited(i.refresh())),
          for (final entry in commands.attempts.entries.where(
            (e) =>
                e.value.action == DiscussionAction.respond &&
                e.value.intent['p_response'] == 'accepted' &&
                e.value.receipt == null &&
                !i.rows.any(
                  (row) => row.id == e.value.intent['p_invitation_id'],
                ),
          ))
            _InvitationRecovery(slot: entry.key, attempt: entry.value),
          if (i.loaded && i.more)
            TextButton(
              onPressed: i.busy ? null : () => unawaited(i.load()),
              child: Text(l.discussionLoadMore),
            ),
          if (!g.loaded && g.error == null || g.busy)
            const LinearProgressIndicator(),
          if (g.error != null)
            DiscussionError(g.error!, retry: () => unawaited(g.refresh())),
          if (g.loaded && g.rows.isEmpty && g.error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l.discussionNoGroups),
            ),
          for (final group in g.rows)
            _DiscussionFolder(group, key: ValueKey(group.id)),
          if (g.loaded && g.more)
            TextButton(
              onPressed: g.busy ? null : () => unawaited(g.load()),
              child: Text(l.discussionLoadMore),
            ),
          const SizedBox(height: 16),
          Text(
            l.discussionProjectChats,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Acceptance may commit and remove the pending invitation before its reply
// arrives. Recover that own frozen command without retaining a private title.
class _InvitationRecovery extends ConsumerWidget {
  const _InvitationRecovery({required this.slot, required this.attempt});
  final String slot;
  final DiscussionAttempt attempt;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        commands = ref.watch(discussionCommandsProvider);
    Future<void> retry() async {
      if (!await requireGroupPolicy(context, ref, attempt.actor) ||
          !context.mounted ||
          ref.read(authSessionProvider).identity?.id != attempt.actor) {
        return;
      }
      final receipt = await commands.run(
        slot,
        attempt.actor,
        attempt.action,
        attempt.intent,
      );
      if (!context.mounted ||
          ref.read(authSessionProvider).identity?.id != attempt.actor) {
        return;
      }
      if (receipt != null) {
        commands.forget(slot);
        ref.read(discussionInvitationsProvider)?.invalidate();
        ref.read(discussionGroupsProvider)?.invalidate();
        context.push(discussionRoute(receipt.roomId));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.discussionUncertain),
        if (attempt.error != null) DiscussionError(attempt.error!),
        TextButton(
          onPressed: attempt.busy ? null : retry,
          child: Text(l.discussionRetry),
        ),
        if (!attempt.busy && !attempt.uncertain)
          TextButton(
            onPressed: () => commands.forget(slot),
            child: Text(l.discussionCancel),
          ),
      ],
    );
  }
}

class _DiscussionFolder extends ConsumerStatefulWidget {
  const _DiscussionFolder(this.group, {super.key});
  final DiscussionGroup group;
  @override
  ConsumerState<_DiscussionFolder> createState() => _DiscussionFolderState();
}

class _DiscussionFolderState extends ConsumerState<_DiscussionFolder> {
  bool expanded = false;
  DiscussionPager<DiscussionRoom>? pager;
  @override
  void didUpdateWidget(covariant _DiscussionFolder old) {
    super.didUpdateWidget(old);
    if (old.group != widget.group && expanded) pager?.invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final p = expanded
        ? ref.watch(discussionRoomsProvider(widget.group.id))
        : null;
    if (p != null && pager != p) {
      pager = p;
      Future.microtask(p.load);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiscussionFolderHeader(
          name: widget.group.name,
          unread: widget.group.unreadCount,
          expanded: expanded,
          onToggle: () => setState(() => expanded = !expanded),
        ),
        if (expanded && p != null)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: DiscussionRoomList(p),
          ),
      ],
    );
  }
}

class DiscussionRoomList extends StatelessWidget {
  const DiscussionRoomList(this.pager, {super.key});
  final DiscussionPager<DiscussionRoom> pager;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: pager,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pager.busy || !pager.loaded && pager.error == null)
            const LinearProgressIndicator(),
          if (pager.error != null)
            DiscussionError(
              pager.error!,
              retry: () => unawaited(pager.refresh()),
            ),
          if (pager.loaded && pager.rows.isEmpty && pager.error == null)
            Text(l.discussionNoRooms),
          for (final r in pager.rows)
            ListTile(
              key: ValueKey('discussion-${r.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                r.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: r.preview == null
                  ? null
                  : Text(
                      r.preview!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: r.unreadCount == 0
                  ? null
                  : Semantics(
                      label: l.discussionUnread(r.unreadCount),
                      child: Badge(
                        label: Text(
                          r.unreadCount > 99 ? '99+' : '${r.unreadCount}',
                        ),
                      ),
                    ),
              leading: Icon(
                r.archived
                    ? Icons.inventory_2_outlined
                    : Icons.chat_bubble_outline,
              ),
              onTap: () => context.push(discussionRoute(r.id)),
            ),
          if (pager.loaded && pager.more)
            TextButton(
              onPressed: pager.busy ? null : () => unawaited(pager.load()),
              child: Text(l.discussionLoadMore),
            ),
        ],
      ),
    );
  }
}

class DiscussionInvitationTile extends ConsumerWidget {
  const DiscussionInvitationTile(this.invitation, {super.key});
  final DiscussionInvitation invitation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        commands = ref.watch(discussionCommandsProvider);
    return ListenableBuilder(
      listenable: commands,
      builder: (context, _) {
        final slot = 'invite/${invitation.id}',
            attempt = commands.attempts[slot];
        Future<void> accept() async {
          final actor = ref.read(authSessionProvider).identity?.id;
          if (actor == null) return;
          if (attempt == null &&
              !await confirmGroupAction(
                context,
                actor,
                l.discussionAccept,
                explanation: l.discussionConsent,
              )) {
            return;
          }
          if (!context.mounted ||
              !await requireGroupPolicy(context, ref, actor)) {
            return;
          }
          if (!context.mounted ||
              ref.read(authSessionProvider).identity?.id != actor) {
            return;
          }
          final result = await commands.run(
            slot,
            actor,
            DiscussionAction.respond,
            {
              'p_room_id': invitation.roomId,
              'p_invitation_id': invitation.id,
              'p_response': 'accepted',
            },
          );
          if (!context.mounted ||
              ref.read(authSessionProvider).identity?.id != actor) {
            return;
          }
          if (result != null) {
            commands.forget(slot);
            ref.read(discussionInvitationsProvider)?.invalidate();
            ref.read(discussionGroupsProvider)?.invalidate();
            context.push(discussionRoute(result.roomId));
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    invitation.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(invitation.groupName),
                  Text(
                    invitation.inviterName ?? l.discussionAccountUnavailable,
                  ),
                  Text(l.discussionConsent),
                  if (attempt?.error != null) DiscussionError(attempt!.error!),
                  if (attempt?.uncertain == true) Text(l.discussionUncertain),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: attempt?.busy == true ? null : accept,
                        child: Text(
                          attempt?.uncertain == true
                              ? l.discussionRetry
                              : l.discussionAccept,
                        ),
                      ),
                      TextButton(
                        onPressed:
                            attempt?.busy == true || attempt?.uncertain == true
                            ? null
                            : () {
                                commands.forget(slot);
                                context.push(
                                  discussionDeclineRoute(
                                    invitation.roomId,
                                    invitation.id,
                                  ),
                                );
                              },
                        child: Text(l.discussionDecline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
