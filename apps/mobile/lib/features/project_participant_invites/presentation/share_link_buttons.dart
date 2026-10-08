import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../project_delegates/application/project_invite_sharing.dart';

/// Only this explicit copy/share boundary discloses a capability to the platform.
class ShareLinkButtons extends ConsumerStatefulWidget {
  const ShareLinkButtons({
    required this.projectId,
    required this.prepare,
    this.canDisclose,
    this.disabled = false,
    super.key,
  });
  final String projectId;
  final Future<String?> Function() prepare;
  final bool Function()? canDisclose;
  final bool disabled;
  @override
  ConsumerState<ShareLinkButtons> createState() => _ShareLinkButtonsState();
}

class _ShareLinkButtonsState extends ConsumerState<ShareLinkButtons> {
  var _revision = 0;
  bool _busy = false;
  String? _message;
  @override
  void didUpdateWidget(covariant ShareLinkButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.projectId != oldWidget.projectId) {
      _revision++;
      _busy = false;
      _message = null;
    }
  }

  Future<void> _disclose(bool native, BuildContext buttonContext) async {
    if (_busy) return;
    final revision = ++_revision;
    final account = ref.read(authSessionProvider).identity?.id;
    setState(() {
      _busy = true;
      _message = null;
    });
    bool current() =>
        mounted &&
        revision == _revision &&
        ref.read(authSessionProvider).identity?.id == account &&
        ref.read(authSessionProvider).accountAccessIdentityId == account;
    try {
      final value = await widget.prepare();
      if (!mounted ||
          !buttonContext.mounted ||
          !current() ||
          widget.canDisclose?.call() == false) {
        return;
      }
      if (value == null) {
        setState(
          () => _message = AppLocalizations.of(context).projectShareFailure,
        );
        return;
      }
      final sharing = ref.read(projectInviteSharingProvider);
      if (native) {
        final box = buttonContext.findRenderObject() as RenderBox?;
        await sharing.share(
          value,
          origin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        );
      } else {
        await sharing.copy(value);
        if (current()) {
          setState(
            () => _message = AppLocalizations.of(context).projectShareCopied,
          );
        }
      }
    } catch (_) {
      if (current()) {
        setState(
          () => _message = AppLocalizations.of(context).projectShareFailure,
        );
      }
    } finally {
      if (current()) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(
      authSessionProvider.select(
        (s) => (s.identity?.id, s.accountAccessIdentityId),
      ),
      (_, _) {
        _revision++;
        if (mounted) {
          setState(() {
            _busy = false;
            _message = null;
          });
        }
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (buttonContext) => OutlinedButton.icon(
            key: const Key('project-share-copy'),
            onPressed: _busy || widget.disabled
                ? null
                : () => _disclose(false, buttonContext),
            icon: const Icon(Icons.copy),
            label: Text(l10n.projectShareCopy),
          ),
        ),
        Builder(
          builder: (buttonContext) => FilledButton.icon(
            key: const Key('project-share-native'),
            onPressed: _busy || widget.disabled
                ? null
                : () => _disclose(true, buttonContext),
            icon: const Icon(Icons.share_outlined),
            label: Text(l10n.projectShareNative),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Text(
            _message!,
            key: const Key('project-share-message'),
            semanticsLabel: _message,
          ),
      ],
    );
  }
}
