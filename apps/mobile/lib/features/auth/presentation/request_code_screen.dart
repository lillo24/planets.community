import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_command_controller.dart';
import 'auth_failure_message.dart';

class RequestCodeScreen extends ConsumerStatefulWidget {
  const RequestCodeScreen({required this.returnTo, super.key});

  final String returnTo;

  @override
  ConsumerState<RequestCodeScreen> createState() => _RequestCodeScreenState();
}

class _RequestCodeScreenState extends ConsumerState<RequestCodeScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final sent = await ref
        .read(authCommandProvider.notifier)
        .requestCode(email: _emailController.text, returnTo: widget.returnTo);
    if (sent && mounted) {
      final location = Uri(
        path: '/auth/verify',
        queryParameters: widget.returnTo == '/'
            ? null
            : {'returnTo': widget.returnTo},
      );
      context.go(location.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final command = ref.watch(authCommandProvider);
    final error = command.failure;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authRequestTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.compact,
              ),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.mark_email_unread_outlined,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        l10n.authRequestTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        l10n.authRequestDescription,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.large),
                      TextFormField(
                        key: const Key('auth-email-field'),
                        controller: _emailController,
                        enabled: !command.isBusy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: l10n.authEmailLabel,
                          hintText: l10n.authEmailHint,
                        ),
                        validator: (value) {
                          final candidate = value?.trim() ?? '';
                          if (!candidate.contains('@') ||
                              candidate.length > 254) {
                            return l10n.authInvalidEmail;
                          }
                          return null;
                        },
                        onFieldSubmitted: command.isBusy
                            ? null
                            : (_) => _requestCode(),
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
                        key: const Key('auth-request-button'),
                        onPressed: command.isBusy ? null : _requestCode,
                        child: command.isBusy
                            ? SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
                                ),
                              )
                            : Text(l10n.authSendCodeAction),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        l10n.authPrivacyNote,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
