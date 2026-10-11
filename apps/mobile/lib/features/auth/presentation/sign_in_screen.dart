import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_command_controller.dart';
import '../application/auth_routes.dart';
import '../application/auth_session_controller.dart';
import '../application/return_destination.dart';
import '../data/provider_auth_adapter.dart';
import '../domain/auth_models.dart';
import '../domain/provider_auth.dart';
import 'auth_failure_message.dart';
import 'auth_status.dart';
import 'google_sign_in_button.dart';
import 'request_code_screen.dart';

/// Method choice exists only with Google; OTP-only entry stays one step.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({required this.returnTo, super.key});

  final String returnTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref
        .watch(providerAuthAdapterProvider)
        .isAvailable(AuthProvider.google)) {
      return RequestCodeScreen(returnTo: returnTo);
    }
    final session = ref.watch(authSessionProvider);
    if (session.phase == AuthSessionPhase.restoring ||
        session.phase == AuthSessionPhase.restorationFailed ||
        session.phase == AuthSessionPhase.checkingProfile) {
      return const Scaffold(
        body: SafeArea(child: Center(child: AuthStatus())),
      );
    }
    final l10n = AppLocalizations.of(context);
    final command = ref.watch(authCommandProvider);
    void close() {
      ref.read(authCommandProvider.notifier).cancelFlow();
      context.go(authCancelDestination(returnTo));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Scaffold(
        appBar: pageAppBar(
          context,
          title: Text(l10n.authSignInTitle),
          closeKey: const Key('auth-close-button'),
          onClose: close,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppBreakpoints.compact,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GoogleSignInButton(
                      busy:
                          command.phase ==
                          AuthCommandPhase.signingInWithProvider,
                      onPressed: command.isBusy
                          ? null
                          : () => ref
                                .read(authCommandProvider.notifier)
                                .signInWithProvider(AuthProvider.google),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    TextButton(
                      key: const Key('auth-email-method-button'),
                      onPressed: command.isBusy
                          ? null
                          : () => context.go(
                              Uri(
                                path: AuthRoutes.email,
                                queryParameters: returnTo == '/'
                                    ? null
                                    : {'returnTo': returnTo},
                              ).toString(),
                            ),
                      child: Text(
                        l10n.authEmailMethodAction,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (command.failure case final failure?) ...[
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        authFailureMessage(l10n, failure),
                        key: const Key('auth-safe-error'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
