import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/support_mail.dart';

/// External handoff boundary. It keeps failures explicit and makes no send claim.
class SupportMailAction extends ConsumerStatefulWidget {
  const SupportMailAction({required this.subject, this.body = '', super.key});

  final String subject;
  final String body;

  @override
  ConsumerState<SupportMailAction> createState() => _SupportMailActionState();
}

class _SupportMailActionState extends ConsumerState<SupportMailAction> {
  bool _busy = false;
  bool? _opened;
  int _generation = 0;

  @override
  void didUpdateWidget(SupportMailAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subject != widget.subject || oldWidget.body != widget.body) {
      _generation++;
      _busy = false;
      _opened = null;
    }
  }

  Future<void> _open(Uri uri) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _opened = null;
    });
    bool opened;
    try {
      opened = await ref.read(supportMailLauncherProvider).open(uri);
    } on Exception {
      opened = false;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _busy = false;
      _opened = opened;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final email = ref.watch(publicSupportEmailProvider);
    Uri? uri;
    if (email != null) {
      try {
        uri = supportMailUri(email, subject: widget.subject, body: widget.body);
      } on FormatException {
        uri = null;
      } on ArgumentError {
        uri = null;
      }
    }
    final destination = uri;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (destination == null)
          Text(
            l10n.helpEmailUnconfigured,
            key: const Key('help-mail-unconfigured'),
          )
        else ...[
          SelectableText(email!),
          const SizedBox(height: AppSpacing.small),
          FilledButton.icon(
            key: const Key('help-mail-open'),
            onPressed: _busy ? null : () => _open(destination),
            icon: const Icon(Icons.mail_outline),
            label: Text(l10n.helpOpenMail),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(l10n.helpMailChoice),
          if (_opened != null) ...[
            const SizedBox(height: AppSpacing.small),
            Semantics(
              liveRegion: true,
              child: Text(
                _opened! ? l10n.helpMailOpened : l10n.helpMailUnavailable,
                key: const Key('help-mail-status'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
