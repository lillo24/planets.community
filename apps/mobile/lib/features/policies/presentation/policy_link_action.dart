import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../help/application/support_mail.dart';

// Same supported external launcher as Help. No clipboard or browser handoff is automatic.
class PolicyLinkAction extends ConsumerStatefulWidget {
  const PolicyLinkAction({
    required this.label,
    required this.uri,
    this.asTile = false,
    super.key,
  });
  final String label;
  final Uri uri;
  final bool asTile;
  @override
  ConsumerState<PolicyLinkAction> createState() => _PolicyLinkActionState();
}

class _PolicyLinkActionState extends ConsumerState<PolicyLinkAction> {
  bool _busy = false;
  bool _failed = false;
  Future<void> _open() async {
    setState(() => _busy = true);
    bool opened;
    try {
      opened = await ref.read(supportMailLauncherProvider).open(widget.uri);
    } on Exception {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !opened;
    });
  }

  Future<void> _copy() async {
    final l10n = AppLocalizations.of(context);
    bool copied;
    try {
      await Clipboard.setData(ClipboardData(text: widget.uri.toString()));
      copied = true;
    } on Exception {
      copied = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copied ? l10n.policyCopied : l10n.policyCopyFailed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.asTile)
          ListTile(
            title: Text(widget.label),
            leading: const Icon(Icons.privacy_tip_outlined),
            trailing: const Icon(Icons.open_in_new),
            onTap: _busy ? null : _open,
          )
        else
          TextButton.icon(
            onPressed: _busy ? null : _open,
            icon: const Icon(Icons.open_in_new),
            label: Text(widget.label),
          ),
        if (_failed) ...[
          Text(l10n.policyLinkFailed),
          SelectableText(widget.uri.toString()),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _busy ? null : _open,
                child: Text(l10n.retryAction),
              ),
              TextButton(onPressed: _copy, child: Text(l10n.policyCopyLink)),
            ],
          ),
        ],
      ],
    );
  }
}
