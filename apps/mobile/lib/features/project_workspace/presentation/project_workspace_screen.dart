import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../../project_delegates/application/project_delegate_controllers.dart';
import '../../project_delegates/domain/project_delegate_models.dart';
import '../application/project_workspace_controller.dart';
import 'project_workspace_widgets.dart';

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
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.watch(authSessionProvider).identity?.id;
    final role = ref.watch(projectManagementRoleProvider);
    final isManager =
        profileId != null &&
        role.isFor(profileId, widget.projectId, widget.projectKind) &&
        role.phase == ProjectDelegateLoadPhase.ready &&
        role.role?.isManager == true;
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.projectWorkspaceTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.medium),
          children: [
            if (profileId != null)
              ProjectWorkspaceCollection(
                expectedProfileId: profileId,
                projectId: widget.projectId,
                isManager: isManager,
                onRetry: _load,
              ),
            if (profileId != null &&
                role.phase == ProjectDelegateLoadPhase.failure)
              TextButton(onPressed: _load, child: Text(l10n.retryAction)),
          ],
        ),
      ),
    );
  }
}
