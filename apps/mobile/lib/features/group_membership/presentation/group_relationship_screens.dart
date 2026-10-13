import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/user_scroll_pagination.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../groups/data/group_gateway.dart';
import '../../groups/application/group_controllers.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/presentation/group_widgets.dart';
import '../../project_participant_invites/presentation/share_link_buttons.dart';
import '../application/group_relationship_controller.dart';
import '../data/group_relationship_gateway.dart';
import '../domain/group_relationships.dart';
import 'group_membership_widgets.dart';

class MyGroupRelationshipsScreen extends StatelessWidget {
  const MyGroupRelationshipsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: groupAppBar(context, l.groupsMy),
      body: GroupBody(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final section in [
              (l.groupManaged, 'managed', Icons.edit_outlined),
              (l.groupJoined, 'memberships', Icons.groups_outlined),
              (l.groupOwnRequests, 'requests', Icons.pending_actions),
              (l.groupOffers, 'offers', Icons.badge_outlined),
            ])
              Card(
                child: ListTile(
                  leading: Icon(section.$3),
                  title: Text(section.$1),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/groups/mine/${section.$2}'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/groups/create'),
              icon: const Icon(Icons.add),
              label: Text(l.groupsCreate),
            ),
          ],
        ),
      ),
    );
  }
}

class GroupRelationshipsScreen extends ConsumerWidget {
  const GroupRelationshipsScreen({this.groupId, this.family, super.key});
  final String? groupId;
  final GroupHistoryKind? family; // null is the rank/UUID People projection.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(authSessionProvider).identity?.id;
    if (actor == null) {
      return Scaffold(
        appBar: groupAppBar(context, AppLocalizations.of(context).groupsMy),
        body: const SizedBox.shrink(),
      );
    }
    return _GroupRelationships(
      key: ValueKey((actor, groupId, family)),
      actor: actor,
      groupId: groupId,
      family: family,
    );
  }
}

class _GroupRelationships extends ConsumerStatefulWidget {
  const _GroupRelationships({
    required this.actor,
    this.groupId,
    this.family,
    super.key,
  });
  final String actor;
  final String? groupId;
  final GroupHistoryKind? family;
  @override
  ConsumerState<_GroupRelationships> createState() =>
      _GroupRelationshipsState();
}

class _GroupRelationshipsState extends ConsumerState<_GroupRelationships> {
  late final GroupRelationshipPager<GroupPageRow> pager;
  GroupSelfContext? self;
  bool valid() =>
      mounted && ref.read(authSessionProvider).identity?.id == widget.actor;
  String get slot => 'list/${widget.groupId}/${widget.family}';
  @override
  void initState() {
    super.initState();
    final gateway = ref.read(groupRelationshipGatewayProvider);
    pager = GroupRelationshipPager((cursor) async {
      if (widget.groupId != null) {
        final role = await gateway.self(widget.actor, widget.groupId!);
        if (!valid()) return <GroupPageRow>[];
        self = role;
      }
      return widget.family == null
          ? gateway.people(widget.actor, widget.groupId!, cursor)
          : gateway.history(
              widget.actor,
              widget.family!,
              group: widget.groupId,
              cursor: cursor,
            );
    }, valid);
    Future.microtask(pager.load);
  }

  @override
  void dispose() {
    pager.dispose();
    super.dispose();
  }

  Future<GroupRelationshipReceipt?> command(
    GroupMutation action,
    Map<String, dynamic> intent,
    String label, {
    GroupAuthority? offered,
  }) async {
    if (!mounted || !valid()) return null;
    final registry = ref.read(groupCommandRegistryProvider);
    final pending = registry.attempts[slot];
    if (pending == null &&
        !await confirmGroupAction(
          context,
          widget.actor,
          label,
          explanation: offered == GroupAuthority.coCreator
              ? AppLocalizations.of(context).groupCoCreatorWarning
              : action == GroupMutation.remove ||
                    action == GroupMutation.revokeRole
              ? AppLocalizations.of(context).groupIndependentRoles
              : null,
        )) {
      return null;
    }
    if (!mounted ||
        !valid() ||
        (!action.exit &&
            !await requireGroupPolicy(context, ref, widget.actor))) {
      return null;
    }
    // This current identity/authority read follows every confirmation/policy wait.
    if (widget.groupId != null) {
      try {
        self = await ref
            .read(groupRelationshipGatewayProvider)
            .self(widget.actor, widget.groupId!);
      } catch (e) {
        if (valid()) {
          pager.clear();
          setState(() => pager.error = e);
        }
        return null;
      }
    }
    if (!mounted || !valid()) return null;
    final result = await registry.run(
      slot,
      widget.actor,
      action,
      intent,
      policyAllows: () => groupPolicyAllows(ref, widget.actor),
    );
    if (!mounted || !valid()) return null;
    if (result != null) {
      try {
        final own = await ref
            .read(groupRelationshipGatewayProvider)
            .self(widget.actor, result.groupId);
        if (!mounted || !valid()) return null;
        if (widget.groupId != null) self = own;
      } catch (e) {
        if (!mounted || !valid()) return null;
        if (groupFailure(e) == GroupFailure.denied) pager.clear();
        setState(() => pager.error = e);
        return result;
      }
      await pager.refresh();
      if (!mounted || !valid()) return null;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.currentStatus == null
                ? l.groupStatusUnknown
                : l.groupRecorded,
          ),
        ),
      );
      registry.forget(slot);
    }
    if (result == null &&
        registry.attempts[slot]?.failure == GroupFailure.denied) {
      self = null;
      pager.clear();
    }
    return result;
  }

  Future<GroupAuthority?> selectRole(String title) async {
    final selected = await showDialog<GroupAuthority>(
      context: context,
      builder: (context) => _RoleChoice(actor: widget.actor, title: title),
    );
    return valid() ? selected : null;
  }

  Future<void> createInvitation() async {
    final l = AppLocalizations.of(context),
        registry = ref.read(groupCommandRegistryProvider);
    final pending = registry.attempts[slot];
    final role = pending == null
        ? await selectRole(l.groupInviteRole)
        : GroupAuthority.parse(pending.intent['p_role']);
    if (role == null || !mounted) return;
    final result = await command(
      GroupMutation.invite,
      {'p_group_id': widget.groupId, 'p_role': role.wire},
      l.groupInviteRole,
      offered: role,
    );
    if (result == null || !mounted || !valid()) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _AuthorityHandoff(
        actor: widget.actor,
        groupId: widget.groupId!,
        receipt: result,
      ),
    );
  }

  String title(AppLocalizations l) => switch (widget.family) {
    null => l.groupPeople,
    GroupHistoryKind.requests =>
      widget.groupId == null ? l.groupOwnRequests : l.groupRequests,
    GroupHistoryKind.memberships =>
      widget.groupId == null ? l.groupJoined : l.groupMembershipHistory,
    GroupHistoryKind.delegates => l.groupTeam,
    GroupHistoryKind.offers =>
      widget.groupId == null ? l.groupOffers : l.groupInviteHistory,
    GroupHistoryKind.roleChanges => l.groupRoleHistory,
    GroupHistoryKind.links => l.groupLinkHistory,
    GroupHistoryKind.managed => l.groupManaged,
  };
  Widget action(String label, VoidCallback callback, {Key? key}) =>
      OutlinedButton(
        key: key,
        onPressed:
            ref.read(groupCommandRegistryProvider).attempts[slot]?.busy == true
            ? null
            : callback,
        child: Text(label),
      );
  List<Widget> personActions(GroupPerson row, AppLocalizations l) => [
    if (self?.manager == true &&
        row.membershipId != null &&
        row.id != widget.actor)
      action(
        l.groupRemove,
        () => command(GroupMutation.remove, {
          'p_membership_id': row.membershipId,
        }, l.groupRemove),
      ),
    if (self?.structural == true &&
        row.membershipId != null &&
        row.authority == null &&
        row.id != widget.actor)
      action(l.groupOfferRole, () async {
        final role = await selectRole(l.groupOfferRole);
        if (role != null && mounted) {
          await command(
            GroupMutation.offer,
            {
              'p_group_id': widget.groupId,
              'p_membership_id': row.membershipId,
              'p_role': role.wire,
            },
            l.groupOfferRole,
            offered: role,
          );
        }
      }),
  ];
  List<Widget> historyActions(GroupHistoryRow row, AppLocalizations l) =>
      switch (row.family) {
        GroupHistoryKind.requests => [
          if (row.status == 'pending' &&
              widget.groupId != null &&
              row.personId != widget.actor &&
              self?.manager == true) ...[
            action(
              l.groupAccept,
              () => command(GroupMutation.acceptRequest, {
                'p_request_id': row.id,
              }, l.groupAccept),
            ),
            action(
              l.groupReject,
              () => command(GroupMutation.rejectRequest, {
                'p_request_id': row.id,
              }, l.groupReject),
            ),
          ],
          if (row.status == 'pending' && row.personId == widget.actor)
            action(
              l.groupWithdraw,
              () => command(GroupMutation.withdraw, {
                'p_request_id': row.id,
              }, l.groupWithdraw),
            ),
        ],
        GroupHistoryKind.memberships => [
          if (row.status == 'current' && row.personId == widget.actor)
            action(
              l.groupLeave,
              () => command(GroupMutation.leave, {
                'p_membership_id': row.id,
              }, l.groupLeave),
            ),
          if (row.status == 'current' &&
              widget.groupId != null &&
              row.personId != widget.actor &&
              self?.manager == true)
            action(
              l.groupRemove,
              () => command(GroupMutation.remove, {
                'p_membership_id': row.id,
              }, l.groupRemove),
            ),
        ],
        GroupHistoryKind.delegates => [
          if (row.status == 'current' && row.personId == widget.actor)
            action(
              l.groupStepDown,
              () => command(GroupMutation.stepDown, {
                'p_delegate_id': row.id,
              }, l.groupStepDown),
            ),
          if (row.status == 'current' &&
              row.personId != widget.actor &&
              self?.structural == true) ...[
            action(l.groupChangeRole, () async {
              final role = await selectRole(l.groupChangeRole);
              if (role != null && mounted) {
                await command(
                  GroupMutation.changeRole,
                  {'p_delegate_id': row.id, 'p_role': role.wire},
                  l.groupChangeRole,
                  offered: role,
                );
              }
            }),
            action(
              l.groupRevokeRole,
              () => command(GroupMutation.revokeRole, {
                'p_delegate_id': row.id,
              }, l.groupRevokeRole),
            ),
          ],
        ],
        GroupHistoryKind.offers => [
          if (row.status == 'pending' &&
              widget.groupId == null &&
              row.personId == widget.actor) ...[
            action(
              l.groupAccept,
              () => command(
                GroupMutation.acceptOffer,
                {'p_offer_id': row.id},
                l.groupAcceptAuthority,
                offered: row.role,
              ),
            ),
            action(
              l.groupDecline,
              () => command(GroupMutation.declineOffer, {
                'p_offer_id': row.id,
              }, l.groupDecline),
            ),
          ],
          if (row.status == 'pending' &&
              widget.groupId != null &&
              self?.structural == true)
            action(
              l.groupRevoke,
              () => command(GroupMutation.revokeInvite, {
                'p_invitation_id': row.id,
              }, l.groupRevoke),
            ),
        ],
        _ => [],
      };
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        registry = ref.watch(groupCommandRegistryProvider);
    ref.listen(authSessionProvider.select((s) => s.identity?.id), (_, next) {
      if (next != widget.actor) pager.clear();
    });
    return Scaffold(
      appBar: groupAppBar(context, title(l)),
      body: GroupBody(
        child: ListenableBuilder(
          listenable: Listenable.merge([pager, registry]),
          builder: (context, _) {
            final attempt = registry.attempts[slot];
            return UserScrollPagination(
              enabled: pager.more && !pager.busy && pager.error == null,
              requestKey: (pager.revision, pager.rows.length),
              onLoad: pager.load,
              builder: (context, fallback) => RefreshIndicator(
                onRefresh: pager.refresh,
                child: ListView(
                  key: PageStorageKey((
                    widget.actor,
                    widget.groupId,
                    widget.family,
                  )),
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (widget.family == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(l.groupPeoplePrivacy),
                      ),
                    if (widget.family == GroupHistoryKind.delegates &&
                        self?.structural == true) ...[
                      FilledButton.icon(
                        key: const Key('group-invite-organizer'),
                        onPressed: attempt?.busy == true
                            ? null
                            : createInvitation,
                        icon: const Icon(Icons.person_add_outlined),
                        label: Text(l.groupInviteRole),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final section in [
                            (l.groupInviteHistory, 'authority-invitations'),
                            (l.groupRoleHistory, 'role-history'),
                          ])
                            OutlinedButton(
                              onPressed: () => context.push(
                                '/groups/${widget.groupId}/${section.$2}',
                              ),
                              child: Text(section.$1),
                            ),
                        ],
                      ),
                      Text(l.groupIndependentRoles),
                    ],
                    if (pager.busy || attempt?.busy == true)
                      const LinearProgressIndicator(),
                    GroupActionFailure(attempt?.failure),
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
                          registry.forget(slot);
                          await pager.refresh();
                        },
                        child: Text(l.groupsDiscard),
                      ),
                    if (attempt != null &&
                        attempt.failure != null &&
                        !attempt.busy)
                      OutlinedButton(
                        onPressed: () => command(
                          attempt.mutation,
                          attempt.intent,
                          l.groupsRetry,
                        ),
                        child: Text(l.groupsRetry),
                      ),
                    if (pager.error != null)
                      GroupLoadError(error: pager.error, retry: pager.refresh),
                    if (pager.rows.isEmpty &&
                        !pager.busy &&
                        pager.error == null)
                      Text(l.groupNoRows),
                    for (final row in pager.rows)
                      Card(
                        key: ValueKey(row.id),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (row is GroupPerson) ...[
                                Text(
                                  row.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Chip(
                                      label: Text(
                                        groupRoleLabel(l, row.authority),
                                      ),
                                    ),
                                    if (row.membershipId != null &&
                                        row.authority != null)
                                      Chip(label: Text(l.groupMember)),
                                  ],
                                ),
                                if (row.joinedAt != null)
                                  Text(
                                    MaterialLocalizations.of(
                                      context,
                                    ).formatMediumDate(row.joinedAt!.toLocal()),
                                  ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: personActions(row, l),
                                ),
                              ],
                              if (row is GroupHistoryRow) ...[
                                if (row.family == GroupHistoryKind.managed) ...[
                                  Text(
                                    row.name!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(groupRoleLabel(l, row.role)),
                                  Text(groupStateLabel(l, row.publication!)),
                                  if (row.suppressed == true)
                                    Text(l.groupsHidden),
                                  OutlinedButton(
                                    onPressed: () => context.push(
                                      '/groups/${row.id}${row.role == GroupAuthority.creator ? '/edit' : ''}',
                                    ),
                                    child: Text(
                                      row.role == GroupAuthority.creator
                                          ? l.groupsEdit
                                          : l.groupsTitle,
                                    ),
                                  ),
                                ] else ...[
                                  if (row.groupId != null &&
                                      widget.groupId == null)
                                    _GroupPublicName(groupId: row.groupId!),
                                  if (row.name != null)
                                    Text(
                                      row.name!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  if (row.status != null)
                                    Text(
                                      groupRelationshipStatus(l, row.status),
                                    ),
                                  if (row.role != null)
                                    Text(groupRoleLabel(l, row.role)),
                                  if (row.initialRole != null)
                                    Text(
                                      '${l.groupInitialRole}: ${groupRoleLabel(l, row.initialRole)}',
                                    ),
                                  Text(
                                    MaterialLocalizations.of(
                                      context,
                                    ).formatMediumDate(row.createdAt.toLocal()),
                                  ),
                                  if (row.expiresAt != null)
                                    Text(
                                      '${l.groupExpiry}: ${MaterialLocalizations.of(context).formatMediumDate(row.expiresAt!.toLocal())}',
                                    ),
                                  if (row.resolvedAt != null)
                                    Text(
                                      '${l.groupResolved}: ${MaterialLocalizations.of(context).formatMediumDate(row.resolvedAt!.toLocal())}',
                                    ),
                                  if (row.actorId != null)
                                    ExpansionTile(
                                      // Expansion state must not reuse the
                                      // enclosing list's saved scroll offset.
                                      key: PageStorageKey((
                                        'group-issuer',
                                        widget.actor,
                                        widget.groupId,
                                        widget.family,
                                        row.id,
                                      )),
                                      title: Text(l.groupIssuer),
                                      children: [
                                        SelectableText(
                                          row.actorId!,
                                          key: PageStorageKey((
                                            'group-issuer-text',
                                            row.id,
                                          )),
                                        ),
                                      ],
                                    ),
                                  if (row.note != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(row.note!),
                                    ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: historyActions(row, l),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (pager.more && !pager.busy && pager.error == null)
                      TextButton(
                        key: const Key('group-relationships-more'),
                        onPressed: pager.load,
                        child: Text(l.groupsMore),
                      ),
                    if (!pager.more && pager.rows.isNotEmpty) Text(l.groupsEnd),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GroupPublicName extends ConsumerStatefulWidget {
  const _GroupPublicName({required this.groupId});
  final String groupId;
  @override
  ConsumerState<_GroupPublicName> createState() => _GroupPublicNameState();
}

class _GroupPublicNameState extends ConsumerState<_GroupPublicName> {
  late Future<PublicGroup?> read;
  @override
  void initState() {
    super.initState();
    read = ref.read(groupGatewayProvider).publicDetail(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder(
      future: read,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return GroupLoadError(
            error: snapshot.error,
            retry: () => setState(
              () => read = ref
                  .read(groupGatewayProvider)
                  .publicDetail(widget.groupId),
            ),
          );
        }
        return TextButton(
          onPressed: () => context.push('/groups/${widget.groupId}'),
          child: Text(snapshot.data?.content.name ?? l.groupPublicUnavailable),
        );
      },
    );
  }
}

class _RoleChoice extends ConsumerWidget {
  const _RoleChoice({required this.actor, required this.title});
  final String actor, title;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    ref.listen(authSessionProvider.select((s) => s.identity?.id), (_, next) {
      if (next != actor && context.mounted) Navigator.pop(context);
    });
    return SimpleDialog(
      title: Text(title),
      children: [
        for (final role in [
          GroupAuthority.coOrganizer,
          GroupAuthority.coCreator,
        ])
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, role),
            child: Text(groupRoleLabel(l, role)),
          ),
      ],
    );
  }
}

class _AuthorityHandoff extends ConsumerWidget {
  const _AuthorityHandoff({
    required this.actor,
    required this.groupId,
    required this.receipt,
  });
  final String actor, groupId;
  final GroupRelationshipReceipt receipt;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    ref.listen(authSessionProvider.select((s) => s.identity?.id), (_, next) {
      if (next != actor && context.mounted) Navigator.pop(context);
    });
    return AlertDialog(
      title: Text(l.groupInviteRole),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.groupSevenDays),
            if (receipt.token == null)
              Text(l.groupSecretLost)
            else
              ShareLinkButtons(
                projectId: groupId,
                prepare: () async {
                  final role = await ref
                      .read(groupRelationshipGatewayProvider)
                      .self(actor, groupId);
                  if (!context.mounted ||
                      ref.read(authSessionProvider).identity?.id != actor ||
                      !role.structural) {
                    return null;
                  }
                  // Structural context checks lifecycle/accountable identity after waits.
                  await ref
                      .read(groupGatewayProvider)
                      .structuralDetail(actor, groupId);
                  return context.mounted &&
                          ref.read(authSessionProvider).identity?.id == actor
                      ? 'https://planets.community/invite/group/${receipt.token}'
                      : null;
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.groupCancel),
        ),
      ],
    );
  }
}
