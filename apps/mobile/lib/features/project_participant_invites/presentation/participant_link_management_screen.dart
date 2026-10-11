import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../application/participant_link_manager.dart';
import 'participant_invitation_routes.dart';
import 'participant_invite_messages.dart';
import 'share_link_buttons.dart';
import 'project_context_dialog.dart';

class ParticipantLinkManagementButton extends StatelessWidget {
  const ParticipantLinkManagementButton({
    required this.projectId,
    required this.kind,
    super.key,
  });
  final String projectId;
  final ProjectKind kind;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('participant-links-manage'),
    onPressed: () =>
        context.push(ParticipantInvitationRoutes.manage(kind, projectId)),
    icon: const Icon(Icons.link),
    label: Text(AppLocalizations.of(context).participantLinksTitle),
  );
}

class ParticipantLinkManagementScreen extends ConsumerStatefulWidget {
  const ParticipantLinkManagementScreen({
    required this.projectId,
    required this.kind,
    super.key,
  });
  final String projectId;
  final ProjectKind kind;
  @override
  ConsumerState<ParticipantLinkManagementScreen> createState() =>
      _ParticipantLinkManagementScreenState();
}

class _ParticipantLinkManagementScreenState
    extends ConsumerState<ParticipantLinkManagementScreen> {
  late final String? _account;
  bool _historyExpanded = false;
  @override
  void initState() {
    super.initState();
    _account = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant ParticipantLinkManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.kind != widget.kind) {
      Future<void>.microtask(_load);
    }
  }

  bool get _current =>
      mounted &&
      _account != null &&
      ref.read(authSessionProvider).identity?.id == _account &&
      GoRouter.of(context).state.uri.path ==
          ParticipantInvitationRoutes.manage(widget.kind, widget.projectId);
  Future<void> _load() async {
    if (_current) {
      await ref
          .read(participantLinkManagerProvider.notifier)
          .load(_account!, widget.projectId, widget.kind);
    }
  }

  Future<void> _confirm(ParticipantLinkOperation operation) async {
    if (!_current) return;
    final l10n = AppLocalizations.of(context);
    final oldState = ref.read(participantLinkManagerProvider);
    final project = widget.projectId;
    final kind = widget.kind;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ProjectContextDialog(
        account: _account,
        destination: ParticipantInvitationRoutes.manage(kind, project),
        child: AlertDialog(
          title: Text(
            operation == ParticipantLinkOperation.revoke
                ? l10n.participantLinkRevoke
                : l10n.participantLinkRegenerate,
          ),
          content: Text(
            operation == ParticipantLinkOperation.revoke
                ? l10n.participantLinkRevokeConfirm
                : l10n.participantLinkRegenerateConfirm,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.projectShareClose),
            ),
            FilledButton(
              key: const Key('participant-link-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                operation == ParticipantLinkOperation.revoke
                    ? l10n.participantLinkRevoke
                    : l10n.participantLinkRegenerate,
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true ||
        !_current ||
        widget.projectId != project ||
        widget.kind != kind) {
      return;
    }
    await ref
        .read(participantLinkManagerProvider.notifier)
        .mutate(
          _account!,
          project,
          kind,
          operation,
          displayedInvitationId: oldState.link?.id,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(authSessionProvider).identity?.id;
    final state = ref.watch(participantLinkManagerProvider);
    final belongs =
        account == _account &&
        _account != null &&
        state.isFor(_account, widget.projectId, widget.kind);
    final ready = belongs && state.ready && state.role.isManager;
    final help = IconButton(
      key: const Key('participant-link-help'),
      tooltip: l10n.organizationLinkHelp,
      icon: const Icon(Icons.help_outline),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.organizationLinkHelp),
          content: Text(l10n.participantLinkNotJoinable),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.projectShareClose),
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.participantLinksTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.large),
          children: [
            if (ready) ...[
              Text(
                state.link == null
                    ? l10n.organizationNoParticipantLink
                    : l10n.organizationReusableLink,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(l10n.organizationDirectAdmissionWarning),
              const SizedBox(height: AppSpacing.medium),
            ],
            // Preserve the disclosure boundary while its fresh canonical read
            // temporarily hides the management controls.
            Visibility(
              key: const Key('participant-management-sharing'),
              visible: ready && state.link != null,
              maintainState: true,
              child: ShareLinkButtons(
                projectId: widget.projectId,
                disabled: !ready || state.busy,
                canDisclose: () {
                  final current = ref.read(participantLinkManagerProvider);
                  return _current &&
                      current.isFor(_account!, widget.projectId, widget.kind) &&
                      current.ready &&
                      current.role.isManager &&
                      current.link != null;
                },
                prepare: () async {
                  if (!_current) return null;
                  final project = widget.projectId;
                  final kind = widget.kind;
                  final link = await ref
                      .read(participantLinkManagerProvider.notifier)
                      .forSharing(_account!, project, kind);
                  return _current &&
                          widget.projectId == project &&
                          widget.kind == kind
                      ? link?.url
                      : null;
                },
              ),
            ),
            if (belongs && state.busy) const LinearProgressIndicator(),
            if (account != _account) Text(l10n.participantInviteForbidden),
            if (belongs && state.failure != null)
              Text(
                participantInviteFailureMessage(l10n, state.failure!),
                key: const Key('participant-link-error'),
              ),
            if (ready) ...[
              if (state.joinable == false)
                Text(l10n.participantInviteUnavailable),
              if (state.previewFailure != null)
                Text(
                  participantInviteFailureMessage(l10n, state.previewFailure!),
                ),
              if (state.link == null)
                FilledButton(
                  key: const Key('participant-link-regenerate'),
                  onPressed: state.busy
                      ? null
                      : () => ref
                            .read(participantLinkManagerProvider.notifier)
                            .mutate(
                              _account,
                              widget.projectId,
                              widget.kind,
                              ParticipantLinkOperation.create,
                            ),
                  child: Text(
                    l10n.participantLinkCreate,
                    textAlign: TextAlign.center,
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  help,
                  if (state.link != null)
                    PopupMenuButton<ParticipantLinkOperation>(
                      key: const Key('participant-link-actions'),
                      tooltip: l10n.organizationLinkActions,
                      enabled: !state.busy,
                      onSelected: _confirm,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          key: const Key('participant-link-regenerate'),
                          value: ParticipantLinkOperation.regenerate,
                          child: Text(l10n.participantLinkRegenerate),
                        ),
                        PopupMenuItem(
                          key: const Key('participant-link-revoke'),
                          value: ParticipantLinkOperation.revoke,
                          child: Text(l10n.participantLinkRevoke),
                        ),
                      ],
                    ),
                ],
              ),
              if (state.history.isNotEmpty || state.hasMore)
                ExpansionTile(
                  key: const Key('participant-link-history'),
                  initiallyExpanded: _historyExpanded,
                  onExpansionChanged: (expanded) => _historyExpanded = expanded,
                  tilePadding: EdgeInsets.zero,
                  title: Text(l10n.participantLinkHistory),
                  children: [
                    for (final generation in state.history)
                      ListTile(
                        key: ValueKey(generation.id),
                        title: Text(
                          generation.reason == 'revoked'
                              ? l10n.participantLinkRevoked
                              : generation.reason == 'replaced'
                              ? l10n.participantLinkReplaced
                              : l10n.participantLinkActive,
                        ),
                        subtitle: Text(
                          DateFormat.yMMMd(
                            Localizations.localeOf(context).toLanguageTag(),
                          ).add_jm().format(generation.createdAt.toLocal()),
                        ),
                      ),
                    if (state.hasMore)
                      TextButton(
                        key: const Key('participant-link-history-more'),
                        onPressed: state.busy
                            ? null
                            : () => ref
                                  .read(participantLinkManagerProvider.notifier)
                                  .load(
                                    _account,
                                    widget.projectId,
                                    widget.kind,
                                    more: true,
                                  ),
                        child: Text(l10n.participantLinkMore),
                      ),
                  ],
                ),
            ],
            if (belongs &&
                (state.failure != null || state.previewFailure != null))
              TextButton(
                key: const Key('participant-link-retry'),
                onPressed: _current && !state.busy ? _load : null,
                child: Text(l10n.retryAction),
              ),
          ],
        ),
      ),
    );
  }
}
