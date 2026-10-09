import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../../project_delegates/application/project_delegate_controllers.dart';
import '../../project_delegates/domain/project_delegate_models.dart';
import '../application/project_workspace_controller.dart';
import '../domain/project_workspace_models.dart';

class ProjectWorkspaceScreen extends ConsumerStatefulWidget {
  const ProjectWorkspaceScreen({
    required this.projectId,
    required this.projectKind,
    super.key,
  });

  final String projectId;
  final ProjectKind projectKind;

  @override
  ConsumerState<ProjectWorkspaceScreen> createState() =>
      _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState
    extends ConsumerState<ProjectWorkspaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _fieldInitialized = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profileId = ref.read(authSessionProvider).identity?.id;
    if (profileId == null) return;
    await Future.wait([
      ref
          .read(projectManagementRoleProvider.notifier)
          .load(
            expectedProfileId: profileId,
            projectId: widget.projectId,
            projectKind: widget.projectKind,
          ),
      ref
          .read(projectWorkspaceProvider.notifier)
          .load(expectedProfileId: profileId, projectId: widget.projectId),
    ]);
    if (!mounted) return;
    final state = ref.read(projectWorkspaceProvider);
    if (state.isFor(profileId, widget.projectId)) {
      _urlController.text = state.workspace?.url.value ?? '';
      _fieldInitialized = true;
      setState(() {});
    }
  }

  String? _validateUrl(String? input) {
    final l10n = AppLocalizations.of(context);
    try {
      ProjectWorkspaceUrl.parse(input ?? '');
      return null;
    } on ProjectWorkspaceUrlException catch (error) {
      return switch (error.failure) {
        ProjectWorkspaceUrlFailure.empty => l10n.projectWorkspaceUrlRequired,
        ProjectWorkspaceUrlFailure.tooLong => l10n.projectWorkspaceUrlTooLong(
          ProjectWorkspaceUrl.maxLength,
        ),
        ProjectWorkspaceUrlFailure.notHttps =>
          l10n.projectWorkspaceUrlHttpsRequired,
        ProjectWorkspaceUrlFailure.invalid => l10n.projectWorkspaceUrlInvalid,
      };
    }
  }

  Future<void> _save(String profileId) async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await ref
        .read(projectWorkspaceProvider.notifier)
        .setWorkspace(
          expectedManagerProfileId: profileId,
          projectId: widget.projectId,
          input: _urlController.text,
        );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? l10n.projectWorkspaceSaved
              : _failureMessage(l10n, ref.read(projectWorkspaceProvider)),
        ),
      ),
    );
    if (saved) {
      _urlController.text = ref
          .read(projectWorkspaceProvider)
          .workspace!
          .url
          .value;
    }
  }

  Future<void> _remove(String profileId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.projectWorkspaceRemoveTitle),
        content: Text(l10n.projectWorkspaceRemoveMessage),
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
    if (confirmed != true || !mounted) return;
    final removed = await ref
        .read(projectWorkspaceProvider.notifier)
        .clearWorkspace(
          expectedManagerProfileId: profileId,
          projectId: widget.projectId,
        );
    if (!mounted) return;
    if (removed) _urlController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? l10n.projectWorkspaceRemoved
              : _failureMessage(l10n, ref.read(projectWorkspaceProvider)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.watch(authSessionProvider).identity?.id;
    final roleState = ref.watch(projectManagementRoleProvider);
    final workspaceState = ref.watch(projectWorkspaceProvider);
    final roleCurrent =
        profileId != null &&
        roleState.isFor(profileId, widget.projectId, widget.projectKind);
    final workspaceCurrent =
        profileId != null && workspaceState.isFor(profileId, widget.projectId);
    final role = roleCurrent ? roleState.role : null;
    final loading =
        !roleCurrent ||
        !workspaceCurrent ||
        roleState.phase == ProjectDelegateLoadPhase.loading ||
        workspaceState.phase == ProjectWorkspacePhase.loading ||
        !_fieldInitialized;
    final unavailable =
        roleState.phase == ProjectDelegateLoadPhase.failure ||
        workspaceState.phase == ProjectWorkspacePhase.failure ||
        role == null ||
        !role.isManager;

    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(l10n.projectWorkspaceManageTitle),
      ),
      body: SafeArea(
        child: loading
            ? LoadingState(message: l10n.projectWorkspaceLoading)
            : unavailable
            ? ErrorState(
                message: l10n.projectWorkspaceUnavailable,
                onRetry: _load,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  Text(l10n.projectWorkspaceManageDescription),
                  const SizedBox(height: AppSpacing.medium),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      key: const Key('project-workspace-url-field'),
                      controller: _urlController,
                      validator: _validateUrl,
                      enabled: !workspaceState.mutating,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      maxLength: ProjectWorkspaceUrl.maxLength,
                      decoration: InputDecoration(
                        labelText: l10n.projectWorkspaceUrlLabel,
                        hintText: l10n.projectWorkspaceUrlHint,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  if (workspaceState.workspace != null) ...[
                    Text(
                      l10n.projectWorkspaceConfiguredHost(
                        workspaceState.workspace!.url.hostname,
                      ),
                      key: const Key('project-workspace-configured-host'),
                    ),
                    const SizedBox(height: AppSpacing.small),
                  ],
                  Text(
                    l10n.projectWorkspaceExternalNotice,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.large),
                  FilledButton(
                    key: const Key('project-workspace-save'),
                    onPressed: workspaceState.mutating
                        ? null
                        : () => _save(profileId),
                    child: workspaceState.mutating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.projectWorkspaceSaveAction),
                  ),
                  if (workspaceState.workspace != null) ...[
                    const SizedBox(height: AppSpacing.small),
                    OutlinedButton(
                      key: const Key('project-workspace-remove'),
                      onPressed: workspaceState.mutating
                          ? null
                          : () => _remove(profileId),
                      child: Text(l10n.projectWorkspaceRemoveAction),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

String _failureMessage(AppLocalizations l10n, ProjectWorkspaceState state) =>
    switch (state.failure) {
      ProjectWorkspaceFailureKind.invalidUrl =>
        l10n.projectWorkspaceUrlHttpsRequired,
      ProjectWorkspaceFailureKind.forbidden => l10n.projectWorkspaceForbidden,
      ProjectWorkspaceFailureKind.unavailable ||
      null => l10n.projectWorkspaceUnavailable,
    };
