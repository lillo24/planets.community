import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../participation/domain/participation_models.dart';
import '../application/project_workspace_controller.dart';
import '../application/project_workspace_launcher.dart';
import '../domain/project_workspace_models.dart';
import 'project_workspace_routes.dart';

Future<void> confirmAndOpenProjectWorkspace(
  BuildContext context,
  WidgetRef ref,
  ProjectWorkspace workspace,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.projectWorkspaceOpenTitle),
      content: Text(
        l10n.projectWorkspaceOpenMessage(workspace.url.hostname),
        key: const Key('project-workspace-confirm-host'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.projectWorkspaceCancelAction),
        ),
        FilledButton(
          key: const Key('project-workspace-confirm-open'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.projectWorkspaceOpenAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final opened = await ref
      .read(projectWorkspaceLauncherProvider)
      .open(workspace.url);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.projectWorkspaceOpenFailure)));
  }
}

class ProjectWorkspaceManageCard extends ConsumerStatefulWidget {
  const ProjectWorkspaceManageCard({
    required this.expectedProfileId,
    required this.projectId,
    required this.projectKind,
    super.key,
  });

  final String expectedProfileId;
  final String projectId;
  final ProjectKind projectKind;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(projectWorkspaceProvider);
    final current = state.isFor(widget.expectedProfileId, widget.projectId);
    final workspace = current ? state.workspace : null;
    final loading = !current || state.phase == ProjectWorkspacePhase.loading;
    final failed = current && state.phase == ProjectWorkspacePhase.failure;
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
                if (loading)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              failed
                  ? l10n.projectWorkspaceUnavailable
                  : workspace == null
                  ? l10n.projectWorkspaceManageEmptyDescription
                  : workspace.url.hostname,
            ),
            if (!loading) ...[
              const SizedBox(height: AppSpacing.small),
              if (failed)
                TextButton(
                  key: const Key('project-manage-workspace-retry'),
                  onPressed: _load,
                  child: Text(l10n.retryAction),
                )
              else
                Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: AppSpacing.xSmall,
                  children: [
                    if (workspace != null)
                      OutlinedButton.icon(
                        key: const Key('project-manage-workspace-open'),
                        onPressed: () => confirmAndOpenProjectWorkspace(
                          context,
                          ref,
                          workspace,
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(l10n.projectWorkspaceOpenWorkspaceAction),
                      ),
                    TextButton.icon(
                      key: const Key('project-manage-workspace-edit'),
                      onPressed: () => context.push(
                        ProjectWorkspaceRoutes.manage(
                          widget.projectKind,
                          widget.projectId,
                        ),
                      ),
                      icon: Icon(workspace == null ? Icons.add : Icons.edit),
                      label: Text(
                        workspace == null
                            ? l10n.projectWorkspaceAddWorkspaceAction
                            : l10n.projectWorkspaceEditWorkspaceAction,
                      ),
                    ),
                  ],
                ),
            ],
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
    super.key,
  });

  final String expectedProfileId;
  final String projectId;
  final ProjectKind projectKind;
  final bool isManager;

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
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(projectWorkspaceProvider);
    final current = state.isFor(widget.expectedProfileId, widget.projectId);
    final workspace = current ? state.workspace : null;
    return Column(
      key: const Key('project-workspace-info-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.projectWorkspaceTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.small),
        if (!current || state.phase == ProjectWorkspacePhase.loading)
          const Center(child: CircularProgressIndicator())
        else if (state.phase == ProjectWorkspacePhase.failure)
          Row(
            children: [
              Expanded(child: Text(l10n.projectWorkspaceUnavailable)),
              TextButton(onPressed: _load, child: Text(l10n.retryAction)),
            ],
          )
        else if (workspace == null)
          Row(
            children: [
              Expanded(child: Text(l10n.projectWorkspaceNotConfigured)),
              if (widget.isManager)
                TextButton(
                  key: const Key('project-workspace-info-add'),
                  onPressed: () => context.push(
                    ProjectWorkspaceRoutes.manage(
                      widget.projectKind,
                      widget.projectId,
                    ),
                  ),
                  child: Text(l10n.projectWorkspaceAddWorkspaceAction),
                ),
            ],
          )
        else
          ListTile(
            key: const Key('project-workspace-info-open'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_shared_outlined),
            title: Text(workspace.url.hostname),
            subtitle: Text(l10n.projectWorkspaceExternalNotice),
            trailing: widget.isManager
                ? TextButton(
                    key: const Key('project-workspace-info-edit'),
                    onPressed: () => context.push(
                      ProjectWorkspaceRoutes.manage(
                        widget.projectKind,
                        widget.projectId,
                      ),
                    ),
                    child: Text(l10n.projectWorkspaceEditWorkspaceAction),
                  )
                : const Icon(Icons.open_in_new),
            onTap: () =>
                confirmAndOpenProjectWorkspace(context, ref, workspace),
          ),
      ],
    );
  }
}

class ProjectWorkspaceChatControl extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(projectWorkspaceProvider);
    final current = state.isFor(expectedProfileId, projectId);
    final workspace = current ? state.workspace : null;
    if (!current || state.phase == ProjectWorkspacePhase.loading) {
      return const SizedBox.square(
        dimension: 32,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.small),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (workspace == null && !isManager) return const SizedBox.shrink();
    return ActionChip(
      key: const Key('project-workspace-chat-control'),
      avatar: const Icon(Icons.folder_shared_outlined, size: 18),
      label: Text(
        workspace == null
            ? l10n.projectWorkspaceAddWorkspaceAction
            : l10n.projectWorkspaceShortTitle,
      ),
      onPressed: workspace == null
          ? () => context.push(
              ProjectWorkspaceRoutes.manage(projectKind, projectId),
            )
          : () => confirmAndOpenProjectWorkspace(context, ref, workspace),
    );
  }
}
