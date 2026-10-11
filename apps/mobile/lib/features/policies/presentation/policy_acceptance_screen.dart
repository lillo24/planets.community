import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/presentation/account_sign_out_action.dart';
import '../../help/presentation/help_screen.dart';
import '../application/policy_acceptance_controller.dart';
import '../application/policy_documents.dart';
import 'policy_link_action.dart';

class PolicyAcceptanceScreen extends ConsumerStatefulWidget {
  const PolicyAcceptanceScreen({this.returnToPreviousPage = false, super.key});

  /// Native action-bound review retains the editor underneath this page.
  /// Global router gates continue to use their URL continuation by default.
  final bool returnToPreviousPage;
  @override
  ConsumerState<PolicyAcceptanceScreen> createState() =>
      _PolicyAcceptanceScreenState();
}

class _PolicyAcceptanceScreenState
    extends ConsumerState<PolicyAcceptanceScreen> {
  bool _checked = false;
  bool _returning = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(policyAcceptanceProvider);
    if (widget.returnToPreviousPage &&
        !_returning &&
        state.allows(
          ref.read(authSessionProvider).identity?.id,
          ref.read(policyVersionProvider),
        )) {
      _returning = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
    ref.listen(
      policyAcceptanceProvider.select((s) => (s.account, s.version)),
      (_, _) => setState(() => _checked = false),
    );
    final documents = ref.watch(policyDocumentsProvider);
    final canAccept =
        state.phase == PolicyAcceptancePhase.required ||
        state.phase == PolicyAcceptancePhase.writeFailed;
    return PopScope(
      canPop: widget.returnToPreviousPage,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: HelpScaffold(
        title: l10n.policyAcceptanceTitle,
        fallback: '/',
        onBack: widget.returnToPreviousPage
            ? () => Navigator.of(context).maybePop()
            : () => context.go('/'),
        children: [
          Text(l10n.policyAcceptanceExplanation),
          const SizedBox(height: AppSpacing.medium),
          Text(l10n.policyProvisional),
          Text(
            l10n.policyVersion(state.version),
            key: const Key('policy-version'),
          ),
          PolicyLinkAction(label: l10n.policyTerms, uri: documents.terms),
          PolicyLinkAction(label: l10n.policyRules, uri: documents.rules),
          PolicyLinkAction(label: l10n.policyPrivacy, uri: documents.privacy),
          Text(l10n.policyAccountAcknowledgement),
          if (state.phase == PolicyAcceptancePhase.loading ||
              state.phase == PolicyAcceptancePhase.saving)
            const LinearProgressIndicator(),
          if (state.phase == PolicyAcceptancePhase.readFailed ||
              state.phase == PolicyAcceptancePhase.writeFailed) ...[
            Text(
              state.phase == PolicyAcceptancePhase.readFailed
                  ? l10n.policyReadFailed
                  : l10n.policyWriteFailed,
            ),
            TextButton(
              onPressed: ref.read(policyAcceptanceProvider.notifier).retryRead,
              child: Text(l10n.retryAction),
            ),
          ],
          CheckboxListTile(
            key: const Key('policy-acceptance-checkbox'),
            contentPadding: EdgeInsets.zero,
            value: _checked,
            onChanged: canAccept
                ? (value) => setState(() => _checked = value == true)
                : null,
            title: Text(l10n.policyAcceptLabel),
          ),
          FilledButton(
            key: const Key('policy-acceptance-continue'),
            onPressed: _checked && canAccept
                ? () => ref.read(policyAcceptanceProvider.notifier).accept()
                : null,
            child: Text(l10n.policyAcceptAction),
          ),
          if (ref.watch(authSessionProvider).isAuthenticated)
            const AccountSignOutAction(),
        ],
      ),
    );
  }
}
