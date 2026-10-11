import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../participation/domain/participation_models.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/project_workspace_controller.dart';
import '../application/project_workspace_launcher.dart';
import '../domain/project_workspace_models.dart';
import 'project_workspace_routes.dart';

Future<void> confirmAndOpenProjectWorkspace(
  BuildContext context,
  WidgetRef ref,
  ProjectWorkspace workspace,
) async {
  final expectedIdentity = ref.read(authSessionProvider).identity?.id;
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
  final profileId = ref.read(authSessionProvider).identity?.id;
  if (profileId == null || profileId != expectedIdentity) return;
  await ref
      .read(projectWorkspaceProvider.notifier)
      .load(expectedProfileId: profileId, projectId: workspace.projectId);
  if (!context.mounted ||
      ref.read(authSessionProvider).identity?.id != profileId) {
    return;
  }
  final state = ref.read(projectWorkspaceProvider);
  if (state.phase != ProjectWorkspacePhase.ready ||
      !state.isFor(profileId, workspace.projectId) ||
      !state.links.any(
        (link) =>
            link.id == workspace.id && link.url.value == workspace.url.value,
      )) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.projectWorkspaceUnavailable)));
    return;
  }
  final opened = await ref
      .read(projectWorkspaceLauncherProvider)
      .open(workspace.url);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.projectWorkspaceOpenFailure)));
  }
}

class ProjectWorkspaceManageCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              onPressed: () => context.push(
                ProjectWorkspaceRoutes.manage(projectKind, projectId),
              ),
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
  Widget build(BuildContext context) => Column(
    key: const Key('project-workspace-info-section'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        AppLocalizations.of(context).projectWorkspaceTitle,
        style: Theme.of(context).textTheme.titleLarge,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.links.isEmpty) Text(l10n.projectWorkspaceNotConfigured),
        for (final link in state.links)
          Padding(
            key: ValueKey('workspace-link-${link.id}'),
            padding: const EdgeInsets.only(bottom: AppSpacing.small),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
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
                if (isManager)
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
                        onPressed: state.mutating
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
        if (isManager)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('project-workspace-add'),
              onPressed: state.mutating
                  ? null
                  : () => _edit(context, ref, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.projectWorkspaceAddWorkspaceAction),
            ),
          ),
        if (state.mutating) const LinearProgressIndicator(),
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
      builder: (_) => _WorkspaceLinkEditor(
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.projectWorkspaceRemoveTitle),
        content: Text(l10n.projectWorkspaceRemoveNamedMessage(link.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.projectWorkspaceCancelAction),
          ),
          FilledButton(
            key: const Key('project-workspace-confirm-remove'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.projectWorkspaceRemoveAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final removed = await ref
        .read(projectWorkspaceProvider.notifier)
        .removeLink(
          expectedManagerProfileId: expectedProfileId,
          projectId: projectId,
          linkId: link.id,
        );
    if (!context.mounted ||
        ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? l10n.projectWorkspaceRemoved
              : l10n.projectWorkspaceUnavailable,
        ),
      ),
    );
  }
}

class _WorkspaceLinkEditor extends ConsumerStatefulWidget {
  const _WorkspaceLinkEditor({
    required this.profileId,
    required this.projectId,
    this.link,
  });
  final String profileId;
  final String projectId;
  final ProjectWorkspace? link;
  @override
  ConsumerState<_WorkspaceLinkEditor> createState() =>
      _WorkspaceLinkEditorState();
}

class _WorkspaceLinkEditorState extends ConsumerState<_WorkspaceLinkEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.link?.name ?? '');
  late final _url = TextEditingController(text: widget.link?.url.value ?? '');
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(projectWorkspaceProvider);
    final authorized =
        ref.watch(authSessionProvider).identity?.id == widget.profileId &&
        state.isFor(widget.profileId, widget.projectId) &&
        state.phase == ProjectWorkspacePhase.ready;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          widget.link == null
              ? l10n.projectWorkspaceAddWorkspaceAction
              : l10n.projectWorkspaceEditWorkspaceAction,
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!authorized)
                  Text(l10n.projectWorkspaceUnavailable)
                else ...[
                  TextFormField(
                    key: const Key('project-workspace-name-field'),
                    controller: _name,
                    enabled: !_saving,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: l10n.projectWorkspaceNameLabel,
                    ),
                    validator: (input) {
                      try {
                        validateProjectWorkspaceName(input ?? '');
                        return null;
                      } on ProjectWorkspaceNameException {
                        return l10n.projectWorkspaceNameInvalid;
                      }
                    },
                  ),
                  TextFormField(
                    key: const Key('project-workspace-url-field'),
                    controller: _url,
                    enabled: !_saving,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    maxLength: ProjectWorkspaceUrl.maxLength,
                    decoration: InputDecoration(
                      labelText: l10n.projectWorkspaceUrlLabel,
                      hintText: l10n.projectWorkspaceUrlHint,
                    ),
                    validator: (input) {
                      try {
                        ProjectWorkspaceUrl.parse(input ?? '');
                        return null;
                      } on ProjectWorkspaceUrlException catch (error) {
                        return switch (error.failure) {
                          ProjectWorkspaceUrlFailure.empty =>
                            l10n.projectWorkspaceUrlRequired,
                          ProjectWorkspaceUrlFailure.tooLong =>
                            l10n.projectWorkspaceUrlTooLong(
                              ProjectWorkspaceUrl.maxLength,
                            ),
                          ProjectWorkspaceUrlFailure.notHttps =>
                            l10n.projectWorkspaceUrlHttpsRequired,
                          ProjectWorkspaceUrlFailure.invalid =>
                            l10n.projectWorkspaceUrlInvalid,
                        };
                      }
                    },
                  ),
                ],
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.projectWorkspaceCancelAction),
          ),
          FilledButton(
            key: const Key('project-workspace-save'),
            onPressed: !authorized || _saving ? null : _save,
            child: Text(l10n.projectWorkspaceSaveAction),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await ref
        .read(projectWorkspaceProvider.notifier)
        .saveLink(
          expectedManagerProfileId: widget.profileId,
          projectId: widget.projectId,
          name: _name.text,
          input: _url.text,
          linkId: widget.link?.id,
        );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _saving = false;
    });
    if (ref.read(authSessionProvider).identity?.id != widget.profileId) {
      Navigator.pop(context);
      return;
    }
    if (saved) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.projectWorkspaceSaved)));
    } else {
      setState(() {
        _error = l10n.projectWorkspaceUnavailable;
      });
    }
  }
}
