import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../activity_interest/application/activity_interest_tracker.dart';
import '../../activity_interest/domain/activity_interest_event.dart';
import '../../participation/domain/participation_models.dart';
import '../../mock_mode/application/mock_mode_coordinator.dart';
import '../../project_delegates/application/project_invite_sharing.dart';
import 'participant_invitation_routes.dart';

/// Only this explicit copy/share boundary discloses a capability to the platform.
class ShareLinkButtons extends ConsumerStatefulWidget {
  const ShareLinkButtons({
    required this.projectId,
    required this.prepare,
    this.canDisclose,
    this.publicActivity,
    this.disabled = false,
    super.key,
  });
  final String projectId;
  final Future<String?> Function() prepare;
  final bool Function()? canDisclose;
  // Set only by the ordinary public Tavolo dialog, never invitation controls.
  final PublicActivityInterestItem? publicActivity;
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
    if (_busy || ref.read(activeMockRealmProvider)) return;
    final revision = ++_revision;
    final account = ref.read(authSessionProvider).identity?.id;
    final publicActivity = widget.publicActivity;
    setState(() {
      _busy = true;
      _message = null;
    });
    bool current() =>
        mounted &&
        revision == _revision &&
        ref.read(authSessionProvider).identity?.id == account;
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
      if (publicActivity != null &&
          widget.publicActivity?.id == publicActivity.id &&
          value ==
              ParticipantInvitationRoutes.ordinaryUrl(
                ProjectKind.recurring,
                publicActivity.id,
              )) {
        recordActivityInterest(
          ref,
          ActivityInterestEvent.publicShare(
            publicActivity,
            native
                ? ActivityShareAction.shareSheetInvoked
                : ActivityShareAction.linkCopied,
          ),
          isCurrent: () =>
              current() &&
              widget.publicActivity?.id == publicActivity.id &&
              widget.canDisclose?.call() != false,
        );
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
    if (ref.watch(activeMockRealmProvider)) {
      return Text(l10n.mockExternalUnavailable);
    }
    ref.listen(authSessionProvider.select((s) => s.identity?.id), (_, _) {
      _revision++;
      if (mounted) {
        setState(() {
          _busy = false;
          _message = null;
        });
      }
    });
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
