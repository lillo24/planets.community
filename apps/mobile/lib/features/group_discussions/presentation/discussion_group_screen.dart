import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../group_membership/data/group_relationship_gateway.dart';
import '../../group_membership/domain/group_relationships.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../../groups/presentation/group_widgets.dart';
import '../application/discussion_controllers.dart';
import '../data/discussion_gateway.dart';
import '../domain/discussion_models.dart';
import 'discussion_feedback.dart';
import 'discussion_folders.dart';
import 'discussion_routes.dart';

class DiscussionGroupScreen extends ConsumerStatefulWidget {
  const DiscussionGroupScreen({
    required this.groupId,
    this.create = false,
    super.key,
  });
  final String groupId;
  final bool create;
  @override
  ConsumerState<DiscussionGroupScreen> createState() =>
      _DiscussionGroupScreenState();
}

class _DiscussionGroupScreenState extends ConsumerState<DiscussionGroupScreen>
    with WidgetsBindingObserver {
  final name = TextEditingController();
  DiscussionPager<DiscussionRoom>? pager;
  String? actor;
  GroupSelfContext? self;
  Object? error;
  int epoch = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && actor != null) {
      unawaited(bind(actor!, reset: false));
      pager?.invalidate();
    }
  }

  @override
  void dispose() {
    epoch++;
    WidgetsBinding.instance.removeObserver(this);
    name.dispose();
    super.dispose();
  }

  Future<void> bind(String id, {bool reset = true}) async {
    actor = id;
    self = null;
    error = null;
    if (reset) {
      name.clear();
    }
    final captured = ++epoch;
    try {
      final own = await ref
          .read(groupRelationshipGatewayProvider)
          .self(id, widget.groupId);
      if (mounted &&
          captured == epoch &&
          ref.read(authSessionProvider).identity?.id == id) {
        setState(() {
          self = own;
          if (reset) {
            name.text =
                ref
                        .read(discussionCommandsProvider)
                        .attempts['create/${widget.groupId}']
                        ?.intent['p_title']
                    as String? ??
                '';
          }
        });
      }
    } catch (failure) {
      if (mounted && captured == epoch) setState(() => error = failure);
    }
  }

  Future<void> save() async {
    final id = actor, p = pager;
    if (id == null ||
        p == null ||
        self?.authority == null ||
        !p.loaded ||
        p.error != null) {
      return;
    }
    final commands = ref.read(discussionCommandsProvider),
        slot = 'create/${widget.groupId}';
    final attempt = commands.attempts[slot];
    final title = attempt?.intent['p_title'] as String? ?? name.text.trim();
    if (title.runes.isEmpty || title.runes.length > 120) {
      setState(
        () => error = const FormatException('Invalid discussion title.'),
      );
      return;
    }
    if (!await requireGroupPolicy(context, ref, id) ||
        !mounted ||
        ref.read(authSessionProvider).identity?.id != id) {
      return;
    }
    final receipt = await commands.run(slot, id, DiscussionAction.create, {
      'p_group_id': widget.groupId,
      'p_title': title,
    });
    if (!mounted || ref.read(authSessionProvider).identity?.id != id) return;
    if (receipt != null) {
      commands.forget(slot);
      context.pushReplacement(discussionRoute(receipt.roomId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(authSessionProvider).identity?.id,
        l = AppLocalizations.of(context),
        p = ref.watch(discussionRoomsProvider(widget.groupId));
    ref.listen(authSessionProvider.select((s) => (s.identity?.id, s.phase)), (
      _,
      next,
    ) {
      epoch++;
      name.clear();
      self = null;
      actor = null;
    });
    ref.listen(discussionSignalsProvider, (_, next) {
      if (next.asData?.value.connected == true && actor != null) {
        unawaited(bind(actor!, reset: false));
      }
    });
    if (id != null && actor != id) Future.microtask(() => bind(id));
    if (p != null && pager != p) {
      pager = p;
      Future.microtask(p.load);
    }
    final commands = ref.watch(discussionCommandsProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([commands, ?p]),
      builder: (context, _) {
        final attempt = commands.attempts['create/${widget.groupId}'];
        return PopScope(
          canPop: attempt?.busy != true && attempt?.uncertain != true,
          child: Scaffold(
            appBar: groupAppBar(
              context,
              widget.create ? l.discussionCreate : l.discussionTitle,
              fallback: '/messages',
              close: () {
                if (attempt?.busy != true && attempt?.uncertain != true) {
                  closeGroups(context, '/messages');
                }
              },
            ),
            body: GroupBody(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (error != null)
                    DiscussionError(
                      error!,
                      retry: () => id == null ? null : unawaited(bind(id)),
                    ),
                  if (p != null && !widget.create) ...[
                    if (self?.authority != null && p.loaded && p.error == null)
                      FilledButton.icon(
                        onPressed: () =>
                            context.push(discussionCreateRoute(widget.groupId)),
                        icon: const Icon(Icons.add),
                        label: Text(l.discussionCreate),
                      ),
                    const SizedBox(height: 16),
                    DiscussionRoomList(p),
                  ],
                  if (widget.create && p != null) ...[
                    if (p.busy || self == null && error == null)
                      const LinearProgressIndicator(),
                    if (p.error != null)
                      DiscussionError(
                        p.error!,
                        retry: () => unawaited(p.refresh()),
                      ),
                    if (self != null && self!.authority == null)
                      Text(l.discussionUnavailable),
                    if (self?.authority != null) ...[
                      TextField(
                        key: const Key('discussion-name'),
                        controller: name,
                        readOnly: attempt != null,
                        decoration: InputDecoration(
                          labelText: l.discussionName,
                        ),
                        maxLength: 120,
                      ),
                      Text(l.discussionConsent),
                      if (attempt?.error != null)
                        DiscussionError(attempt!.error!),
                      if (attempt?.uncertain == true)
                        Text(l.discussionUncertain),
                      FilledButton(
                        key: const Key('discussion-create-submit'),
                        onPressed:
                            attempt?.busy == true ||
                                !p.loaded ||
                                p.error != null
                            ? null
                            : save,
                        child: Text(
                          attempt == null
                              ? l.discussionCreate
                              : l.discussionRetry,
                        ),
                      ),
                      if (attempt != null &&
                          !attempt.busy &&
                          !attempt.uncertain &&
                          attempt.receipt == null)
                        TextButton(
                          onPressed: () =>
                              commands.forget('create/${widget.groupId}'),
                          child: Text(l.discussionCancel),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// An own exit/decline discloses no room content and needs live Auth only. These
// explicit destinations remain usable when personal setup becomes incomplete.
class DiscussionExitScreen extends ConsumerWidget {
  const DiscussionExitScreen({
    required this.roomId,
    required this.objectId,
    required this.decline,
    super.key,
  });
  final String roomId, objectId;
  final bool decline;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        commands = ref.watch(discussionCommandsProvider),
        actor = ref.watch(authSessionProvider).identity?.id;
    return ListenableBuilder(
      listenable: commands,
      builder: (context, _) {
        final slot = 'exit/$objectId', attempt = commands.attempts[slot];
        Future<void> exit() async {
          if (actor == null) return;
          if (attempt == null &&
              !await confirmGroupAction(
                context,
                actor,
                decline ? l.discussionDecline : l.discussionLeave,
                explanation: decline ? null : l.discussionLeaveConfirm,
              )) {
            return;
          }
          if (!context.mounted ||
              ref.read(authSessionProvider).identity?.id != actor) {
            return;
          }
          final result = await commands.run(
            slot,
            actor,
            decline ? DiscussionAction.respond : DiscussionAction.leave,
            {
              'p_room_id': roomId,
              if (decline) 'p_invitation_id': objectId,
              if (decline) 'p_response': 'declined',
              if (!decline) 'p_admission_id': objectId,
            },
          );
          if (result != null &&
              context.mounted &&
              ref.read(authSessionProvider).identity?.id == actor) {
            commands.forget(slot);
            context.go('/messages');
          }
        }

        return PopScope(
          canPop: attempt?.busy != true && attempt?.uncertain != true,
          child: Scaffold(
            appBar: groupAppBar(
              context,
              decline ? l.discussionDecline : l.discussionLeave,
              fallback: '/messages',
              close: () {
                if (attempt?.busy != true && attempt?.uncertain != true) {
                  closeGroups(context, '/messages');
                }
              },
            ),
            body: GroupBody(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (!decline) Text(l.discussionLeaveConfirm),
                  if (attempt?.error != null) DiscussionError(attempt!.error!),
                  if (attempt?.uncertain == true) Text(l.discussionUncertain),
                  FilledButton(
                    onPressed: actor == null || attempt?.busy == true
                        ? null
                        : exit,
                    child: Text(
                      attempt?.uncertain == true
                          ? l.discussionRetry
                          : decline
                          ? l.discussionDecline
                          : l.discussionLeave,
                    ),
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
