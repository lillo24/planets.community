import '../../messages/presentation/inbox_content.dart';

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
import 'discussion_room_actions.dart';
import 'discussion_project_invitations.dart';
import '../../messages/presentation/messages_routes.dart';
import '../data/discussion_projects_gateway.dart';

class DiscussionFolders extends ConsumerStatefulWidget {
  const DiscussionFolders({super.key});
  @override
  ConsumerState<DiscussionFolders> createState() => _DiscussionFoldersState();
}

class _DiscussionFoldersState extends ConsumerState<DiscussionFolders>
    with WidgetsBindingObserver {
  DiscussionPager<DiscussionGroup>? groups;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(discussionGroupsProvider),
        l = AppLocalizations.of(context);
    if (g == null) return const SizedBox.shrink();
    if (groups != g) {
      groups = g;
      Future.microtask(g.load);
    }
    final commands = ref.watch(discussionCommandsProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([g, commands]),
      builder: (context, _) => InboxSource(
        content: g.rows.isNotEmpty
            ? InboxContent.present
            : g.error != null
            ? InboxContent.failure
            : !g.loaded || g.busy
            ? InboxContent.pending
            : InboxContent.empty,
        onRefresh: g.refresh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!g.loaded && g.error == null || g.busy)
              const LinearProgressIndicator(),
            if (g.error != null)
              DiscussionError(g.error!, retry: () => unawaited(g.refresh())),
            if (g.loaded &&
                g.rows.isEmpty &&
                g.error == null &&
                InboxContentScope.maybeOf(context) == null)
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
          ],
        ),
      ),
    );
  }
}

// Inbox refreshes can dispose both the invitation tile and Requests subtree.
// A live actor-bound command may finish on the same route without those widgets;
// explicit navigation away, account changes and disposed commands cancel it.
void _openAcceptedDiscussion(
  GoRouter router,
  Uri origin,
  DiscussionCommands commands,
  String actor,
  DiscussionReceipt receipt,
) {
  if (commands.disposed ||
      !commands.authorized(actor) ||
      router.routeInformationProvider.value.uri != origin) {
    return;
  }
  router.push(discussionRoute(receipt.roomId));
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
      final router = GoRouter.of(context);
      final origin = router.routeInformationProvider.value.uri;
      final invitations = ref.read(discussionInvitationsProvider);
      final groups = ref.read(discussionGroupsProvider);
      final receipt = await commands.run(
        slot,
        attempt.actor,
        attempt.action,
        attempt.intent,
      );
      if (receipt != null) {
        commands.forget(slot);
        invitations?.invalidate();
        groups?.invalidate();
        _openAcceptedDiscussion(
          router,
          origin,
          commands,
          attempt.actor,
          receipt,
        );
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
  DiscussionPager<DiscussionProjectRow>? projects;
  DiscussionPager<DiscussionRoom>? pager;
  @override
  void didUpdateWidget(covariant _DiscussionFolder old) {
    super.didUpdateWidget(old);
    if (old.group != widget.group && expanded) pager?.invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final projectPage = expanded
        ? ref.watch(discussionProjectsProvider(widget.group.id))
        : null;
    if (projectPage != null && projects != projectPage) {
      projects = projectPage;
      Future.microtask(projectPage.load);
    }
    final p = expanded && widget.group.canReadIdeas
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
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (projectPage != null) DiscussionProjectList(projectPage),
                if (p != null) ...[
                  Text(
                    AppLocalizations.of(context).discussionTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  DiscussionRoomList(p),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class DiscussionRoomList extends ConsumerStatefulWidget {
  const DiscussionRoomList(this.pager, {super.key});
  final DiscussionPager<DiscussionRoom> pager;
  @override
  ConsumerState<DiscussionRoomList> createState() => _DiscussionRoomListState();
}

class _DiscussionRoomListState extends ConsumerState<DiscussionRoomList> {
  bool showHidden = false;
  DiscussionPager<DiscussionRoom>? hiddenPager;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final group = widget.pager.rows.firstOrNull?.groupId;
    final hidden = showHidden && group != null
        ? ref.watch(discussionHiddenRoomsProvider(group))
        : null;
    if (hidden != null && hiddenPager != hidden) {
      hiddenPager = hidden;
      Future.microtask(hidden.load);
    }
    final pager = hidden ?? widget.pager;
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
          for (final r in [
            ...pager.rows.where((r) => r.isGeneral),
            ...pager.rows.where((r) => !r.isGeneral),
          ])
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  key: ValueKey('discussion-${r.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    r.isGeneral ? l.discussionGeneral : r.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: r.isGeneral
                        ? Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)
                        : null,
                  ),
                  subtitle: Text(
                    r.isFormer
                        ? l.discussionFormerHistory
                        : r.frozen
                        ? '${l.discussionConversionPublished} · ${l.discussionReadOnly}'
                        : r.manuallyHidden
                        ? l.discussionHidden
                        : r.automaticallyHidden
                        ? l.discussionQuiet
                        : r.preview ?? r.purpose,
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
                    r.isGeneral
                        ? Icons.push_pin_outlined
                        : r.muted
                        ? Icons.notifications_off_outlined
                        : r.archived || r.frozen
                        ? Icons.inventory_2_outlined
                        : Icons.chat_bubble_outline,
                  ),
                  onTap: () => context.push(discussionRoute(r.id)),
                ),
                if (r.canHide)
                  DiscussionRoomActions(
                    room: r,
                    onChanged: () async {
                      await widget.pager.refresh();
                      await hiddenPager?.refresh();
                    },
                  ),
              ],
            ),
          if (pager.loaded && pager.more)
            TextButton(
              onPressed: pager.busy ? null : () => unawaited(pager.load()),
              child: Text(l.discussionLoadMore),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.discussionShowHidden),
            value: showHidden,
            onChanged: (value) => setState(() => showHidden = value),
          ),
          Text(
            l.discussionHiddenHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class DiscussionProjectList extends StatelessWidget {
  const DiscussionProjectList(this.pager, {super.key});
  final DiscussionPager<DiscussionProjectRow> pager;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: pager,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.discussionProjectChats,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (pager.busy) const LinearProgressIndicator(),
          if (pager.error != null)
            DiscussionError(
              pager.error!,
              retry: () => unawaited(pager.refresh()),
            ),
          if (pager.loaded && pager.rows.isEmpty && pager.error == null)
            Text(l.discussionNoProjectChats),
          for (final row in pager.rows)
            ListTile(
              title: Text(row.item.displayTitle),
              subtitle: row.item.lastVisibleMessageBody == null
                  ? null
                  : Text(
                      row.item.lastVisibleMessageBody!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              leading: const Icon(Icons.groups_outlined),
              trailing: row.item.unreadCount == 0
                  ? null
                  : Badge(label: Text('${row.item.unreadCount}')),
              onTap: () => context.push(projectChatRoute(row.id)),
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

class DiscussionRequests extends ConsumerStatefulWidget {
  const DiscussionRequests({super.key});
  @override
  ConsumerState<DiscussionRequests> createState() => _DiscussionRequestsState();
}

class _DiscussionRequestsState extends ConsumerState<DiscussionRequests> {
  DiscussionPager<DiscussionInvitation>? bound;
  bool projectInvitationsOpen = false;

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(discussionInvitationsProvider),
        commands = ref.watch(discussionCommandsProvider),
        l = AppLocalizations.of(context);
    if (p == null) return const SizedBox.shrink();
    if (bound != p) {
      bound = p;
      Future.microtask(p.load);
    }
    return ListenableBuilder(
      listenable: Listenable.merge([p, commands]),
      builder: (context, _) => InboxSource(
        content:
            p.rows.isNotEmpty ||
                commands.attempts.values.any(
                  (a) =>
                      a.action == DiscussionAction.respond &&
                      a.intent['p_response'] == 'accepted' &&
                      a.receipt == null,
                )
            ? InboxContent.present
            : p.error != null
            ? InboxContent.failure
            : !p.loaded || p.busy
            ? InboxContent.pending
            : InboxContent.empty,
        onRefresh: p.refresh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (p.rows.isNotEmpty)
              Text(
                l.discussionInvitations,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ExpansionTile(
              title: Text(l.discussionProjectInvitation),
              // The same loader settles while collapsed, so empty-state claims
              // include these invitations. Expansion/selection behavior is unchanged.
              maintainState: InboxContentScope.maybeOf(context) != null,
              onExpansionChanged: (open) =>
                  setState(() => projectInvitationsOpen = open),
              children: [
                if ((projectInvitationsOpen ||
                        InboxContentScope.maybeOf(context) != null) &&
                    ref.watch(authSessionProvider).identity != null)
                  DiscussionProjectInvitations(
                    actor: ref.watch(authSessionProvider).identity!.id,
                  ),
              ],
            ),
            for (final invitation in p.rows)
              DiscussionInvitationTile(
                invitation,
                key: ValueKey(invitation.id),
              ),
            if (p.busy) const LinearProgressIndicator(),
            if (p.error != null)
              DiscussionError(p.error!, retry: () => unawaited(p.refresh())),
            for (final entry in commands.attempts.entries.where(
              (e) =>
                  e.value.action == DiscussionAction.respond &&
                  e.value.intent['p_response'] == 'accepted' &&
                  e.value.receipt == null &&
                  !p.rows.any(
                    (row) => row.id == e.value.intent['p_invitation_id'],
                  ),
            ))
              _InvitationRecovery(slot: entry.key, attempt: entry.value),
            if (p.loaded && p.more)
              TextButton(
                onPressed: p.busy ? null : () => unawaited(p.load()),
                child: Text(l.discussionLoadMore),
              ),
          ],
        ),
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
          final router = GoRouter.of(context);
          final origin = router.routeInformationProvider.value.uri;
          final invitations = ref.read(discussionInvitationsProvider);
          final groups = ref.read(discussionGroupsProvider);
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
          if (result != null) {
            commands.forget(slot);
            invitations?.invalidate();
            groups?.invalidate();
            _openAcceptedDiscussion(router, origin, commands, actor, result);
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
                  if (invitation.purpose case final purpose?
                      when purpose.isNotEmpty)
                    Text(
                      purpose,
                      key: ValueKey(
                        'discussion-invitation-purpose-${invitation.id}',
                      ),
                    ),
                  if (invitation.visibility case final visibility?)
                    Text(
                      '${l.discussionAudience}: ${visibility == 'group' ? l.discussionGroupVisible : l.discussionInviteOnly}',
                      key: ValueKey(
                        'discussion-invitation-audience-${invitation.id}',
                      ),
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
