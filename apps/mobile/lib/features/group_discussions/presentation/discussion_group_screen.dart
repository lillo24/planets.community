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
  final name = TextEditingController(), purpose = TextEditingController();
  String visibility = 'group';
  DiscussionPager<DiscussionRoom>? pager;
  String? actor;
  GroupSelfContext? self;
  DiscussionSettings? settings;
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
    purpose.dispose();
    super.dispose();
  }

  Future<void> bind(String id, {bool reset = true}) async {
    actor = id;
    error = null;
    if (reset) {
      self = null;
      settings = null;
      name.clear();
      purpose.clear();
    }
    final captured = ++epoch;
    try {
      final own = await ref
          .read(groupRelationshipGatewayProvider)
          .self(id, widget.groupId);
      final config = await ref
          .read(discussionGatewayProvider)
          .settings(id, widget.groupId);
      if (!mounted ||
          captured != epoch ||
          ref.read(authSessionProvider).identity?.id != id) {
        return;
      }
      setState(() {
        self = own;
        settings = config;
        if (reset) {
          final intent = ref
              .read(discussionCommandsProvider)
              .attempts['create/${widget.groupId}']
              ?.intent;
          name.text = intent?['p_title'] as String? ?? '';
          purpose.text = intent?['p_purpose'] as String? ?? '';
          visibility = intent?['p_visibility'] as String? ?? 'group';
        }
      });
    } catch (failure) {
      if (mounted && captured == epoch) {
        setState(() {
          error = failure;
          settings = null;
        });
      }
    }
  }

  Future<void> save() async {
    final id = actor;
    if (id == null || settings?.canCreate != true) return;
    final commands = ref.read(discussionCommandsProvider),
        slot = 'create/${widget.groupId}';
    final attempt = commands.attempts[slot];
    final intent =
        attempt?.intent ??
        {
          'p_group_id': widget.groupId,
          'p_title': name.text.trim(),
          'p_purpose': purpose.text.trim(),
          'p_visibility': visibility,
        };
    if ((intent['p_title'] as String).runes.isEmpty ||
        (intent['p_title'] as String).runes.length > 120 ||
        (intent['p_purpose'] as String).runes.length > 500) {
      setState(
        () => error = const FormatException('Invalid Idea title or purpose.'),
      );
      return;
    }
    if (!await requireGroupPolicy(context, ref, id) ||
        !mounted ||
        ref.read(authSessionProvider).identity?.id != id) {
      return;
    }
    final receipt = await commands.run(
      slot,
      id,
      DiscussionAction.create,
      intent,
    );
    if (!mounted || ref.read(authSessionProvider).identity?.id != id) return;
    if (receipt != null) {
      commands.forget(slot);
      context.pushReplacement(discussionRoute(receipt.roomId));
    } else {
      await bind(id, reset: false);
    }
  }

  Future<void> changePolicy(String policy) async {
    final id = actor, config = settings;
    if (id == null || config == null || !config.canEdit) return;
    final commands = ref.read(discussionCommandsProvider),
        slot = 'settings/${widget.groupId}';
    final intent =
        commands.attempts[slot]?.intent ??
        {
          'p_group_id': widget.groupId,
          'p_expected_version': config.version,
          'p_creation_policy': policy,
        };
    if (!await requireGroupPolicy(context, ref, id) ||
        !mounted ||
        ref.read(authSessionProvider).identity?.id != id) {
      return;
    }
    final result = await commands.run(
      slot,
      id,
      DiscussionAction.settings,
      intent,
    );
    if (!mounted || ref.read(authSessionProvider).identity?.id != id) return;
    if (result != null) commands.forget(slot);
    await bind(id, reset: false);
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(authSessionProvider).identity?.id,
        l = AppLocalizations.of(context),
        p = ref.watch(discussionRoomsProvider(widget.groupId));
    ref.listen(authSessionProvider.select((s) => (s.identity?.id, s.phase)), (
      _,
      _,
    ) {
      epoch++;
      name.clear();
      purpose.clear();
      self = null;
      settings = null;
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
        final attempt = commands.attempts['create/${widget.groupId}'],
            settingAttempt = commands.attempts['settings/${widget.groupId}'];
        final locked =
            attempt?.busy == true ||
            attempt?.uncertain == true ||
            settingAttempt?.busy == true ||
            settingAttempt?.uncertain == true;
        return PopScope(
          canPop: !locked,
          child: Scaffold(
            appBar: groupAppBar(
              context,
              widget.create ? l.discussionCreate : l.discussionTitle,
              fallback: '/messages',
              close: () {
                if (!locked) closeGroups(context, '/messages');
              },
            ),
            body: GroupBody(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (error != null)
                    DiscussionError(
                      error!,
                      retry: () =>
                          id == null ? null : unawaited(bind(id, reset: false)),
                    ),
                  if (settings == null && error == null)
                    const LinearProgressIndicator(),
                  if (!widget.create) ...[
                    Text(l.discussionPlanningHelp),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: settings?.canCreate == true
                              ? () => context.push(
                                  discussionCreateRoute(widget.groupId),
                                )
                              : null,
                          icon: const Icon(Icons.add_comment_outlined),
                          label: Text(l.discussionCreate),
                        ),
                        OutlinedButton.icon(
                          onPressed: self?.structural == true
                              ? () => context.push(
                                  '/proposals/create?group=${widget.groupId}',
                                )
                              : null,
                          icon: const Icon(Icons.add),
                          label: Text(l.groupProjectCreate),
                        ),
                      ],
                    ),
                    if (settings?.canCreate == false)
                      Text(l.discussionCreationRestricted),
                    if (settings != null)
                      ExpansionTile(
                        title: Text(l.discussionSettings),
                        children: [
                          Text(l.discussionCreationHelp),
                          DropdownButtonFormField<String>(
                            key: ValueKey('policy-${settings!.version}'),
                            initialValue: settings!.policy,
                            decoration: InputDecoration(
                              labelText: l.discussionWhoCreates,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'managers',
                                child: Text(l.discussionManagersOnly),
                              ),
                              DropdownMenuItem(
                                value: 'members',
                                child: Text(l.discussionAllMembers),
                              ),
                            ],
                            onChanged: settings!.canEdit && !locked
                                ? (value) {
                                    if (value != null) {
                                      unawaited(changePolicy(value));
                                    }
                                  }
                                : null,
                          ),
                          if (!settings!.canEdit)
                            Text(l.discussionSettingsAuthority),
                          if (settingAttempt?.error != null)
                            DiscussionError(
                              settingAttempt!.error!,
                              retry: () => unawaited(
                                changePolicy(
                                  settingAttempt.intent['p_creation_policy']
                                      as String,
                                ),
                              ),
                            ),
                        ],
                      ),
                    if (settings?.generalRoomId != null)
                      ListTile(
                        leading: const Icon(Icons.folder_shared_outlined),
                        title: Text(l.discussionGroupWorkspace),
                        subtitle: Text(l.discussionExternalHint),
                        onTap: () => context.push(
                          discussionLinksRoute(settings!.generalRoomId!),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (p != null) DiscussionRoomList(p),
                  ],
                  if (widget.create) ...[
                    Text(l.discussionPlanningHelp),
                    if (settings?.canCreate == false)
                      Text(l.discussionCreationRestricted),
                    if (settings?.canCreate == true || attempt != null) ...[
                      TextField(
                        key: const Key('discussion-name'),
                        controller: name,
                        readOnly: attempt != null,
                        decoration: InputDecoration(
                          labelText: l.discussionName,
                        ),
                        maxLength: 120,
                      ),
                      TextField(
                        key: const Key('discussion-purpose'),
                        controller: purpose,
                        readOnly: attempt != null,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: l.discussionPurpose,
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: visibility,
                        decoration: InputDecoration(
                          labelText: l.discussionAudience,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'group',
                            child: Text(l.discussionGroupVisible),
                          ),
                          DropdownMenuItem(
                            value: 'invitation',
                            child: Text(l.discussionInviteOnly),
                          ),
                        ],
                        onChanged: attempt == null
                            ? (value) => setState(() => visibility = value!)
                            : null,
                      ),
                      Text(l.discussionManagerDisclosure),
                      Text(l.discussionConsent),
                      if (attempt?.error != null)
                        DiscussionError(attempt!.error!),
                      if (attempt?.uncertain == true)
                        Text(l.discussionUncertain),
                      FilledButton(
                        key: const Key('discussion-create-submit'),
                        onPressed:
                            attempt?.busy == true || settings?.canCreate != true
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
