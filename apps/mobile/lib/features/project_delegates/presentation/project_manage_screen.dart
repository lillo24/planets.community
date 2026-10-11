import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../../participation/presentation/participation_routes.dart';
import '../../project_participant_invites/presentation/participant_invitation_routes.dart';
import '../../project_workspace/presentation/project_workspace_widgets.dart';
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
  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  void _scheduleLoad() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    Future<void>.microtask(() async {
      try {
        await _load();
      } finally {
        if (mounted) _loadScheduled = false;
      }
    });
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
    if (profileId != null &&
        (state.phase == ProjectDelegateLoadPhase.idle || !current)) {
      _scheduleLoad();
    }

    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.projectManageTitle)),
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
                    child: Column(
                      children: [
                        ListTile(
                          minLeadingWidth: 24,
                          horizontalTitleGap: 8,
                          key: const Key('project-manage-participation'),
                          leading: const Icon(Icons.groups_outlined),
                          title: Text(l10n.peopleTitle),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            ParticipationRoutes.participants(
                              widget.projectKind,
                              widget.projectId,
                            ),
                          ),
                        ),
                        ListTile(
                          minLeadingWidth: 24,
                          horizontalTitleGap: 8,
                          key: const Key('participant-links-manage'),
                          leading: const Icon(Icons.link),
                          title: Text(l10n.organizationParticipantLinks),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            ParticipantInvitationRoutes.manage(
                              widget.projectKind,
                              widget.projectId,
                            ),
                          ),
                        ),
                        if (role.hasStructuralAuthority) ...[
                          ListTile(
                            minLeadingWidth: 24,
                            horizontalTitleGap: 8,
                            key: const Key('project-manage-team'),
                            leading: const Icon(
                              Icons.supervisor_account_outlined,
                            ),
                            title: Text(l10n.projectCoorganizersTitle),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              ProjectDelegateRoutes.team(
                                widget.projectKind,
                                widget.projectId,
                              ),
                            ),
                          ),
                          ListTile(
                            minLeadingWidth: 24,
                            horizontalTitleGap: 8,
                            key: const Key('project-manage-structural-edit'),
                            leading: const Icon(Icons.edit_outlined),
                            title: Text(l10n.projectManageStructuralTitle),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              ProjectDelegateRoutes.edit(
                                widget.projectKind,
                                widget.projectId,
                              ),
                            ),
                          ),
                        ],
                        ProjectWorkspaceManageCard(
                          expectedProfileId: profileId,
                          projectId: widget.projectId,
                          projectKind: widget.projectKind,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
