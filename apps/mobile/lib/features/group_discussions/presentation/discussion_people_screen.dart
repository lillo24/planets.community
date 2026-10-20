import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../group_membership/application/group_relationship_controller.dart';
import '../../group_membership/data/group_relationship_gateway.dart';
import '../../group_membership/domain/group_relationships.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../../groups/presentation/group_widgets.dart';
import '../application/discussion_controllers.dart';
import '../data/discussion_gateway.dart';
import '../domain/discussion_models.dart';
import '../domain/discussion_invite_destination.dart';
import 'discussion_feedback.dart';
import 'discussion_routes.dart';
import 'discussion_invitation_link.dart';

class DiscussionPeopleScreen extends ConsumerStatefulWidget {
  const DiscussionPeopleScreen({required this.roomId, super.key});
  final String roomId;
  @override
  ConsumerState<DiscussionPeopleScreen> createState() =>
      _DiscussionPeopleScreenState();
}

class _DiscussionPeopleScreenState
    extends ConsumerState<DiscussionPeopleScreen> {
  DiscussionChatController? controller;
  DiscussionPager<DiscussionPerson>? people;
  DiscussionPager<DiscussionManagedInvitation>? invitations;
  GroupRelationshipPager<GroupPerson>? candidates;
  String? admission;
  bool selecting = false;
  @override
  void dispose() {
    people?.dispose();
    invitations?.dispose();
    candidates?.dispose();
    super.dispose();
  }

  bool valid(DiscussionChatController c, String episode) =>
      mounted &&
      controller == c &&
      !c.disposed &&
      c.room?.admissionId == episode &&
      c.room?.canReadPeople == true &&
      ref.read(authSessionProvider).identity?.id == c.actor;
  void bind(DiscussionChatController c) {
    final r = c.room;
    if (r == null || !r.canReadPeople) return;
    people?.dispose();
    invitations?.dispose();
    invitations = null;
    candidates?.dispose();
    candidates = null;
    selecting = false;
    admission = r.admissionId;
    final p = DiscussionPager<DiscussionPerson>(
      (cursor) => c.gateway.people(c.actor, c.roomId, cursor),
      () => valid(c, r.admissionId),
    );
    people = p;
    Future.microtask(p.load);
    if (r.canManage) {
      final i = DiscussionPager<DiscussionManagedInvitation>(
        (cursor) => c.gateway.managedInvitations(c.actor, c.roomId, cursor),
        () => valid(c, r.admissionId) && c.room?.canManage == true,
      );
      invitations = i;
      Future.microtask(i.load);
    }
  }

  void choose(DiscussionChatController c) {
    final r = c.room;
    if (r == null || !r.canInvite || r.archived || r.frozen) return;
    candidates?.dispose();
    final p = GroupRelationshipPager<GroupPerson>(
      (cursor) => ref
          .read(groupRelationshipGatewayProvider)
          .people(c.actor, r.groupId, cursor),
      () => valid(c, r.admissionId) && c.room?.canInvite == true,
    );
    setState(() {
      candidates = p;
      selecting = true;
    });
    unawaited(p.load());
  }

  Future<void> action(
    DiscussionChatController c,
    DiscussionAction action,
    String object,
  ) async {
    final room = c.room;
    if (room == null) return;
    final commands = ref.read(discussionCommandsProvider),
        slot = action == DiscussionAction.invite
            ? discussionInviteSlot(c.actor, room.groupId, room.id, object)
            : '${action.name}/$object';
    if (!(action == DiscussionAction.invite
            ? room.canInvite
            : room.canManage) &&
        commands.attempts[slot] == null) {
      return;
    }
    final intent = {
      'p_room_id': room.id,
      if (action == DiscussionAction.invite) 'p_profile_id': object,
      if (action == DiscussionAction.remove) 'p_admission_id': object,
      if (action == DiscussionAction.withdraw) 'p_invitation_id': object,
    };
    if (commands.attempts[slot] == null &&
        !await confirmGroupAction(
          context,
          c.actor,
          action == DiscussionAction.invite
              ? AppLocalizations.of(context).discussionInvite
              : action == DiscussionAction.withdraw
              ? AppLocalizations.of(context).discussionCancel
              : AppLocalizations.of(context).discussionRemove,
        )) {
      return;
    }
    if (!mounted ||
        !valid(c, room.admissionId) ||
        !await requireGroupPolicy(context, ref, c.actor)) {
      return;
    }
    if (!mounted || !valid(c, room.admissionId)) return;
    final result = await commands.run(slot, c.actor, action, intent);
    if (!mounted || !valid(c, room.admissionId)) return;
    if (result != null) {
      commands.forget(slot);
      people?.invalidate();
      invitations?.invalidate();
      if (action == DiscussionAction.invite) setState(() => selecting = false);
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
      people?.dispose();
      people = null;
      invitations?.dispose();
      invitations = null;
      candidates?.dispose();
      candidates = null;
      admission = null;
    });
    ref.listen(discussionSignalsProvider, (_, next) {
      if (next.asData?.value.connected == true) {
        people?.invalidate();
        invitations?.invalidate();
        if (selecting) candidates?.refresh();
      }
    });
    if (c != null && controller != c) {
      controller = c;
      Future.microtask(c.refresh);
    }
    return ListenableBuilder(
      listenable: Listenable.merge([
        commands,
        ?c,
        ?people,
        ?candidates,
        ?invitations,
      ]),
      builder: (context, _) {
        final room = c?.room?.canReadPeople == true ? c?.room : null;
        if (room == null &&
            (c?.room != null ||
                c?.error != null &&
                    discussionFailure(c!.error!) == DiscussionFailure.denied) &&
            (people != null || invitations != null || candidates != null)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                people?.dispose();
                people = null;
                invitations?.dispose();
                invitations = null;
                candidates?.dispose();
                candidates = null;
                admission = null;
                selecting = false;
                ref.read(discussionCommandsProvider).clearRoom(widget.roomId);
              });
            }
          });
        }
        if (c != null && room != null && admission != room.admissionId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && controller == c) {
              setState(() => bind(c));
            }
          });
        }
        if (room == null || !room.canInvite) {
          if (invitations != null || candidates != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  invitations?.dispose();
                  invitations = null;
                  candidates?.dispose();
                  candidates = null;
                  selecting = false;
                });
              }
            });
          }
          if (selecting) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => selecting = false);
            });
          }
        }
        final pending = commands.attempts.values.any(
          (a) =>
              a.intent['p_room_id'] == widget.roomId && (a.busy || a.uncertain),
        );
        return PopScope(
          canPop: !pending,
          child: Scaffold(
            appBar: groupAppBar(
              context,
              l.discussionPeople,
              fallback: discussionRoute(widget.roomId),
              close: () {
                if (!pending) {
                  closeGroups(context, discussionRoute(widget.roomId));
                }
              },
            ),
            body: GroupBody(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (room == null) ...[
                    if (c?.error != null)
                      DiscussionError(
                        c!.error!,
                        retry: () => unawaited(c.refresh()),
                      )
                    else if (c?.room != null)
                      Text(
                        l.discussionUnavailable,
                        key: const Key('discussion-people-unavailable'),
                      )
                    else
                      const CircularProgressIndicator(),
                  ],
                  if (room != null) ...[
                    if (room.canManage && !room.isGeneral && !room.frozen)
                      DiscussionInvitationLinkControls(
                        room: room,
                        actor: c!.actor,
                        onChanged: c.refresh,
                      ),
                    for (final entry in commands.attempts.entries.where(
                      (e) =>
                          {
                            DiscussionAction.invite,
                            DiscussionAction.remove,
                            DiscussionAction.withdraw,
                          }.contains(e.value.action) &&
                          e.value.intent['p_room_id'] == room.id &&
                          e.value.error != null,
                    )) ...[
                      DiscussionError(
                        entry.value.error!,
                        retry: () => unawaited(
                          action(
                            c!,
                            entry.value.action,
                            (entry.value.intent['p_profile_id'] ??
                                    entry.value.intent['p_admission_id'] ??
                                    entry.value.intent['p_invitation_id'])
                                as String,
                          ),
                        ),
                      ),
                      if (entry.value.uncertain)
                        Text(l.discussionUncertain)
                      else if (!entry.value.busy)
                        TextButton(
                          onPressed: () => commands.forget(entry.key),
                          child: Text(l.discussionCancel),
                        ),
                    ],
                    if (room.canManage && invitations != null) ...[
                      if (invitations!.busy) const LinearProgressIndicator(),
                      if (invitations!.error != null)
                        DiscussionError(
                          invitations!.error!,
                          retry: () => unawaited(invitations!.refresh()),
                        ),
                      for (final i in invitations!.rows)
                        ListTile(
                          title: Text(i.name ?? l.discussionAccountUnavailable),
                          subtitle: Text(l.discussionInvitations),
                          trailing: TextButton(
                            onPressed:
                                commands.attempts['withdraw/${i.id}']?.busy ==
                                    true
                                ? null
                                : () => action(
                                    c!,
                                    DiscussionAction.withdraw,
                                    i.id,
                                  ),
                            child: Text(l.discussionCancel),
                          ),
                        ),
                      if (invitations!.more)
                        TextButton(
                          onPressed: invitations!.busy
                              ? null
                              : () => unawaited(invitations!.load()),
                          child: Text(l.discussionLoadMore),
                        ),
                    ],
                    if (room.canInvite && !room.archived && !room.frozen)
                      OutlinedButton.icon(
                        onPressed: () => choose(c!),
                        icon: const Icon(Icons.person_add_outlined),
                        label: Text(l.discussionInvite),
                      ),
                    if (selecting && candidates != null) ...[
                      if (candidates!.busy) const LinearProgressIndicator(),
                      if (candidates!.error != null)
                        DiscussionError(
                          candidates!.error!,
                          retry: () => unawaited(candidates!.refresh()),
                        ),
                      for (final p in candidates!.rows)
                        if (p.id != c!.actor)
                          ListTile(
                            title: Text(p.name),
                            subtitle: Text(groupRoleLabel(l, p.authority)),
                            trailing: Builder(
                              builder: (context) {
                                final a =
                                    commands.attempts[discussionInviteSlot(
                                      c.actor,
                                      room.groupId,
                                      room.id,
                                      p.id,
                                    )];
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: l.discussionInvite,
                                      onPressed: a?.busy == true
                                          ? null
                                          : () => action(
                                              c,
                                              DiscussionAction.invite,
                                              p.id,
                                            ),
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                      for (final a in commands.attempts.entries.where(
                        (e) =>
                            e.key.startsWith('invite/') &&
                            e.value.intent['p_room_id'] == room.id,
                      ))
                        if (a.value.error != null)
                          DiscussionError(
                            a.value.error!,
                            retry: () => unawaited(
                              action(
                                c!,
                                DiscussionAction.invite,
                                a.value.intent['p_profile_id'] as String,
                              ),
                            ),
                          ),
                      if (candidates!.more)
                        TextButton(
                          onPressed: candidates!.busy
                              ? null
                              : () => unawaited(candidates!.load()),
                          child: Text(l.discussionLoadMore),
                        ),
                    ],
                    if (people?.busy == true) const LinearProgressIndicator(),
                    if (people?.error != null)
                      DiscussionError(
                        people!.error!,
                        retry: () => unawaited(people!.refresh()),
                      ),
                    for (final p in people?.rows ?? <DiscussionPerson>[])
                      ListTile(
                        title: Text(p.name ?? l.discussionAccountUnavailable),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Room provenance is distinct from Group authority.
                            if (!room.isGeneral &&
                                p.profileId == room.creatorId)
                              Text(
                                l.discussionIdeaCreator,
                                key: ValueKey(
                                  'discussion-creator-${p.profileId}',
                                ),
                              ),
                            Text(
                              groupRoleLabel(
                                l,
                                p.role == null
                                    ? null
                                    : GroupAuthority.parse(p.role),
                              ),
                            ),
                          ],
                        ),
                        trailing:
                            room.canManage &&
                                !room.archived &&
                                p.profileId != c!.actor
                            ? IconButton(
                                tooltip: l.discussionRemove,
                                onPressed:
                                    commands.attempts['remove/${p.id}']?.busy ==
                                        true
                                    ? null
                                    : () => action(
                                        c,
                                        DiscussionAction.remove,
                                        p.id,
                                      ),
                                icon: const Icon(Icons.person_remove_outlined),
                              )
                            : null,
                      ),
                    if (people?.more == true)
                      TextButton(
                        onPressed: people!.busy
                            ? null
                            : () => unawaited(people!.load()),
                        child: Text(l.discussionLoadMore),
                      ),
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
