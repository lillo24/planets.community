import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../../groups/presentation/group_widgets.dart';
import '../../project_workspace/domain/project_workspace_models.dart';
import '../application/discussion_controllers.dart';
import '../application/discussion_links_controller.dart';
import '../data/discussion_gateway.dart';
import '../domain/discussion_links.dart';
import 'discussion_feedback.dart';
import 'discussion_link_open.dart';
import 'discussion_link_editor.dart';
import 'discussion_link_widgets.dart';
import 'discussion_routes.dart';
import 'discussion_share_link.dart';

IconData discussionLinkIcon(DiscussionLink link) =>
    {
      'wa.me',
      'whatsapp.com',
      'chat.whatsapp.com',
      'www.whatsapp.com',
    }.contains(link.url.hostname)
    ? Icons.chat_outlined
    : {
        't.me',
        'telegram.me',
        'telegram.org',
        'www.telegram.org',
      }.contains(link.url.hostname)
    ? Icons.send_outlined
    : switch (classifyProjectWorkspace(link.name, link.url.uri)) {
        ProjectWorkspaceIconType.document => Icons.description_outlined,
        ProjectWorkspaceIconType.spreadsheet => Icons.table_chart_outlined,
        ProjectWorkspaceIconType.video => Icons.videocam_outlined,
        ProjectWorkspaceIconType.drive => Icons.folder_shared_outlined,
        ProjectWorkspaceIconType.link => Icons.link,
      };
bool isDiscussionLinkAction(DiscussionAction action) => {
  DiscussionAction.addLink,
  DiscussionAction.editLink,
  DiscussionAction.removeLink,
}.contains(action);

class DiscussionLinksScreen extends ConsumerStatefulWidget {
  const DiscussionLinksScreen({required this.roomId, super.key});
  final String roomId;
  @override
  ConsumerState<DiscussionLinksScreen> createState() =>
      _DiscussionLinksScreenState();
}

class _DiscussionLinksScreenState extends ConsumerState<DiscussionLinksScreen>
    with WidgetsBindingObserver {
  DiscussionLinksController? bound;
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
    if (state == AppLifecycleState.resumed) bound?.pager.invalidate();
  }

  Future<void> retry(
    DiscussionLinksController c,
    String slot,
    DiscussionAttempt attempt,
  ) async {
    final admission = c.admission, epoch = c.epoch;
    if (admission == null ||
        attempt.intent['p_expected_admission_id'] != admission) {
      return;
    }
    if (!await requireGroupPolicy(context, ref, c.actor) ||
        !mounted ||
        !c.current(admission, epoch) ||
        ref.read(authSessionProvider).identity?.id != c.actor) {
      return;
    }
    final commands = ref.read(discussionCommandsProvider);
    final result = await commands.run(
      slot,
      c.actor,
      attempt.action,
      attempt.intent,
    );
    if (!mounted ||
        c.disposed ||
        ref.read(authSessionProvider).identity?.id != c.actor) {
      return;
    }
    if (result != null) {
      commands.forget(slot);
      await c.pager.refresh();
    }
  }

  Future<void> remove(DiscussionLinksController c, DiscussionLink link) async {
    if (!c.canManage) return;
    final commands = ref.read(discussionCommandsProvider),
        slot = 'link/remove/${link.id}/${link.admissionId}',
        epoch = c.epoch;
    if (!await confirmGroupAction(
          context,
          c.actor,
          AppLocalizations.of(context).projectWorkspaceRemoveTitle,
          explanation: AppLocalizations.of(context)
              .projectWorkspaceRemoveNamedMessage(link.name),
        ) ||
        !mounted ||
        !c.current(link.admissionId, epoch)) {
      return;
    }
    if (!await requireGroupPolicy(context, ref, c.actor) ||
        !mounted ||
        !c.current(link.admissionId, epoch)) {
      return;
    }
    final result = await commands.run(
      slot,
      c.actor,
      DiscussionAction.removeLink,
      {
        'p_room_id': c.room,
        'p_expected_admission_id': link.admissionId,
        'p_link_id': link.id,
        'p_expected_version': link.version,
      },
    );
    if (!mounted || !c.current(link.admissionId, epoch)) return;
    if (result != null) commands.forget(slot);
    await c.pager.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(discussionLinksProvider(widget.roomId)),
        commands = ref.watch(discussionCommandsProvider),
        l = AppLocalizations.of(context);
    if (c != null && bound != c) {
      bound = c;
      Future.microtask(c.pager.load);
    }
    return ListenableBuilder(
      listenable: Listenable.merge([commands, ?c]),
      builder: (context, _) {
        final pending = commands.attempts.entries
            .where(
              (e) =>
                  isDiscussionLinkAction(e.value.action) &&
                  e.value.intent['p_room_id'] == widget.roomId,
            )
            .toList();
        final locked = pending.any((e) => e.value.busy || e.value.uncertain),
            p = c?.pager;
        return PopScope(
          canPop: !locked,
          child: Scaffold(
            appBar: groupAppBar(
              context,
              l.discussionWorkspace,
              fallback: discussionRoute(widget.roomId),
              close: () {
                if (!locked) {
                  closeGroups(context, discussionRoute(widget.roomId));
                }
              },
            ),
            body: GroupBody(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(l.discussionLinksHistory),
                  Text(l.discussionLinkPermissions),
                  if (c == null ||
                      p == null ||
                      !p.loaded && p.error == null ||
                      p.busy)
                    const LinearProgressIndicator(),
                  if (p?.error != null)
                    DiscussionError(
                      p!.error!,
                      retry: () => unawaited(p.refresh()),
                    ),
                  if (p?.loaded == true && p!.error == null && p.rows.isEmpty)
                    Text(l.discussionLinksEmpty),
                  if (c != null && c.canManage)
                    FilledButton.icon(
                      key: const Key('discussion-link-add'),
                      onPressed: locked
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  DiscussionLinkEditor(controller: c),
                            ),
                      icon: const Icon(Icons.add),
                      label: Text(l.projectWorkspaceAddWorkspaceAction),
                    ),
                  for (final entry in pending) ...[
                    if (entry.value.uncertain) Text(l.discussionUncertain),
                    if (entry.value.error != null)
                      DiscussionError(entry.value.error!),
                    if (entry.value.error != null && c != null && !c.scopeEnded)
                      TextButton(
                        key: ValueKey('discussion-link-retry-${entry.key}'),
                        onPressed: entry.value.busy
                            ? null
                            : () => retry(c, entry.key, entry.value),
                        child: Text(l.discussionRetry),
                      ),
                    if (!entry.value.busy && !entry.value.uncertain)
                      TextButton(
                        onPressed: () => commands.forget(entry.key),
                        child: Text(l.discussionCancel),
                      ),
                  ],
                  for (final link in p?.rows ?? <DiscussionLink>[])
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DiscussionLinkHeading(
                              icon: discussionLinkIcon(link),
                              name: link.name,
                              hostname: link.url.hostname,
                              onOpen: () => confirmAndOpenDiscussionLink(
                                context,
                                ref,
                                c!,
                                link,
                              ),
                            ),
                            if (c != null) DiscussionShareLinkButton(actor: c.actor, link: link),
                            if (c?.canManage == true)
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed: locked
                                        ? null
                                        : () => showDialog<void>(
                                            context: context,
                                            builder: (_) =>
                                                DiscussionLinkEditor(
                                                  controller: c!,
                                                  link: link,
                                                ),
                                          ),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: Text(
                                      l.projectWorkspaceEditWorkspaceAction,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: locked
                                        ? null
                                        : () => remove(c!, link),
                                    icon: const Icon(Icons.delete_outline),
                                    label: Text(l.projectWorkspaceRemoveAction),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (p?.loaded == true && p!.more)
                    TextButton(
                      onPressed: p.busy ? null : () => unawaited(p.load()),
                      child: Text(l.discussionLoadMore),
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
