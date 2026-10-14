import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../../groups/presentation/group_widgets.dart';
import '../../messages/presentation/message_read_viewport.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/report_form_screen.dart';
import '../application/discussion_controllers.dart';
import '../data/discussion_gateway.dart';
import '../domain/discussion_models.dart';
import 'discussion_feedback.dart';
import 'discussion_routes.dart';
import 'discussion_widgets.dart';

class DiscussionChatScreen extends ConsumerStatefulWidget {
  const DiscussionChatScreen({required this.roomId, super.key});
  final String roomId;
  @override
  ConsumerState<DiscussionChatScreen> createState() =>
      _DiscussionChatScreenState();
}

class _DiscussionChatScreenState extends ConsumerState<DiscussionChatScreen>
    with WidgetsBindingObserver {
  final message = TextEditingController(), scroll = ScrollController();
  DiscussionChatController? bound;
  String? episode;
  bool deniedCleared = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    message.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) bound?.invalidate();
  }

  void newest(DiscussionChatController expected) {
    final admission = expected.room?.admissionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A retained/offstage route can have a position without layout metrics.
      // Delayed scrolling also belongs to the original actor/admission only.
      if (mounted &&
          bound == expected &&
          !expected.disposed &&
          expected.room?.admissionId == admission &&
          ref.read(authSessionProvider).identity?.id == expected.actor &&
          ModalRoute.of(context)?.isCurrent == true &&
          scroll.hasClients &&
          scroll.position.hasContentDimensions) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> older(DiscussionChatController c) async {
    if (!scroll.hasClients || !scroll.position.hasContentDimensions) return;
    final admission = c.room?.admissionId;
    final before = scroll.hasClients ? scroll.position.maxScrollExtent : 0.0,
        position = scroll.hasClients ? scroll.offset : 0.0;
    await c.older();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          bound == c &&
          !c.disposed &&
          c.room?.admissionId == admission &&
          ModalRoute.of(context)?.isCurrent == true &&
          scroll.hasClients &&
          scroll.position.hasContentDimensions) {
        scroll.jumpTo(
          (position + scroll.position.maxScrollExtent - before).clamp(
            0.0,
            scroll.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  Future<void> send(DiscussionChatController c) async {
    final room = c.room;
    if (room == null || room.archived) return;
    final commands = ref.read(discussionCommandsProvider),
        slot = 'send/${room.admissionId}';
    final attempt = commands.attempts[slot],
        body = attempt?.intent['p_body'] as String? ?? message.text.trim();
    if (body.runes.isEmpty || body.runes.length > 4000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).discussionInvalid)),
      );
      return;
    }
    if (!await requireGroupPolicy(context, ref, c.actor) ||
        !mounted ||
        ref.read(authSessionProvider).identity?.id != c.actor) {
      return;
    }
    final result = await commands.run(slot, c.actor, DiscussionAction.send, {
      'p_room_id': c.roomId,
      'p_body': body,
    });
    if (!mounted ||
        bound != c ||
        ref.read(authSessionProvider).identity?.id != c.actor) {
      return;
    }
    if (result != null) {
      if (c.room?.admissionId == room.admissionId &&
          message.text.trim() == body) {
        message.clear();
      }
      commands.forget(slot);
      await c.refresh();
      if (mounted && c.room?.admissionId == room.admissionId) newest(c);
    } else if (commands.attempts[slot]?.error != null &&
        discussionFailure(commands.attempts[slot]!.error!) ==
            DiscussionFailure.denied) {
      await c.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(discussionChatProvider(widget.roomId)),
        commands = ref.watch(discussionCommandsProvider),
        l = AppLocalizations.of(context);
    ref.listen(authSessionProvider.select((s) => (s.identity?.id, s.phase)), (
      _,
      _,
    ) {
      message.clear();
      episode = null;
    });
    if (c != null && bound != c) {
      bound = c;
      message.clear();
      episode = null;
      Future.microtask(() async {
        await c.refresh();
        if (mounted && bound == c) newest(c);
      });
    }
    return ListenableBuilder(
      listenable: Listenable.merge([commands, ?c]),
      builder: (context, _) {
        final room = c?.room;
        if (room != null && episode != room.admissionId) {
          final hadEpisode = episode != null;
          episode = room.admissionId;
          if (hadEpisode) {
            message.clear();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) commands.clearRoom(widget.roomId);
            });
          }
        }
        if (c?.error != null &&
            discussionFailure(c!.error!) == DiscussionFailure.denied &&
            !deniedCleared) {
          deniedCleared = true;
          message.clear();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) commands.clearRoom(widget.roomId);
          });
        }
        if (room != null) deniedCleared = false;
        final slot = 'send/${room?.admissionId}',
            attempt = commands.attempts[slot];
        if (attempt != null &&
            message.text.isEmpty &&
            attempt.intent['p_body'] is String) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                episode == room?.admissionId &&
                commands.attempts[slot] == attempt &&
                message.text.isEmpty) {
              message.text = attempt.intent['p_body'] as String;
            }
          });
        }
        final body = room == null
            ? Center(
                child: c?.error == null
                    ? const CircularProgressIndicator()
                    : DiscussionError(
                        c!.error!,
                        retry: () => unawaited(c.refresh()),
                      ),
              )
            : MessageReadViewport(
                profileId: c!.actor,
                kind: 'group_discussion',
                chatId: room.id,
                boundary: c.token,
                scrollController: scroll,
                child: Column(
                  children: [
                    if (c.busy) const LinearProgressIndicator(),
                    if (c.error != null)
                      DiscussionError(
                        c.error!,
                        retry: () => unawaited(c.refresh()),
                      ),
                    for (final entry in commands.attempts.entries.where(
                      (e) =>
                          e.value.action == DiscussionAction.update &&
                          e.value.intent['p_room_id'] == room.id &&
                          e.value.error != null &&
                          !room.canManage,
                    ))
                      Column(
                        children: [
                          Text(l.discussionUncertain),
                          Text(entry.value.intent['p_title'] as String),
                          Text(
                            entry.value.intent['p_archived'] == true
                                ? l.discussionArchive
                                : l.discussionRestore,
                          ),
                          DiscussionError(entry.value.error!),
                          TextButton(
                            onPressed: entry.value.busy
                                ? null
                                : () async {
                                    final result = await commands.run(
                                      entry.key,
                                      c.actor,
                                      entry.value.action,
                                      entry.value.intent,
                                    );
                                    if (mounted &&
                                        ref
                                                .read(authSessionProvider)
                                                .identity
                                                ?.id ==
                                            c.actor &&
                                        result != null) {
                                      commands.forget(entry.key);
                                      await c.refresh();
                                    }
                                  },
                            child: Text(l.discussionRetry),
                          ),
                          if (!entry.value.busy && !entry.value.uncertain)
                            TextButton(
                              onPressed: () => commands.forget(entry.key),
                              child: Text(l.discussionCancel),
                            ),
                        ],
                      ),
                    if (c.latestAvailable)
                      TextButton(
                        onPressed: () => unawaited(
                          c.refresh(latest: true).then((_) => newest(c)),
                        ),
                        child: Text(l.discussionLatest),
                      ),
                    Expanded(
                      child: ListView(
                        controller: scroll,
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (c.more && c.messages.isNotEmpty)
                            TextButton(
                              key: const Key('discussion-older'),
                              onPressed: c.busy ? null : () => older(c),
                              child: Text(l.discussionOlder),
                            ),
                          if (c.messages.isEmpty && !c.busy && c.error == null)
                            Text(l.discussionNoMessages),
                          for (final m in c.messages)
                            DiscussionBubble(
                              key: ValueKey(m.id),
                              body: m.body,
                              sender:
                                  m.senderName ??
                                  l.discussionAccountUnavailable,
                              own: m.senderId == c.actor,
                              onReport: m.senderId == c.actor
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ReportFormScreen(
                                          target: ModerationReportTarget(
                                            kind: ModerationTargetKind
                                                .groupDiscussionMessage,
                                            id: m.id,
                                            label: l.discussionReportLabel,
                                          ),
                                          onClose: () =>
                                              Navigator.of(context).pop(),
                                        ),
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Text(
                        room.archived
                            ? l.discussionReadOnly
                            : l.discussionHistory,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (!room.archived)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (attempt?.error != null)
                                DiscussionError(attempt!.error!),
                              if (attempt?.uncertain == true)
                                Text(l.discussionUncertain),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      key: const Key('discussion-composer'),
                                      controller: message,
                                      minLines: 1,
                                      maxLines: 4,
                                      readOnly: attempt != null,
                                      decoration: InputDecoration(
                                        labelText: l.discussionMessage,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    key: const Key('discussion-send'),
                                    tooltip: attempt?.uncertain == true
                                        ? l.discussionRetry
                                        : l.discussionSend,
                                    onPressed: attempt?.busy == true
                                        ? null
                                        : () => send(c),
                                    icon: const Icon(Icons.send_outlined),
                                  ),
                                ],
                              ),
                              if (attempt != null &&
                                  !attempt.busy &&
                                  !attempt.uncertain &&
                                  attempt.receipt == null)
                                TextButton(
                                  onPressed: () => commands.forget(slot),
                                  child: Text(l.discussionCancel),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
        return PopScope(
          canPop: attempt?.busy != true && attempt?.uncertain != true,
          child: Scaffold(
            appBar: pageAppBar(
              context,
              title: Text(
                room?.title ?? l.discussionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onClose: () {
                if (attempt?.busy != true && attempt?.uncertain != true) {
                  closeGroups(context, '/messages');
                }
              },
              actions: [
                if (room != null)
                  IconButton(
                    tooltip: l.discussionPeople,
                    onPressed: () =>
                        context.push(discussionPeopleRoute(room.id)),
                    icon: const Icon(Icons.people_outline),
                  ),
                if (room != null)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'leave') {
                        context.push(
                          discussionLeaveRoute(room.id, room.admissionId),
                        );
                      } else {
                        showDialog<void>(
                          context: context,
                          builder: (_) => _DiscussionEditDialog(
                            controller: c!,
                            archive: value == 'rename' ? null : !room.archived,
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      if (room.canManage)
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(l.discussionRename),
                        ),
                      if (room.canManage)
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(
                            room.archived
                                ? l.discussionRestore
                                : l.discussionArchive,
                          ),
                        ),
                      PopupMenuItem(
                        value: 'leave',
                        child: Text(l.discussionLeave),
                      ),
                    ],
                  ),
              ],
            ),
            body: SafeArea(child: body),
          ),
        );
      },
    );
  }
}

class _DiscussionEditDialog extends ConsumerStatefulWidget {
  const _DiscussionEditDialog({
    required this.controller,
    required this.archive,
  });
  final DiscussionChatController controller;
  final bool? archive;
  @override
  ConsumerState<_DiscussionEditDialog> createState() =>
      _DiscussionEditDialogState();
}

class _DiscussionEditDialogState extends ConsumerState<_DiscussionEditDialog> {
  late final TextEditingController title;
  late int version;
  late bool archive;
  late final String admission;
  DiscussionRoom? reviewed;
  Object? reviewError;
  bool closing = false;
  @override
  void initState() {
    super.initState();
    final r = widget.controller.room!;
    final attempt = ref
        .read(discussionCommandsProvider)
        .attempts['update/${r.id}/${r.admissionId}'];
    title = TextEditingController(
      text: attempt?.intent['p_title'] as String? ?? r.title,
    );
    version = attempt?.intent['p_expected_version'] as int? ?? r.version;
    archive =
        attempt?.intent['p_archived'] as bool? ?? widget.archive ?? r.archived;
    admission = r.admissionId;
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller,
        l = AppLocalizations.of(context),
        commands = ref.watch(discussionCommandsProvider),
        slot = 'update/${c.roomId}/$admission';
    return ListenableBuilder(
      listenable: Listenable.merge([c, commands]),
      builder: (context, _) {
        final attempt = commands.attempts[slot];
        if (!closing &&
            (c.room?.canManage != true ||
                c.room?.admissionId != admission ||
                ref.read(authSessionProvider).identity?.id != c.actor)) {
          closing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.pop(context);
          });
        }
        Future<void> save() async {
          final text =
              attempt?.intent['p_title'] as String? ?? title.text.trim();
          if (text.runes.isEmpty || text.runes.length > 120) return;
          if (!await requireGroupPolicy(context, ref, c.actor) ||
              !mounted ||
              ref.read(authSessionProvider).identity?.id != c.actor) {
            return;
          }
          final result = await commands.run(
            slot,
            c.actor,
            DiscussionAction.update,
            {
              'p_room_id': c.roomId,
              'p_expected_version': version,
              'p_title': text,
              'p_archived': archive,
            },
          );
          if (!mounted) return;
          if (result != null) {
            commands.forget(slot);
            await c.refresh();
            if (context.mounted) Navigator.pop(context);
          } else if (attempt?.error != null ||
              commands.attempts[slot]?.error != null) {
            await c.refresh();
          }
        }

        return PopScope(
          canPop: attempt?.busy != true && attempt?.uncertain != true,
          child: AlertDialog(
            title: Text(
              widget.archive == null
                  ? l.discussionRename
                  : archive
                  ? l.discussionArchive
                  : l.discussionRestore,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.archive == null)
                    TextField(
                      controller: title,
                      readOnly: attempt != null,
                      maxLength: 120,
                      decoration: InputDecoration(labelText: l.discussionName),
                    ),
                  if (attempt?.error != null) DiscussionError(attempt!.error!),
                  if (attempt?.uncertain == true) Text(l.discussionUncertain),
                  if (reviewError != null) DiscussionError(reviewError!),
                  if (attempt?.error != null &&
                      discussionFailure(attempt!.error!) ==
                          DiscussionFailure.conflict) ...[
                    TextButton(
                      onPressed: () async {
                        try {
                          final latest = await c.gateway.room(
                            c.actor,
                            c.roomId,
                          );
                          if (!mounted || !context.mounted) return;
                          if (!latest.canManage ||
                              latest.admissionId != admission ||
                              ref.read(authSessionProvider).identity?.id !=
                                  c.actor) {
                            Navigator.pop(context);
                            return;
                          }
                          setState(() {
                            reviewed = latest;
                            reviewError = null;
                          });
                        } catch (error) {
                          if (mounted) {
                            setState(() {
                              reviewed = null;
                              reviewError = error;
                            });
                          }
                        }
                      },
                      child: Text(l.discussionReviewLatest),
                    ),
                    if (reviewed != null) ...[
                      Text(reviewed!.title),
                      Text(
                        reviewed!.archived
                            ? l.discussionReadOnly
                            : l.discussionHistory,
                      ),
                      TextButton(
                        onPressed: () {
                          commands.forget(slot);
                          setState(() {
                            version = reviewed!.version;
                            archive = widget.archive ?? reviewed!.archived;
                            reviewed = null;
                          });
                        },
                        child: Text(l.discussionKeepEdits),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: attempt?.busy == true || attempt?.uncertain == true
                    ? null
                    : () => Navigator.pop(context),
                child: Text(l.discussionCancel),
              ),
              FilledButton(
                onPressed: attempt?.busy == true ? null : save,
                child: Text(
                  attempt?.uncertain == true
                      ? l.discussionRetry
                      : l.discussionSave,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
