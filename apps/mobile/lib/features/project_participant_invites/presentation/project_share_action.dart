import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../participation/domain/participation_models.dart';
import '../../project_delegates/application/project_delegate_controllers.dart';
import '../../project_delegates/data/project_delegate_gateway.dart';
import '../../project_delegates/domain/project_delegate_models.dart';
import '../../project_delegates/presentation/project_delegate_routes.dart';
import '../application/participant_link_manager.dart';
import '../domain/participant_invitation_models.dart';
import 'participant_invitation_routes.dart';
import 'participant_invite_messages.dart';
import 'share_link_buttons.dart';
import 'project_context_dialog.dart';

class ProjectShareAction extends StatelessWidget {
  const ProjectShareAction({
    required this.projectId,
    required this.kind,
    super.key,
  });
  final String projectId;
  final ProjectKind kind;
  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('project-share-action'),
    tooltip: AppLocalizations.of(context).projectShareTitle,
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => ProjectShareDialog(projectId: projectId, kind: kind),
    ),
    icon: const Icon(Icons.share_outlined),
  );
}

class ProjectShareDialog extends ConsumerStatefulWidget {
  const ProjectShareDialog({
    required this.projectId,
    required this.kind,
    super.key,
  });
  final String projectId;
  final ProjectKind kind;
  @override
  ConsumerState<ProjectShareDialog> createState() => _ProjectShareDialogState();
}

class _ProjectShareDialogState extends ConsumerState<ProjectShareDialog> {
  late final String? _account;
  bool _special = false;
  ProjectManagementRole _role = ProjectManagementRole.none;
  @override
  void initState() {
    super.initState();
    _account = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_readRole);
  }

  bool get _current =>
      mounted &&
      ref.read(authSessionProvider).accountAccessIdentityId == _account &&
      GoRouter.of(context).state.uri.path ==
          ProjectDelegateRoutes.detail(widget.kind, widget.projectId);
  Future<void> _readRole() async {
    if (_account == null ||
        !_current ||
        ref.read(authSessionProvider).phase != AuthSessionPhase.ready) {
      return;
    }
    try {
      final role = await ref
          .read(projectDelegateGatewayProvider)
          .getOwnManagementRole(
            expectedProfileId: _account,
            projectId: widget.projectId,
          );
      if (_current) setState(() => _role = role);
    } catch (_) {
      if (_current) setState(() => _role = ProjectManagementRole.none);
    }
  }

  Future<void> _select(bool special) async {
    if (!_current) return;
    setState(() => _special = special);
    if (special && _role.isManager && _account != null) {
      await ref
          .read(participantLinkManagerProvider.notifier)
          .mutate(
            _account,
            widget.projectId,
            widget.kind,
            ParticipantLinkOperation.create,
          );
    }
  }

  Future<String?> _prepare() async {
    if (!_current) return null;
    if (!_special) {
      return ParticipantInvitationRoutes.ordinaryUrl(
        widget.kind,
        widget.projectId,
      );
    }
    if (!_role.isManager || _account == null) return null;
    final link = await ref
        .read(participantLinkManagerProvider.notifier)
        .forSharing(_account, widget.projectId, widget.kind);
    return _current ? link?.url : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(authSessionProvider).identity?.id;
    final manager = ref.watch(participantLinkManagerProvider);
    final role = ref.watch(projectManagementRoleProvider);
    final lost =
        account != _account ||
        (role.expectedProfileId == _account &&
            role.projectId == widget.projectId &&
            ((role.phase == ProjectDelegateLoadPhase.ready &&
                    role.role == ProjectManagementRole.none) ||
                role.failure == ProjectDelegateFailureKind.forbidden)) ||
        (manager.isFor(_account ?? '', widget.projectId, widget.kind) &&
            manager.failure == null &&
            manager.ready &&
            !manager.role.isManager) ||
        (manager.isFor(_account ?? '', widget.projectId, widget.kind) &&
            manager.failure == ParticipantInviteFailure.forbidden);
    if (lost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }
    final busy =
        manager.isFor(_account ?? '', widget.projectId, widget.kind) &&
        manager.busy;
    return ProjectContextDialog(
      account: _account,
      destination: ProjectDelegateRoutes.detail(widget.kind, widget.projectId),
      onInvalidated: () {
        if (mounted) {
          ref
              .read(participantLinkManagerProvider.notifier)
              .discard(_account, widget.projectId);
        }
      },
      child: AlertDialog(
        title: Text(l10n.projectShareTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioGroup<bool>(
                groupValue: _special,
                onChanged: (value) {
                  if (!busy && value != null) _select(value);
                },
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      key: const Key('project-share-ordinary'),
                      value: false,
                      title: Text(l10n.projectShareOrdinary),
                    ),
                    if (_role.isManager)
                      RadioListTile<bool>(
                        key: const Key('project-share-special'),
                        value: true,
                        title: Text(l10n.projectShareSpecial),
                      ),
                  ],
                ),
              ),
              if (_special) ...[
                Text(l10n.projectShareSpecialExplanation),
                if (manager.failure case final failure?)
                  Text(
                    participantInviteFailureMessage(l10n, failure),
                    key: const Key('project-share-special-error'),
                  ),
              ],
              ShareLinkButtons(
                projectId: widget.projectId,
                canDisclose: () {
                  if (!_current) return false;
                  if (!_special) return true;
                  final current = ref.read(participantLinkManagerProvider);
                  return current.isFor(
                        _account ?? '',
                        widget.projectId,
                        widget.kind,
                      ) &&
                      current.ready &&
                      current.role.isManager &&
                      current.link != null;
                },
                disabled:
                    busy ||
                    (_special && (!manager.ready || manager.link == null)),
                prepare: _prepare,
              ),
              if (_role.isManager)
                TextButton(
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.pop(context);
                    router.push(
                      ParticipantInvitationRoutes.manage(
                        widget.kind,
                        widget.projectId,
                      ),
                    );
                  },
                  child: Text(l10n.participantLinksTitle),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.projectShareClose),
          ),
        ],
      ),
    );
  }
}
