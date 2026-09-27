import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../../participation/presentation/participation_routes.dart';
import '../application/project_delegate_controllers.dart';
import '../domain/project_delegate_models.dart';
import 'project_delegate_routes.dart';

class ProjectManageScreen extends ConsumerStatefulWidget {
  const ProjectManageScreen({
    required this.projectId,
    required this.projectKind,
    super.key,
  });

  final String projectId;
  final ProjectKind projectKind;

  @override
  ConsumerState<ProjectManageScreen> createState() =>
      _ProjectManageScreenState();
}

class _ProjectManageScreenState extends ConsumerState<ProjectManageScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final profileId = ref.read(authSessionProvider).identity?.id;
    if (profileId == null) return;
    await ref
        .read(projectManagementRoleProvider.notifier)
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
    final state = ref.watch(projectManagementRoleProvider);
    final current =
        profileId != null &&
        state.isFor(profileId, widget.projectId, widget.projectKind);
    final role = current ? state.role : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.projectManageTitle)),
      body: SafeArea(
        child: !current || state.phase == ProjectDelegateLoadPhase.loading
            ? LoadingState(message: l10n.participationLoading)
            : state.phase == ProjectDelegateLoadPhase.failure ||
                  role == ProjectManagementRole.none ||
                  role == null
            ? ErrorState(message: l10n.projectManageUnavailable, onRetry: _load)
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  Card(
                    child: ListTile(
                      key: const Key('project-manage-participation'),
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(l10n.projectManageParticipationTitle),
                      subtitle: Text(
                        l10n.projectManageParticipationDescription,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        ParticipationRoutes.participants(
                          widget.projectKind,
                          widget.projectId,
                        ),
                      ),
                    ),
                  ),
                  if (role == ProjectManagementRole.owner) ...[
                    const SizedBox(height: AppSpacing.small),
                    Card(
                      child: ListTile(
                        key: const Key('project-manage-coorganizers'),
                        leading: const Icon(Icons.supervisor_account_outlined),
                        title: Text(l10n.projectCoorganizersTitle),
                        subtitle: Text(l10n.projectCoorganizersDescription),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          ProjectDelegateRoutes.coorganizers(
                            widget.projectKind,
                            widget.projectId,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
