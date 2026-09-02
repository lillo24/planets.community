import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_command_controller.dart';
import '../application/auth_session_controller.dart';
import '../domain/auth_models.dart';
import 'auth_failure_message.dart';

class AuthStatus extends ConsumerWidget {
  const AuthStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider);
    final command = ref.watch(authCommandProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: switch (session.phase) {
          AuthSessionPhase.restoring => _StatusBody(
            icon: const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            message: l10n.authRestoringSession,
          ),
          AuthSessionPhase.signedOut => _StatusBody(
            icon: const Icon(Icons.lock_open_outlined),
            message: l10n.authSignedOutStatus,
            action: FilledButton(
              onPressed: () => context.go('/auth'),
              child: Text(l10n.authSignInAction),
            ),
            error: command.failure == null
                ? null
                : authFailureMessage(l10n, command.failure!),
          ),
          AuthSessionPhase.checkingProfile => _StatusBody(
            icon: const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            message: l10n.authCompletingProfile,
          ),
          AuthSessionPhase.ready => _StatusBody(
            icon: const Icon(Icons.verified_user_outlined),
            message: l10n.authSignedInStatus,
            action: OutlinedButton(
              onPressed: command.isBusy
                  ? null
                  : () => ref.read(authCommandProvider.notifier).signOut(),
              child: Text(l10n.authSignOutAction),
            ),
            error: command.failure == null
                ? null
                : authFailureMessage(l10n, command.failure!),
          ),
          AuthSessionPhase.profileSetupRequired => _StatusBody(
            icon: const Icon(Icons.sync_problem_outlined),
            message: l10n.authProfileSetupFailure,
            action: FilledButton(
              onPressed: command.isBusy
                  ? null
                  : () => ref
                        .read(authCommandProvider.notifier)
                        .retryProfileSetup(),
              child: Text(l10n.retryAction),
            ),
            secondaryAction: TextButton(
              onPressed: command.isBusy
                  ? null
                  : () => ref.read(authCommandProvider.notifier).signOut(),
              child: Text(l10n.authSignOutAction),
            ),
          ),
        },
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({
    required this.icon,
    required this.message,
    this.action,
    this.secondaryAction,
    this.error,
  });

  final Widget icon;
  final String message;
  final Widget? action;
  final Widget? secondaryAction;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: AppSpacing.small),
        Text(message, textAlign: TextAlign.center),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.small),
          Text(
            error!,
            key: const Key('auth-safe-error'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: AppSpacing.medium),
          action!,
        ],
        ?secondaryAction,
      ],
    );
  }
}
