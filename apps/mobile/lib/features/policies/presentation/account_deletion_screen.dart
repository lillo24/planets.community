import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../help/application/support_mail.dart';
import '../../help/presentation/help_screen.dart';
import '../../help/presentation/support_mail_action.dart';
import '../application/policy_documents.dart';
import 'policy_link_action.dart';

const deletionMailSubject = 'PLANETS — Richiesta eliminazione account';
String deletionMailBody(String email) =>
    'Chiedo l’eliminazione del mio account PLANETS e dei dati personali associati.'
    '${email.trim().isEmpty ? '' : '\nEmail dell’account: ${email.trim()}'}';

class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});
  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final _email = TextEditingController();
  int _generation = 0;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    final generation = _generation;
    final l10n = AppLocalizations.of(context);
    bool copied;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      copied = true;
    } on Exception {
      copied = false;
    }
    if (!mounted || generation != _generation) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copied ? l10n.policyCopied : l10n.policyCopyFailed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    ref.listen(authSessionProvider.select((s) => s.identity?.id), (_, _) {
      _generation++;
      _email.clear();
      setState(() {});
    });
    final l10n = AppLocalizations.of(context);
    final address = ref.watch(publicSupportEmailProvider);
    final body = deletionMailBody(_email.text);
    return HelpScaffold(
      title: l10n.policyDeleteAccount,
      fallback: '/settings',
      children: [
        Text(l10n.policyDeletionExplanation),
        const SizedBox(height: AppSpacing.medium),
        Text(l10n.policyDeletionOutcome),
        Text(l10n.policyDeletionRights),
        const SizedBox(height: AppSpacing.medium),
        Text(l10n.policyDeletionFromEmail),
        TextField(
          key: const Key('deletion-account-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          maxLength: 254,
          decoration: InputDecoration(labelText: l10n.policyAccountEmail),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.medium),
        SelectableText(deletionMailSubject),
        SelectableText(body, key: const Key('deletion-mail-review')),
        SupportMailAction(
          key: ValueKey('deletion-mail-${session.identity?.id}'),
          subject: deletionMailSubject,
          body: body,
        ),
        if (address != null)
          TextButton.icon(
            key: const Key('deletion-copy-address'),
            onPressed: () => _copy(address),
            icon: const Icon(Icons.copy),
            label: Text(l10n.policyCopyAddress),
          ),
        TextButton.icon(
          key: const Key('deletion-copy-draft'),
          onPressed: () => _copy(
            'To: ${address ?? ''}\nSubject: $deletionMailSubject\n\n$body',
          ),
          icon: const Icon(Icons.copy),
          label: Text(l10n.policyCopyDraft),
        ),
        PolicyLinkAction(
          label: l10n.policyDeletionWebsite,
          uri: ref.watch(policyDocumentsProvider).deletion,
        ),
      ],
    );
  }
}
