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
  const PolicyAcceptanceScreen({super.key});
  @override
  ConsumerState<PolicyAcceptanceScreen> createState() =>
      _PolicyAcceptanceScreenState();
}

class _PolicyAcceptanceScreenState
    extends ConsumerState<PolicyAcceptanceScreen> {
  bool _checked = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(policyAcceptanceProvider);
    ref.listen(
      policyAcceptanceProvider.select((s) => (s.account, s.version)),
      (_, _) => setState(() => _checked = false),
    );
    final documents = ref.watch(policyDocumentsProvider);
    final canAccept =
        state.phase == PolicyAcceptancePhase.required ||
        state.phase == PolicyAcceptancePhase.writeFailed;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: HelpScaffold(
        title: l10n.policyAcceptanceTitle,
        fallback: '/',
        onBack: () => context.go('/'),
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
          Text(l10n.policyLocalAcknowledgement),
          if (state.phase == PolicyAcceptancePhase.loading ||
              state.phase == PolicyAcceptancePhase.saving)
            const LinearProgressIndicator(),
          if (state.phase == PolicyAcceptancePhase.readFailed) ...[
            Text(l10n.policyReadFailed),
            TextButton(
              onPressed: ref.read(policyAcceptanceProvider.notifier).retryRead,
              child: Text(l10n.retryAction),
            ),
          ],
          if (state.phase == PolicyAcceptancePhase.writeFailed)
            Text(l10n.policyWriteFailed),
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
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(l10n.policyCancel),
          ),
          TextButton(
            onPressed: () => context.push('/settings'),
            child: Text(l10n.settingsTitle),
          ),
          TextButton(
            onPressed: () => context.push('/help'),
            child: Text(l10n.helpTitle),
          ),
          if (ref.watch(authSessionProvider).isAuthenticated)
            const AccountSignOutAction(),
        ],
      ),
    );
  }
}
