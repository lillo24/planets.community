import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../activity_interest/application/activity_interest_tracker.dart';
import '../../activity_interest/domain/activity_interest_event.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../mock_mode/application/mock_mode_coordinator.dart';
import '../../project_delegates/application/project_invite_sharing.dart';
import '../../settings/application/activities_split_preference_controller.dart';
import '../domain/external_activity.dart';

/// Shares only the validated public official link of a loaded catalogue record.
class ExternalActivityShareActions extends ConsumerStatefulWidget {
  const ExternalActivityShareActions({required this.activity, super.key});
  final ExternalActivity activity;

  @override
  ConsumerState<ExternalActivityShareActions> createState() =>
      _ExternalActivityShareActionsState();
}

class _ExternalActivityShareActionsState
    extends ConsumerState<ExternalActivityShareActions> {
  var _revision = 0;
  var _busy = false;
  String? _message;

  @override
  void didUpdateWidget(covariant ExternalActivityShareActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity.id != widget.activity.id ||
        oldWidget.activity.officialLink.uri !=
            widget.activity.officialLink.uri) {
      _revision++;
      _busy = false;
      _message = null;
    }
  }

  Future<void> _share(bool native, BuildContext buttonContext) async {
    if (_busy || ref.read(activeMockRealmProvider)) return;
    final revision = ++_revision;
    final account = ref.read(authSessionProvider).identity?.id;
    final activity = widget.activity;
    final url = activity.officialLink.uri.toString();
    bool current() =>
        mounted &&
        revision == _revision &&
        !ref.read(activeMockRealmProvider) &&
        ref.read(activitiesSplitPreferenceProvider).enabled &&
        ref.read(authSessionProvider).identity?.id == account &&
        widget.activity.id == activity.id &&
        widget.activity.officialLink.uri == activity.officialLink.uri &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!current()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final sharing = ref.read(projectInviteSharingProvider);
      if (native) {
        final box = buttonContext.findRenderObject() as RenderBox?;
        await sharing.share(
          url,
          origin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        );
      } else {
        await sharing.copy(url);
      }
      if (!current()) return;
      if (!native) {
        setState(
          () => _message = AppLocalizations.of(context).projectShareCopied,
        );
      }
      final item = PublicActivityInterestItem.importedActivity(activity.id);
      if (item != null) {
        recordActivityInterest(
          ref,
          ActivityInterestEvent.publicShare(
            item,
            native
                ? ActivityShareAction.shareSheetInvoked
                : ActivityShareAction.linkCopied,
          ),
          isCurrent: current,
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
    final l = AppLocalizations.of(context);
    if (ref.watch(activeMockRealmProvider)) {
      return Text(l.mockExternalUnavailable);
    }
    ref.listen(authSessionProvider.select((s) => s.identity?.id), (_, _) {
      _revision++;
      setState(() {
        _busy = false;
        _message = null;
      });
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (buttonContext) => OutlinedButton.icon(
            key: const Key('external-activity-copy'),
            onPressed: _busy ? null : () => _share(false, buttonContext),
            icon: const Icon(Icons.copy),
            label: Text(l.projectShareCopy),
          ),
        ),
        Builder(
          builder: (buttonContext) => OutlinedButton.icon(
            key: const Key('external-activity-share'),
            onPressed: _busy ? null : () => _share(true, buttonContext),
            icon: const Icon(Icons.share_outlined),
            label: Text(l.projectShareNative),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Text(_message!, key: const Key('external-activity-share-message')),
      ],
    );
  }
}
