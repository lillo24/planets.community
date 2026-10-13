import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../groups/application/group_controllers.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/presentation/group_widgets.dart';
import '../../profile_photo/presentation/profile_photo_trust_gate.dart';
import '../../project_participant_invites/presentation/share_link_buttons.dart';
import '../application/group_relationship_controller.dart';
import '../data/group_relationship_gateway.dart';
import '../domain/group_relationships.dart';
import 'group_membership_widgets.dart';

class GroupParticipationSection extends ConsumerStatefulWidget {
  const GroupParticipationSection({
    required this.groupId,
    required this.publicAvailable,
    this.onChanged,
    super.key,
  });
  final VoidCallback? onChanged;
  final String groupId;
  final bool publicAvailable;
  @override
  ConsumerState<GroupParticipationSection> createState() =>
      _GroupParticipationSectionState();
}

class _GroupParticipationSectionState
    extends ConsumerState<GroupParticipationSection> {
  String? actor;
  GroupSelfContext? own;
  Object? error;
  final note = TextEditingController();
  bool loading = false, statusUncertain = false;
  int revision = 0;
  String get slot => 'detail/${widget.groupId}';
  bool valid(String id) =>
      mounted &&
      actor == id &&
      ref.read(authSessionProvider).identity?.id == id;
  @override
  void initState() {
    super.initState();
    Future.microtask(bind);
  }

  void bind() {
    final id = ref.read(authSessionProvider).identity?.id;
    if (id == actor && own != null) return;
    actor = id;
    revision++;
    own = null;
    error = null;
    note.clear();
    final retained = ref.read(groupCommandRegistryProvider).attempts[slot];
    if (retained?.actor == id &&
        retained?.mutation == GroupMutation.request &&
        retained?.receipt == null) {
      note.text = retained!.intent['p_note'] as String? ?? '';
    } else if (id != null) {
      note.text = ref.read(groupRequestDraftsProvider)['$id/$slot'] ?? '';
    }
    if (id != null) {
      load();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> load() async {
    final id = actor;
    if (id == null || !mounted) return;
    final epoch = ++revision;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final row = await ref
          .read(groupRelationshipGatewayProvider)
          .self(id, widget.groupId);
      if (valid(id) && epoch == revision) {
        if (row.pendingRequestId != null || row.membershipId != null) {
          ref.read(groupRequestDraftsProvider).remove('$id/$slot');
          note.clear();
        }
        setState(() {
          own = row;
          statusUncertain = false;
        });
      }
    } catch (e) {
      if (valid(id) && epoch == revision) {
        setState(() {
          error = e;
          if (groupFailure(e) == GroupFailure.denied) {
            own = null;
            note.clear();
            ref.read(groupRequestDraftsProvider).remove('$id/$slot');
          }
        });
      }
    } finally {
      if (valid(id) && epoch == revision) setState(() => loading = false);
    }
  }

  Future<void> command(
    GroupMutation action,
    Map<String, dynamic> intent,
    String label,
  ) async {
    final id = actor;
    if (id == null || !valid(id)) return;
    final store = ref.read(groupCommandRegistryProvider);
    final pending = store.attempts[slot];
    if (pending?.receipt != null) {
      await load();
      if (valid(id) && error == null) store.forget(slot);
      return;
    }
    if (pending == null) {
      if (action == GroupMutation.request) {
        if (groupLength(groupTrim(note.text)) > 500) return;
        if (!await requireGroupPolicy(context, ref, id) || !mounted) return;
        if (!await requireProfilePhotoForTrustAction(
          context: context,
          ref: ref,
          expectedProfileId: id,
          reason: ProfilePhotoTrustReason.requestToJoin,
        )) {
          return;
        }
        if (!valid(id)) return;
      } else if (!await confirmGroupAction(
        context,
        id,
        label,
        explanation: AppLocalizations.of(context).groupIndependentRoles,
      )) {
        return;
      }
    }
    if (!action.exit &&
        (!mounted || !await requireGroupPolicy(context, ref, id))) {
      return;
    }
    if (!valid(id)) return;
    final result = await store.run(
      slot,
      id,
      action,
      intent,
      policyAllows: () => groupPolicyAllows(ref, id),
    );
    if (!valid(id)) return;
    if (store.attempts[slot]?.failure == GroupFailure.denied) {
      ref.read(groupRequestDraftsProvider).remove('$id/$slot');
      note.clear();
      setState(() => own = null);
    }
    if (result != null) {
      ref.read(groupRequestDraftsProvider).remove('$id/$slot');
      note.clear();
      setState(() => statusUncertain = true);
      await load();
      if (valid(id) && error == null) store.forget(slot);
    }
  }

  @override
  void dispose() {
    revision++;
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        session = ref.watch(authSessionProvider);
    ref.listen(
      authSessionProvider.select((s) => s.identity?.id),
      (_, _) => bind(),
    );
    final store = ref.watch(groupCommandRegistryProvider);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final attempt = store.attempts[slot],
            self = actor == session.identity?.id ? own : null;
        final busy = loading || attempt?.busy == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.publicAvailable) ...[
              Text(l.groupSharingExplanation),
              ShareLinkButtons(
                projectId: widget.groupId,
                prepare: () async =>
                    'https://planets.community/groups/${widget.groupId}',
              ),
              const SizedBox(height: 16),
            ],
            if (session.identity == null && widget.publicAvailable)
              FilledButton(
                key: const Key('group-sign-in'),
                onPressed: () => context.push(
                  Uri(
                    path: '/auth',
                    queryParameters: {'returnTo': '/groups/${widget.groupId}'},
                  ).toString(),
                ),
                child: Text(l.groupSignIn),
              ),
            if (session.identity != null && actor == session.identity?.id) ...[
              if (loading) const LinearProgressIndicator(),
              if (error != null) GroupLoadError(error: error, retry: load),
              if (statusUncertain) Text(l.groupStatusUnknown),
              GroupActionFailure(attempt?.failure),
              if (session.phase == AuthSessionPhase.profileSetupRequired &&
                  self == null)
                OutlinedButton(
                  onPressed: () => context.push(
                    Uri(
                      path: '/profile/edit',
                      queryParameters: {
                        'returnTo': '/groups/${widget.groupId}',
                      },
                    ).toString(),
                  ),
                  child: Text(l.groupCompleteProfile),
                ),
              if (attempt != null &&
                  !attempt.busy &&
                  {
                    GroupFailure.invalid,
                    GroupFailure.stale,
                    GroupFailure.denied,
                    GroupFailure.prerequisite,
                  }.contains(attempt.failure))
                OutlinedButton(
                  onPressed: () async {
                    store.forget(slot);
                    await load();
                  },
                  child: Text(l.groupsDiscard),
                ),
              if (attempt != null &&
                  attempt.receipt == null &&
                  !attempt.busy &&
                  attempt.failure != null)
                OutlinedButton(
                  key: const Key('group-action-retry'),
                  onPressed: () =>
                      command(attempt.mutation, attempt.intent, l.groupsRetry),
                  child: Text(l.groupsRetry),
                ),
              if (attempt?.receipt != null && error != null)
                OutlinedButton(
                  onPressed: () => command(
                    attempt!.mutation,
                    attempt.intent,
                    l.groupRetryStatus,
                  ),
                  child: Text(l.groupRetryStatus),
                ),
              if (self != null) ...[
                if (self.authority != null)
                  Text(
                    groupRoleLabel(l, self.authority),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                if (self.membershipId != null) Text(l.groupMember),
                if (self.latestMembershipStatus == 'left' ||
                    self.latestMembershipStatus == 'removed')
                  Text(l.groupFormer),
                if (self.latestRequestStatus != null &&
                    self.pendingRequestId == null)
                  Text(groupRelationshipStatus(l, self.latestRequestStatus)),
                if (self.pendingRequestId != null) ...[
                  Text(l.groupPending),
                  if (self.pendingNote != null) Text(self.pendingNote!),
                  OutlinedButton(
                    key: const Key('group-withdraw'),
                    onPressed: busy
                        ? null
                        : () => command(GroupMutation.withdraw, {
                            'p_request_id': self.pendingRequestId,
                          }, l.groupWithdraw),
                    child: Text(l.groupWithdraw),
                  ),
                ],
                if (widget.publicAvailable &&
                    self.pendingRequestId == null &&
                    self.membershipId == null &&
                    !self.manager) ...[
                  if (session.phase == AuthSessionPhase.ready) ...[
                    TextField(
                      key: const Key('group-request-note'),
                      controller: note,
                      enabled: !busy && attempt == null,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l.groupRequestNote,
                        helperText: l.groupRequestNoteHelp,
                        helperMaxLines: 5,
                        errorText: groupLength(groupTrim(note.text)) > 500
                            ? l.groupsLimit
                            : null,
                      ),
                      onChanged: (value) {
                        if (actor != null) {
                          ref.read(groupRequestDraftsProvider)['$actor/$slot'] =
                              value;
                        }
                        setState(() {});
                      },
                    ),
                    FilledButton(
                      key: const Key('group-submit-request'),
                      onPressed:
                          busy ||
                              attempt != null ||
                              groupLength(groupTrim(note.text)) > 500
                          ? null
                          : () => command(GroupMutation.request, {
                              'p_group_id': widget.groupId,
                              'p_note': groupTrim(note.text).isEmpty
                                  ? null
                                  : groupTrim(note.text),
                            }, l.groupSubmitRequest),
                      child: Text(l.groupSubmitRequest),
                    ),
                  ] else
                    OutlinedButton(
                      onPressed: () => context.push(
                        Uri(
                          path: '/profile/edit',
                          queryParameters: {
                            'returnTo': '/groups/${widget.groupId}',
                          },
                        ).toString(),
                      ),
                      child: Text(l.groupCompleteProfile),
                    ),
                ],
                if (self.people)
                  OutlinedButton.icon(
                    key: const Key('group-people'),
                    onPressed: () async {
                      await context.push('/groups/${widget.groupId}/people');
                      if (mounted) await load();
                    },
                    icon: const Icon(Icons.people_outline),
                    label: Text(l.groupPeople),
                  ),
                if (self.manager) ...[
                  OutlinedButton(
                    onPressed: () =>
                        context.push('/groups/${widget.groupId}/requests'),
                    child: Text(l.groupRequests),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        context.push('/groups/${widget.groupId}/memberships'),
                    child: Text(l.groupMembershipHistory),
                  ),
                  OutlinedButton(
                    onPressed: () => context.push(
                      '/groups/${widget.groupId}/participant-links',
                    ),
                    child: Text(l.groupParticipantLinks),
                  ),
                ],
                if (self.structural)
                  OutlinedButton(
                    key: const Key('group-team'),
                    onPressed: () =>
                        context.push('/groups/${widget.groupId}/team'),
                    child: Text(l.groupTeam),
                  ),
                if (self.authority == GroupAuthority.creator ||
                    self.authority == GroupAuthority.coCreator)
                  OutlinedButton(
                    key: const Key('group-manage'),
                    onPressed: () async {
                      await context.push(
                        '/groups/${widget.groupId}/${self.authority == GroupAuthority.creator ? 'edit' : 'structural-edit'}',
                      );
                      if (mounted) {
                        await load();
                        widget.onChanged?.call();
                      }
                    },
                    child: Text(l.groupsEdit),
                  ),
                if (widget.publicAvailable && self.structural)
                  OutlinedButton.icon(
                    key: const Key('group-create-project'),
                    onPressed: () => context.push(
                      '/proposals/create?group=${widget.groupId}',
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(l.groupProjectCreate),
                  ),
                if (self.membershipId != null)
                  OutlinedButton(
                    key: const Key('group-leave'),
                    onPressed: busy
                        ? null
                        : () => command(GroupMutation.leave, {
                            'p_membership_id': self.membershipId,
                          }, l.groupLeave),
                    child: Text(l.groupLeave),
                  ),
                if (self.delegateId != null)
                  OutlinedButton(
                    key: const Key('group-step-down'),
                    onPressed: busy
                        ? null
                        : () => command(GroupMutation.stepDown, {
                            'p_delegate_id': self.delegateId,
                          }, l.groupStepDown),
                    child: Text(l.groupStepDown),
                  ),
                if (self.manager) Text(l.groupIndependentRoles),
              ],
            ],
          ],
        );
      },
    );
  }
}
