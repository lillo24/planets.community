import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_command_controller.dart';
import '../application/auth_session_controller.dart';
import 'auth_failure_message.dart';

class AccountSignOutAction extends ConsumerWidget {
  const AccountSignOutAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(authSessionProvider).isAuthenticated) {
      return const SizedBox.shrink();
    }
    final command = ref.watch(authCommandProvider);
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('account-sign-out-button'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: command.isBusy
              ? null
              : () => ref.read(authCommandProvider.notifier).signOut(),
          icon: const Icon(Icons.logout),
          label: Text(l10n.authSignOutAction),
        ),
        if (command.failure case final failure?) ...[
          const SizedBox(height: AppSpacing.small),
          Text(
            authFailureMessage(l10n, failure),
            key: const Key('account-sign-out-error'),
            style: TextStyle(color: colors.error),
          ),
        ],
      ],
    );
  }
}
