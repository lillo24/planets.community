import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_command_controller.dart';
import '../application/auth_session_controller.dart';
import '../domain/auth_models.dart';
import 'auth_failure_message.dart';

class AccountSuspensionScreen extends ConsumerWidget {
  const AccountSuspensionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final command = ref.watch(authCommandProvider);
    final checking =
        session.phase == AuthSessionPhase.checkingAccount ||
        session.phase == AuthSessionPhase.checkingProfile ||
        session.phase == AuthSessionPhase.restoring;
    return AccountSuspensionBody(
      reason: session.suspension?.userReason,
      checking: checking,
      failed: session.phase == AuthSessionPhase.accountCheckFailed,
      commandError: command.failure == null
          ? null
          : authFailureMessage(AppLocalizations.of(context), command.failure!),
      onCheck: checking || command.isBusy
          ? null
          : () {
              ref.read(authSessionProvider.notifier).refresh();
            },
      onSignOut: command.isBusy
          ? null
          : () {
              ref.read(authCommandProvider.notifier).signOut();
            },
    );
  }
}

// A pure presentation boundary keeps previews/tests free of Auth/Storage APIs.
class AccountSuspensionBody extends StatelessWidget {
  const AccountSuspensionBody({
    super.key,
    this.reason,
    this.checking = false,
    this.failed = false,
    this.commandError,
    this.onCheck,
    this.onSignOut,
  });

  final String? reason;
  final bool checking;
  final bool failed;
  final String? commandError;
  final VoidCallback? onCheck;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          reason != null ? l10n.accountSuspendedTitle : l10n.accountStatusTitle,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (checking) const CircularProgressIndicator(),
                  Text(
                    reason != null
                        ? l10n.accountSuspendedBody
                        : failed
                        ? l10n.accountStatusFailure
                        : l10n.accountStatusChecking,
                  ),
                  if (reason != null) ...[
                    const SizedBox(height: 24),
                    Text(l10n.accountSuspendedReasonLabel),
                    const SizedBox(height: 8),
                    // Render the reason as plain text only, never as markup/telemetry.
                    SelectableText(
                      reason!,
                      key: const Key('account-suspension-reason'),
                    ),
                  ],
                  if (commandError != null) Text(commandError!),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('account-status-check'),
                    onPressed: onCheck,
                    child: Text(l10n.accountStatusCheckAgain),
                  ),
                  TextButton(
                    key: const Key('account-status-sign-out'),
                    onPressed: onSignOut,
                    child: Text(l10n.authSignOutAction),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@Preview(name: 'Suspended account', group: 'Auth')
Widget accountSuspensionPreview() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const AccountSuspensionBody(reason: 'Synthetic review reason.'),
);
