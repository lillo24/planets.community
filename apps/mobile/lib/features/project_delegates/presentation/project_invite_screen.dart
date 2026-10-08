import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/project_delegate_controllers.dart';
import '../domain/project_delegate_models.dart';
import 'project_delegate_routes.dart';

class ProjectInviteScreen extends ConsumerStatefulWidget {
  const ProjectInviteScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<ProjectInviteScreen> createState() =>
      _ProjectInviteScreenState();
}

class _ProjectInviteScreenState extends ConsumerState<ProjectInviteScreen> {
  late final ProjectInviteController _controller;
  String? _loadingKey;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(projectInviteProvider.notifier);
    Future<void>.microtask(() => _load(widget.token));
  }

  @override
  void didUpdateWidget(covariant ProjectInviteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      Future<void>.microtask(() => _load(widget.token));
    }
  }

  Future<void> _load(String token) async {
    final identityId = ref.read(authSessionProvider).identity?.id;
    final key = '$token\u0000${identityId ?? ''}';
    if (_loadingKey == key) return;
    _loadingKey = key;
    try {
      await _controller.load(token);
    } finally {
      if (_loadingKey == key) _loadingKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider);
    final identityId = session.identity?.id;
    final state = ref.watch(projectInviteProvider);
    final current = state.isFor(widget.token, identityId);
    if (!current && state.phase != ProjectDelegateLoadPhase.loading) {
      Future<void>.microtask(() => _load(widget.token));
    }
    final requestedRole = current
        ? state.preview?.requestedAuthorityRole
        : null;
    final title = requestedRole == null
        ? l10n.projectInviteTitle
        : l10n.projectInviteRoleTitle(_roleLabel(l10n, requestedRole));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: !current || state.phase == ProjectDelegateLoadPhase.loading
            ? LoadingState(message: l10n.participationLoading)
            : _content(context, session, state),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AuthSessionState session,
    ProjectInviteState state,
  ) {
    final l10n = AppLocalizations.of(context);
    final preview = state.preview;
    if (state.phase == ProjectDelegateLoadPhase.failure ||
        preview?.isAvailable != true ||
        preview?.projectId == null ||
        preview?.projectKind == null) {
      return _UnavailableInvite(onRetry: () => _load(widget.token));
    }
    final roleLabel = _roleLabel(
      l10n,
      preview!.requestedAuthorityRole ??
          ProjectDelegatedAuthorityRole.coOrganizer,
    );
    final issuerDisplayName =
        preview.issuerDisplayName ?? preview.ownerDisplayName;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.large),
      children: [
        Icon(
          Icons.supervisor_account_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.medium),
        Text(
          issuerDisplayName == null
              ? l10n.projectInviteFromGenericRole(roleLabel)
              : l10n.projectInviteFromActor(issuerDisplayName, roleLabel),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          preview.projectTitle!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (preview.expiresAt case final expiresAt?) ...[
          const SizedBox(height: AppSpacing.small),
          Text(
            l10n.projectInviteExpires(
              DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
                  .add_jm()
                  .format(expiresAt.toLocal()),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.small),
        Text(
          l10n.projectDelegateCapacityImplication,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.large),
        if (state.failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.small),
            child: Text(
              _failureMessage(l10n, state.failure!),
              key: const Key('project-invite-accept-error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        _action(context, session, state),
      ],
    );
  }

  String _roleLabel(
    AppLocalizations l10n,
    ProjectDelegatedAuthorityRole role,
  ) => switch (role) {
    ProjectDelegatedAuthorityRole.coCreator => l10n.projectInviteCoCreatorRole,
    ProjectDelegatedAuthorityRole.coOrganizer =>
      l10n.projectInviteCoOrganizerRole,
  };

  Widget _action(
    BuildContext context,
    AuthSessionState session,
    ProjectInviteState state,
  ) {
    final l10n = AppLocalizations.of(context);
    final returnTo = ProjectDelegateRoutes.invite(widget.token);
    return switch (session.phase) {
      AuthSessionPhase.restoring ||
      AuthSessionPhase.checkingProfile ||
      AuthSessionPhase.checkingAccount ||
      AuthSessionPhase.accountCheckFailed ||
      AuthSessionPhase.suspended => const Center(
        child: CircularProgressIndicator(),
      ),
      AuthSessionPhase.restorationFailed => FilledButton(
        onPressed: () =>
            ref.read(authSessionProvider.notifier).retryRestoration(),
        child: Text(l10n.retryAction),
      ),
      AuthSessionPhase.signedOut => FilledButton(
        key: const Key('project-invite-sign-in'),
        onPressed: () => context.go(
          Uri(
            path: '/auth',
            queryParameters: {'returnTo': returnTo},
          ).toString(),
        ),
        child: Text(l10n.projectInviteSignIn),
      ),
      AuthSessionPhase.profileSetupRequired => FilledButton(
        key: const Key('project-invite-profile'),
        onPressed: () => context.go(
          Uri(
            path: '/profile/edit',
            queryParameters: {'returnTo': returnTo},
          ).toString(),
        ),
        child: Text(l10n.projectInviteCompleteProfile),
      ),
      AuthSessionPhase.ready => FilledButton(
        key: const Key('project-invite-accept'),
        onPressed: state.accepting ? null : _accept,
        child: state.accepting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.projectInviteAccept),
      ),
    };
  }

  Future<void> _accept() async {
    final profileId = ref.read(authSessionProvider).identity?.id;
    if (profileId == null) return;
    final preview = await _controller.accept(profileId);
    if (preview == null || !mounted) return;
    context.go(
      ProjectDelegateRoutes.detail(preview.projectKind!, preview.projectId!),
    );
  }

  String _failureMessage(
    AppLocalizations l10n,
    ProjectDelegateFailureKind failure,
  ) => switch (failure) {
    ProjectDelegateFailureKind.ownerSelfAccept =>
      l10n.projectInviteOwnerFailure,
    ProjectDelegateFailureKind.alreadyDelegate =>
      l10n.projectInviteAlreadyDelegateFailure,
    ProjectDelegateFailureKind.capacityConflict =>
      l10n.projectDelegateCapacityConflict,
    _ => l10n.projectInviteAcceptFailure,
  };
}

class _UnavailableInvite extends StatelessWidget {
  const _UnavailableInvite({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.projectInviteUnavailableTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              l10n.projectInviteUnavailableMessage,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.medium),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retryAction)),
            TextButton(
              onPressed: () => context.go('/'),
              child: Text(l10n.projectInviteBack),
            ),
          ],
        ),
      ),
    );
  }
}
