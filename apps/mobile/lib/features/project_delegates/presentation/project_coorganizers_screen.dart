import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../application/project_delegate_controllers.dart';
import '../application/project_invite_sharing.dart';
import '../domain/project_delegate_models.dart';

class ProjectTeamScreen extends ConsumerStatefulWidget {
  const ProjectTeamScreen({
    required this.projectId,
    required this.projectKind,
    super.key,
  });

  final String projectId;
  final ProjectKind projectKind;

  @override
  ConsumerState<ProjectTeamScreen> createState() => _ProjectTeamScreenState();
}

class _ProjectTeamScreenState extends ConsumerState<ProjectTeamScreen> {
  var _inviteRole = ProjectDelegatedAuthorityRole.coOrganizer;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final profileId = ref.read(authSessionProvider).identity?.id;
    if (profileId == null) return;
    await ref
        .read(projectTeamProvider.notifier)
        .load(
          expectedProfileId: profileId,
          projectId: widget.projectId,
          projectKind: widget.projectKind,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.watch(authSessionProvider).identity?.id;
    final state = ref.watch(projectTeamProvider);
    final current =
        profileId != null &&
        state.isFor(profileId, widget.projectId, widget.projectKind);
    final authorized = state.actorRole?.hasStructuralAuthority == true;

    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.projectCoorganizersTitle)),
      body: SafeArea(
        child:
            !current ||
                (state.phase == ProjectDelegateLoadPhase.loading &&
                    state.actorRole == null)
            ? LoadingState(message: l10n.participationLoading)
            : !authorized
            ? ErrorState(message: l10n.projectDelegateSafeError, onRetry: _load)
            : state.phase == ProjectDelegateLoadPhase.failure &&
                  state.delegates.isEmpty &&
                  state.invitations.isEmpty
            ? ErrorState(message: l10n.projectDelegateSafeError, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  children: [
                    Text(
                      l10n.organizationInviteOrganizer,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    RadioGroup<ProjectDelegatedAuthorityRole>(
                      groupValue: _inviteRole,
                      onChanged: (role) {
                        if (!state.mutating && role != null) {
                          setState(() => _inviteRole = role);
                        }
                      },
                      child: Column(
                        children: [
                          RadioListTile<ProjectDelegatedAuthorityRole>(
                            contentPadding: EdgeInsets.zero,
                            enabled: !state.mutating,
                            value: ProjectDelegatedAuthorityRole.coOrganizer,
                            title: Text(
                              l10n.projectInviteCoOrganizerRole,
                              key: const Key('project-team-role-co-organizer'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          RadioListTile<ProjectDelegatedAuthorityRole>(
                            contentPadding: EdgeInsets.zero,
                            enabled: !state.mutating,
                            value: ProjectDelegatedAuthorityRole.coCreator,
                            title: Text(
                              l10n.projectInviteCoCreatorRole,
                              key: const Key('project-team-role-co-creator'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xSmall),
                    Text(
                      _inviteRole == ProjectDelegatedAuthorityRole.coCreator
                          ? l10n.projectDelegateCoCreatorDescription
                          : l10n.projectDelegateCoOrganizerDescription,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    FilledButton.icon(
                      key: const Key('project-delegate-create'),
                      onPressed: state.mutating ? null : _createInvitation,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: Text(l10n.projectDelegateInviteAction),
                    ),
                    if (state.failure != null) ...[
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        state.failure ==
                                ProjectDelegateFailureKind.capacityConflict
                            ? l10n.projectDelegateCapacityConflict
                            : l10n.projectDelegateSafeError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (state.delegates.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.large),
                      Text(
                        l10n.organizationTeamRoles,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      for (final delegate in state.delegates)
                        _delegateCard(
                          context,
                          delegate,
                          isCurrentUser: delegate.profileId == profileId,
                          mutating: state.mutating,
                        ),
                    ],
                    if (state.invitations.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.large),
                      Text(
                        l10n.projectDelegatePendingTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      for (final invitation in state.invitations)
                        _invitationCard(
                          context,
                          invitation,
                          mutating: state.mutating,
                        ),
                    ],
                    if (state.phase == ProjectDelegateLoadPhase.loading)
                      const LinearProgressIndicator(),
                    if (state.failure != null)
                      TextButton(
                        onPressed: _load,
                        child: Text(l10n.retryAction),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _delegateCard(
    BuildContext context,
    ProjectDelegate delegate, {
    required bool isCurrentUser,
    required bool mutating,
  }) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      key: Key('project-delegate-${delegate.id}'),
      title: Text(delegate.displayName),
      trailing: PopupMenuButton<String>(
        key: Key('project-delegate-actions-${delegate.id}'),
        tooltip: l10n.peopleActions,
        enabled: !mutating,
        onSelected: (action) {
          if (action == 'details') {
            final expectedProfileId = ref
                .read(authSessionProvider)
                .identity
                ?.id;
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => Consumer(
                builder: (context, ref, _) {
                  final identity = ref.watch(authSessionProvider).identity?.id;
                  final team = ref.watch(projectTeamProvider);
                  final allowed =
                      expectedProfileId != null &&
                      identity == expectedProfileId &&
                      team.isFor(
                        expectedProfileId,
                        widget.projectId,
                        widget.projectKind,
                      ) &&
                      team.actorRole?.hasStructuralAuthority == true &&
                      team.delegates.any((person) => person.id == delegate.id);
                  if (!allowed) {
                    final route = ModalRoute.of(context);
                    Future<void>.microtask(() {
                      if (context.mounted && route?.isCurrent == true) {
                        Navigator.of(context).pop();
                      }
                    });
                    return const SizedBox.shrink();
                  }
                  return SafeArea(
                    key: const Key('project-role-details'),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.large),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              delegate.displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(_roleLabel(l10n, delegate.authorityRole)),
                            Text(
                              l10n.projectDelegateAcceptedDate(
                                _formatDate(context, delegate.delegatedAt),
                              ),
                            ),
                            Text(
                              l10n.projectDelegateAddedBy(
                                delegate.grantedByDisplayName,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          } else if (!isCurrentUser) {
            if (action == 'revoke') {
              _removeDelegate(delegate);
            } else {
              _changeRole(
                delegate,
                action == 'promote'
                    ? ProjectDelegatedAuthorityRole.coCreator
                    : ProjectDelegatedAuthorityRole.coOrganizer,
              );
            }
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'details',
            child: Text(l10n.organizationRoleDetails),
          ),
          if (!isCurrentUser) ...[
            if (delegate.authorityRole ==
                ProjectDelegatedAuthorityRole.coOrganizer)
              PopupMenuItem(
                key: Key('project-delegate-promote-${delegate.id}'),
                value: 'promote',
                child: Text(l10n.projectDelegatePromoteAction),
              )
            else
              PopupMenuItem(
                key: Key('project-delegate-demote-${delegate.id}'),
                value: 'demote',
                child: Text(l10n.projectDelegateDemoteAction),
              ),
            PopupMenuItem(
              key: Key('project-delegate-revoke-${delegate.id}'),
              value: 'revoke',
              child: Text(l10n.projectDelegateRemoveAction),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_roleLabel(l10n, delegate.authorityRole)),
          if (isCurrentUser)
            Text(
              l10n.projectDelegateCurrentUser,
              key: Key('project-delegate-self-${delegate.id}'),
            ),
        ],
      ),
    );
  }

  Widget _invitationCard(
    BuildContext context,
    ProjectDelegateInvitation invitation, {
    required bool mutating,
  }) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTileTheme.merge(
        horizontalTitleGap: AppSpacing.small,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          key: Key('project-invitation-${invitation.id}'),
          title: Text(
            _roleLabel(l10n, invitation.requestedAuthorityRole),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          subtitle: Text(
            l10n.organizationInvitationExpiry(
              DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
                  .format(invitation.expiresAt.toLocal()),
            ),
          ),
          childrenPadding: const EdgeInsets.all(AppSpacing.medium),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.projectDelegateInviteDates(
                _formatDate(context, invitation.createdAt),
                _formatDate(context, invitation.expiresAt),
              ),
            ),
            Text(l10n.projectDelegateIssuedBy(invitation.issuerDisplayName)),
            TextButton.icon(
              key: Key('project-invitation-revoke-${invitation.id}'),
              onPressed: mutating ? null : () => _revokeInvitation(invitation),
              label: Text(l10n.projectDelegateRevokeAction),
              icon: const Icon(Icons.link_off),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime value) =>
      DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
          .add_jm()
          .format(value.toLocal());

  Future<void> _createInvitation() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      _inviteRole == ProjectDelegatedAuthorityRole.coCreator
          ? l10n.projectDelegateHighPrivilegeConfirmTitle
          : l10n.projectDelegateInviteAction,
      '${_inviteRole == ProjectDelegatedAuthorityRole.coCreator ? l10n.projectDelegateHighPrivilegeConfirmMessage : l10n.projectDelegateCapacityImplication}\n\n${l10n.projectDelegateLostLinkHelp}',
      l10n.projectDelegateInviteAction,
    );
    if (!confirmed || !mounted) return;
    final expectedProfileId = ref.read(authSessionProvider).identity?.id;
    if (expectedProfileId == null) return;
    final result = await ref
        .read(projectTeamProvider.notifier)
        .createInvitation(_inviteRole);
    if (result == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InvitationResultSheet(
        result: result,
        expectedProfileId: expectedProfileId,
      ),
    );
  }

  Future<void> _changeRole(
    ProjectDelegate delegate,
    ProjectDelegatedAuthorityRole role,
  ) async {
    final l10n = AppLocalizations.of(context);
    final promotes = role == ProjectDelegatedAuthorityRole.coCreator;
    final confirmed = await _confirm(
      promotes
          ? l10n.projectDelegatePromoteConfirmTitle
          : l10n.projectDelegateDemoteConfirmTitle,
      promotes
          ? l10n.projectDelegatePromoteConfirmMessage
          : l10n.projectDelegateDemoteConfirmMessage,
      promotes
          ? l10n.projectDelegatePromoteAction
          : l10n.projectDelegateDemoteAction,
    );
    if (!confirmed || !mounted) return;
    await ref
        .read(projectTeamProvider.notifier)
        .changeDelegateRole(delegate.id, role);
  }

  Future<void> _removeDelegate(ProjectDelegate delegate) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      l10n.projectDelegateRemoveRoleConfirmTitle(
        _roleLabel(l10n, delegate.authorityRole),
      ),
      delegate.authorityRole == ProjectDelegatedAuthorityRole.coCreator
          ? l10n.projectDelegateRemoveCocreatorConfirmMessage
          : l10n.projectDelegateRemoveConfirmMessage,
      l10n.projectDelegateRemoveAction,
    );
    if (!confirmed || !mounted) return;
    await ref.read(projectTeamProvider.notifier).revokeDelegate(delegate.id);
  }

  Future<void> _revokeInvitation(ProjectDelegateInvitation invitation) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      l10n.projectDelegateRevokeConfirmTitle,
      l10n.projectDelegateRevokeConfirmMessage,
      l10n.projectDelegateRevokeAction,
    );
    if (!confirmed || !mounted) return;
    await ref
        .read(projectTeamProvider.notifier)
        .revokeInvitation(invitation.id);
  }

  Future<bool> _confirm(String title, String message, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _InvitationResultSheet extends ConsumerWidget {
  const _InvitationResultSheet({
    required this.result,
    required this.expectedProfileId,
  });

  final ProjectDelegateInvitationResult result;
  final String expectedProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final role = _roleLabel(l10n, result.requestedAuthorityRole);
    final shareText = l10n.projectDelegateShareRoleText(role, result.url);
    ref.listen(authSessionProvider.select((value) => value.identity?.id), (
      _,
      identityId,
    ) {
      if (identityId != expectedProfileId && context.mounted) {
        Navigator.of(context).pop();
      }
    });
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.projectDelegateCreatedTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(l10n.projectDelegateCreatedRole(role)),
              const SizedBox(height: AppSpacing.small),
              SelectableText(result.url, key: const Key('delegate-invite-url')),
              const SizedBox(height: AppSpacing.small),
              Text(l10n.projectDelegateCreatedSecurity),
              if (result.requestedAuthorityRole ==
                  ProjectDelegatedAuthorityRole.coCreator)
                Text(l10n.projectDelegateCoCreatorDescription),
              Text(l10n.projectDelegateLostLinkHelp),
              const SizedBox(height: AppSpacing.medium),
              Wrap(
                spacing: AppSpacing.small,
                children: [
                  OutlinedButton.icon(
                    key: const Key('delegate-invite-copy'),
                    onPressed: () async {
                      await ref
                          .read(projectInviteSharingProvider)
                          .copy(result.url);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.projectDelegateCopied)),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(l10n.projectDelegateCopyAction),
                  ),
                  Builder(
                    builder: (buttonContext) => FilledButton.icon(
                      key: const Key('delegate-invite-share'),
                      onPressed: () async {
                        final box =
                            buttonContext.findRenderObject() as RenderBox?;
                        final origin = box == null
                            ? null
                            : box.localToGlobal(Offset.zero) & box.size;
                        await ref
                            .read(projectInviteSharingProvider)
                            .share(shareText, origin: origin);
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: Text(l10n.projectDelegateShareAction),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _roleLabel(AppLocalizations l10n, ProjectDelegatedAuthorityRole role) =>
    switch (role) {
      ProjectDelegatedAuthorityRole.coCreator =>
        l10n.projectInviteCoCreatorRole,
      ProjectDelegatedAuthorityRole.coOrganizer =>
        l10n.projectInviteCoOrganizerRole,
    };
