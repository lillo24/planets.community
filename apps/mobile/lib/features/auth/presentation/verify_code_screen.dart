import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_command_controller.dart';
import '../application/auth_session_controller.dart';
import '../domain/auth_models.dart';
import 'auth_failure_message.dart';

class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _codeController = TextEditingController();
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    await ref
        .read(authCommandProvider.notifier)
        .verifyCode(_codeController.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final command = ref.watch(authCommandProvider);
    final pending = ref.watch(pendingEmailOtpProvider);
    final session = ref.watch(authSessionProvider);
    final secondsRemaining = _secondsRemaining(command.resendAvailableAt);
    final error = command.failure;
    final needsProfileRetry =
        session.phase == AuthSessionPhase.profileSetupRequired &&
        !session.hasProfileAnchor;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authVerifyTitle)),
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
                  Icon(
                    Icons.password_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    l10n.authVerifyTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    l10n.authVerifyDescription(maskEmail(pending?.email ?? '')),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.large),
                  TextField(
                    key: const Key('auth-code-field'),
                    controller: _codeController,
                    enabled: !command.isBusy && !needsProfileRetry,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.authCodeLabel,
                      hintText: l10n.authCodeHint,
                      counterText: '',
                    ),
                    maxLength: 6,
                    onSubmitted: command.isBusy ? null : (_) => _verify(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      authFailureMessage(l10n, error),
                      key: const Key('auth-safe-error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.large),
                  FilledButton(
                    key: const Key('auth-verify-button'),
                    onPressed: command.isBusy
                        ? null
                        : needsProfileRetry
                        ? () => ref
                              .read(authCommandProvider.notifier)
                              .retryProfileSetup()
                        : _verify,
                    child: command.isBusy
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Text(
                            needsProfileRetry
                                ? l10n.retryAction
                                : l10n.authVerifyAction,
                          ),
                  ),
                  if (!needsProfileRetry) ...[
                    const SizedBox(height: AppSpacing.small),
                    TextButton(
                      key: const Key('auth-resend-button'),
                      onPressed: command.isBusy || secondsRemaining > 0
                          ? null
                          : () => ref
                                .read(authCommandProvider.notifier)
                                .resendCode(),
                      child: Text(
                        secondsRemaining > 0
                            ? l10n.authResendCountdown(secondsRemaining)
                            : l10n.authResendAction,
                      ),
                    ),
                    TextButton(
                      onPressed: command.isBusy
                          ? null
                          : () {
                              ref
                                  .read(authCommandProvider.notifier)
                                  .resetFlow();
                              context.go('/auth');
                            },
                      child: Text(l10n.authUseDifferentEmailAction),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _secondsRemaining(DateTime? availableAt) {
    if (availableAt == null) {
      return 0;
    }
    final milliseconds = availableAt.difference(DateTime.now()).inMilliseconds;
    if (milliseconds <= 0) {
      return 0;
    }
    return (milliseconds / Duration.millisecondsPerSecond).ceil();
  }
}

String maskEmail(String email) {
  final separator = email.indexOf('@');
  if (separator <= 0 || separator == email.length - 1) {
    return '•••';
  }
  final local = email.substring(0, separator);
  final visible = local.substring(0, 1);
  return '$visible•••${email.substring(separator)}';
}
