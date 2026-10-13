import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../participation/domain/participation_models.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../../policies/application/policy_documents.dart';
import '../../policies/presentation/policy_acceptance_screen.dart';
import '../application/project_workspace_controller.dart';
import 'project_workspace_open.dart';
import 'project_workspace_feedback.dart';
import 'project_workspace_link_editor.dart';
import '../domain/project_workspace_models.dart';
import 'project_workspace_routes.dart';

class ProjectWorkspaceManageCard extends ConsumerStatefulWidget {
  const ProjectWorkspaceManageCard({
    required this.expectedProfileId,
    required this.projectId,
    required this.projectKind,
    this.compact = false,
    super.key,
  });
  final String expectedProfileId;
  final String projectId;
  final ProjectKind projectKind;

  /// Organization hubs compose this destination into their navigation card.
  final bool compact;

  @override
  ConsumerState<ProjectWorkspaceManageCard> createState() =>
      _ProjectWorkspaceManageCardState();
}

class _ProjectWorkspaceManageCardState
    extends ConsumerState<ProjectWorkspaceManageCard> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() => ref
      .read(projectWorkspaceProvider.notifier)
      .load(
        expectedProfileId: widget.expectedProfileId,
        projectId: widget.projectId,
      );

  void _open() => context.push(
    ProjectWorkspaceRoutes.manage(widget.projectKind, widget.projectId),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(projectWorkspaceProvider);
    final current = state.isFor(widget.expectedProfileId, widget.projectId);
    final loading = !current || state.phase == ProjectWorkspacePhase.loading;
    final failed = current && state.phase == ProjectWorkspacePhase.failure;
    if (widget.compact) {
      return ListTile(
        key: const Key('project-manage-workspace'),
        minLeadingWidth: 24,
        horizontalTitleGap: 8,
        leading: const Icon(Icons.folder_shared_outlined),
        title: Text(l10n.projectWorkspaceTitle),
        subtitle: failed
            ? Text(l10n.projectWorkspaceUnavailable)
            : current && state.links.length == 1
            ? Text(state.links.single.url.hostname)
            : null,
        trailing: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : failed
            ? IconButton(
                tooltip: l10n.retryAction,
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              )
            : const Icon(Icons.chevron_right),
        // The collection owns empty/loading/error recovery as well as editing.
        onTap: _open,
      );
    }
    return Card(
      key: const Key('project-manage-workspace'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_shared_outlined),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Text(
                    l10n.projectWorkspaceTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(l10n.projectWorkspaceManageDescription),
            TextButton.icon(
              key: const Key('project-manage-workspace-edit'),
              onPressed: _open,
              icon: const Icon(Icons.folder_shared_outlined),
              label: Text(l10n.projectWorkspaceOpenWorkspaceAction),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectWorkspaceInfoSection extends ConsumerStatefulWidget {
  const ProjectWorkspaceInfoSection({
    required this.expectedProfileId,
    required this.projectId,
    required this.projectKind,
    required this.isManager,
    this.compact = false,
    super.key,
  });
  final String expectedProfileId;
  final String projectId;
  final ProjectKind projectKind;
  final bool isManager;

  /// Opt-in organization layout; collection behavior stays shared.
  final bool compact;
  @override
  ConsumerState<ProjectWorkspaceInfoSection> createState() =>
      _ProjectWorkspaceInfoSectionState();
}

class _ProjectWorkspaceInfoSectionState
    extends ConsumerState<ProjectWorkspaceInfoSection> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() => ref
      .read(projectWorkspaceProvider.notifier)
      .load(
        expectedProfileId: widget.expectedProfileId,
        projectId: widget.projectId,
      );
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectWorkspaceProvider);
    if (widget.compact &&
        state.isFor(widget.expectedProfileId, widget.projectId) &&
        state.phase == ProjectWorkspacePhase.ready &&
        state.links.isEmpty &&
        !widget.isManager) {
      return const SizedBox.shrink();
    }
    return Column(
      key: const Key('project-workspace-info-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.compact) const SizedBox(height: AppSpacing.large),
        Text(
          AppLocalizations.of(context).projectWorkspaceTitle,
          style: widget.compact
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.small),
        ProjectWorkspaceCollection(
          expectedProfileId: widget.expectedProfileId,
          projectId: widget.projectId,
          isManager: widget.isManager,
          onRetry: _load,
        ),
      ],
    );
  }
}

class ProjectWorkspaceChatControl extends StatelessWidget {
  const ProjectWorkspaceChatControl({
    required this.expectedProfileId,
    required this.projectId,
    required this.projectKind,
    required this.isManager,
    super.key,
  });
  final String expectedProfileId;
  final String projectId;
  final ProjectKind projectKind;
  final bool isManager;
  @override
  Widget build(BuildContext context) => ActionChip(
    key: const Key('project-workspace-chat-control'),
    avatar: const Icon(Icons.folder_shared_outlined, size: 18),
    label: Text(AppLocalizations.of(context).projectWorkspaceShortTitle),
    onPressed: () =>
        context.push(ProjectWorkspaceRoutes.manage(projectKind, projectId)),
  );
}

IconData projectWorkspaceIcon(ProjectWorkspace link) =>
    switch (classifyProjectWorkspace(link.name, link.url.uri)) {
      ProjectWorkspaceIconType.document => Icons.description_outlined,
      ProjectWorkspaceIconType.spreadsheet => Icons.table_chart_outlined,
      ProjectWorkspaceIconType.video => Icons.videocam_outlined,
      ProjectWorkspaceIconType.drive => Icons.folder_shared_outlined,
      ProjectWorkspaceIconType.link => Icons.link,
    };

// The same private collection serves the existing route and Group info.
class ProjectWorkspaceCollection extends ConsumerWidget {
  const ProjectWorkspaceCollection({
    required this.expectedProfileId,
    required this.projectId,
    required this.isManager,
    required this.onRetry,
    super.key,
  });
  final String expectedProfileId;
  final String projectId;
  final bool isManager;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(projectWorkspaceProvider);
    final policyAllows = ref
        .watch(policyAcceptanceProvider)
        .allows(expectedProfileId, ref.watch(policyVersionProvider));
    if (ref.watch(authSessionProvider).identity?.id != expectedProfileId) {
      return const SizedBox.shrink();
    }
    if (!state.isFor(expectedProfileId, projectId) ||
        state.phase == ProjectWorkspacePhase.loading ||
        state.phase == ProjectWorkspacePhase.idle) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.phase == ProjectWorkspacePhase.failure) {
      return Column(
        children: [
          Text(
            state.failure == ProjectWorkspaceFailureKind.forbidden
                ? l10n.projectWorkspaceForbidden
                : l10n.projectWorkspaceUnavailable,
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.retryAction)),
        ],
      );
    }
    final canWrite = isManager && state.canManage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canWrite && !policyAllows) ...[
          Text(l10n.projectWorkspacePolicyRequired),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('project-workspace-collection-policy'),
              onPressed: () async {
                if (ModalRoute.of(context)?.isCurrent != true) return;
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const PolicyAcceptanceScreen(
                      returnToPreviousPage: true,
                    ),
                  ),
                );
              },
              child: Text(l10n.projectWorkspaceReviewPolicy),
            ),
          ),
        ],
        if (canWrite && state.pendingAdd != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(l10n.projectWorkspaceRecoveryNotice),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('project-workspace-check-add'),
              onPressed: state.mutating ? null : () => _check(context, ref),
              child: Text(l10n.projectWorkspaceCheckAdd),
            ),
          ),
        ],
        if (state.failure != null && state.pendingAdd == null)
          Semantics(
            liveRegion: true,
            child: Text(projectWorkspaceFailureMessage(l10n, state.failure)),
          ),
        if (state.links.isEmpty && state.nextCursor == null)
          Text(l10n.projectWorkspaceNotConfigured),
        for (final link in state.links)
          Padding(
            key: ValueKey('workspace-link-${link.id}'),
            padding: const EdgeInsets.only(bottom: AppSpacing.small),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  key: ValueKey('workspace-open-${link.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(projectWorkspaceIcon(link)),
                  title: Text(link.name),
                  subtitle: Text(link.url.hostname),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: state.mutating
                      ? null
                      : () =>
                            confirmAndOpenProjectWorkspace(context, ref, link),
                ),
                if (canWrite)
                  Wrap(
                    spacing: AppSpacing.small,
                    children: [
                      TextButton.icon(
                        key: ValueKey('workspace-edit-${link.id}'),
                        onPressed: state.mutating
                            ? null
                            : () => _edit(context, ref, link),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.projectWorkspaceEditWorkspaceAction),
                      ),
                      TextButton.icon(
                        key: ValueKey('workspace-remove-${link.id}'),
                        onPressed: state.mutating || !policyAllows
                            ? null
                            : () => _remove(context, ref, link),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l10n.projectWorkspaceRemoveAction),
                      ),
                    ],
                  ),
                const Divider(),
              ],
            ),
          ),
        if (canWrite)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('project-workspace-add'),
              onPressed: state.mutating
                  ? null
                  : () => _edit(context, ref, null),
              icon: const Icon(Icons.add),
              label: Text(
                state.pendingAdd == null
                    ? l10n.projectWorkspaceAddWorkspaceAction
                    : l10n.projectWorkspaceResumeAdd,
              ),
            ),
          ),
        if (state.nextCursor != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('project-workspace-load-more'),
              onPressed: state.mutating || state.loadingMore
                  ? null
                  : () =>
                        ref.read(projectWorkspaceProvider.notifier).loadMore(),
              child: Text(
                state.pageFailure == null
                    ? l10n.projectWorkspaceLoadMore
                    : l10n.projectWorkspaceRetryPage,
              ),
            ),
          ),
        if (state.pageFailure != null)
          Semantics(
            liveRegion: true,
            child: Text(
              projectWorkspaceFailureMessage(l10n, state.pageFailure),
            ),
          ),
        if (state.mutating || state.loadingMore)
          const LinearProgressIndicator(),
        const SizedBox(height: AppSpacing.small),
        Text(
          l10n.projectWorkspaceExternalNotice,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ProjectWorkspace? link,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProjectWorkspaceLinkEditor(
        profileId: expectedProfileId,
        projectId: projectId,
        link: link,
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    ProjectWorkspace link,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(projectWorkspaceProvider.notifier);
    final beforeConfirmation = controller.epoch;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, dialogRef, _) {
          final session = dialogRef.watch(authSessionProvider);
          dialogRef.watch(projectWorkspaceProvider);
          final valid =
              session.identity?.id == expectedProfileId &&
              session.phase == AuthSessionPhase.ready &&
              controller.epoch == beforeConfirmation;
          return AlertDialog(
            title: Text(l10n.projectWorkspaceRemoveTitle),
            content: Text(
              valid
                  ? l10n.projectWorkspaceRemoveNamedMessage(link.name)
                  : l10n.projectWorkspaceUnavailable,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.projectWorkspaceCancelAction),
              ),
              if (valid)
                FilledButton(
                  key: const Key('project-workspace-confirm-remove'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.projectWorkspaceRemoveAction),
                ),
            ],
          );
        },
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        controller.epoch != beforeConfirmation ||
        ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      return;
    }
    final operation = controller.removeLink(
      expectedManagerProfileId: expectedProfileId,
      projectId: projectId,
      linkId: link.id,
      expectedVersion: link.version,
    );
    final operationEpoch = controller.epoch;
    final removed = await operation;
    if (!context.mounted ||
        ref.read(authSessionProvider).identity?.id != expectedProfileId ||
        controller.epoch != operationEpoch) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? l10n.projectWorkspaceRemoved
              : projectWorkspaceFailureMessage(
                  l10n,
                  ref.read(projectWorkspaceProvider).failure,
                ),
        ),
      ),
    );
  }

  Future<void> _check(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(projectWorkspaceProvider.notifier);
    final operation = controller.reconcilePendingAdd(
      expectedManagerProfileId: expectedProfileId,
      projectId: projectId,
    );
    final epoch = controller.epoch;
    final confirmed = await operation;
    if (!context.mounted ||
        controller.epoch != epoch ||
        ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final state = ref.read(projectWorkspaceProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          confirmed
              ? l10n.projectWorkspaceSaved
              : state.pendingAdd != null
              ? l10n.projectWorkspaceReconciliationFailed
              : projectWorkspaceFailureMessage(l10n, state.failure),
        ),
      ),
    );
  }
}
