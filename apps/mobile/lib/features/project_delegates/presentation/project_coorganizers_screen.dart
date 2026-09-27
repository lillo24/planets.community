import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../application/project_delegate_controllers.dart';
import '../application/project_invite_sharing.dart';
import '../domain/project_delegate_models.dart';

class ProjectCoorganizersScreen extends ConsumerStatefulWidget {
  const ProjectCoorganizersScreen({
    required this.projectId,
    required this.projectKind,
    super.key,
  });

  final String projectId;
  final ProjectKind projectKind;

  @override
  ConsumerState<ProjectCoorganizersScreen> createState() =>
      _ProjectCoorganizersScreenState();
}

class _ProjectCoorganizersScreenState
    extends ConsumerState<ProjectCoorganizersScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final ownerId = ref.read(authSessionProvider).identity?.id;
    if (ownerId == null) return;
    await ref
        .read(projectCoorganizersProvider.notifier)
        .load(
          expectedOwnerId: ownerId,
          projectId: widget.projectId,
          projectKind: widget.projectKind,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ownerId = ref.watch(authSessionProvider).identity?.id;
    final state = ref.watch(projectCoorganizersProvider);
    final current =
        ownerId != null &&
        state.isFor(ownerId, widget.projectId, widget.projectKind);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.projectCoorganizersTitle)),
      body: SafeArea(
        child:
            !current ||
                (state.phase == ProjectDelegateLoadPhase.loading &&
                    state.delegates.isEmpty &&
                    state.invitations.isEmpty)
            ? LoadingState(message: l10n.participationLoading)
            : state.phase == ProjectDelegateLoadPhase.failure &&
                  state.delegates.isEmpty &&
                  state.invitations.isEmpty
            ? ErrorState(message: l10n.projectDelegateSafeError, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  children: [
                    FilledButton.icon(
                      key: const Key('project-delegate-create'),
                      onPressed: state.mutating ? null : _createInvitation,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: Text(l10n.projectDelegateInviteAction),
                    ),
                    if (state.failure != null) ...[
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        l10n.projectDelegateSafeError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.large),
                    Text(
                      l10n.projectDelegateActiveTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    if (state.delegates.isEmpty)
                      Text(l10n.projectDelegateActiveEmpty)
                    else
                      for (final delegate in state.delegates)
                        Card(
                          child: ListTile(
                            key: Key('project-delegate-${delegate.id}'),
                            title: Text(delegate.displayName),
                            subtitle: Text(
                              l10n.projectDelegateAcceptedDate(
                                _formatDate(context, delegate.delegatedAt),
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: state.mutating
                                  ? null
                                  : () => _removeDelegate(delegate),
                              child: Text(l10n.projectDelegateRemoveAction),
                            ),
                          ),
                        ),
                    const SizedBox(height: AppSpacing.large),
                    Text(
                      l10n.projectDelegatePendingTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    if (state.invitations.isEmpty)
                      Text(l10n.projectDelegatePendingEmpty)
                    else
                      for (final invitation in state.invitations)
                        Card(
                          child: ListTile(
                            key: Key('project-invitation-${invitation.id}'),
                            title: Text(
                              l10n.projectDelegateInviteDates(
                                _formatDate(context, invitation.createdAt),
                                _formatDate(context, invitation.expiresAt),
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: state.mutating
                                  ? null
                                  : () => _revokeInvitation(invitation),
                              child: Text(l10n.projectDelegateRevokeAction),
                            ),
                          ),
                        ),
                    const SizedBox(height: AppSpacing.medium),
                    Text(l10n.projectDelegateLostLinkHelp),
                  ],
                ),
              ),
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime value) =>
      DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
          .add_jm()
          .format(value.toLocal());

  Future<void> _createInvitation() async {
    final expectedOwnerId = ref.read(authSessionProvider).identity?.id;
    if (expectedOwnerId == null) return;
    final result = await ref
        .read(projectCoorganizersProvider.notifier)
        .createInvitation();
    if (result == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InvitationResultSheet(
        result: result,
        expectedOwnerId: expectedOwnerId,
      ),
    );
  }

  Future<void> _removeDelegate(ProjectDelegate delegate) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      l10n.projectDelegateRemoveConfirmTitle,
      l10n.projectDelegateRemoveConfirmMessage,
      l10n.projectDelegateRemoveAction,
    );
    if (!confirmed || !mounted) return;
    await ref
        .read(projectCoorganizersProvider.notifier)
        .revokeDelegate(delegate.id);
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
        .read(projectCoorganizersProvider.notifier)
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
    required this.expectedOwnerId,
  });

  final ProjectDelegateInvitationResult result;
  final String expectedOwnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shareText = l10n.projectDelegateShareText(result.url);
    ref.listen(authSessionProvider.select((value) => value.identity?.id), (
      _,
      identityId,
    ) {
      if (identityId != expectedOwnerId && context.mounted) {
        Navigator.of(context).pop();
      }
    });
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.projectDelegateCreatedTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.small),
            SelectableText(result.url, key: const Key('delegate-invite-url')),
            const SizedBox(height: AppSpacing.small),
            Text(l10n.projectDelegateCreatedSecurity),
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
    );
  }
}
