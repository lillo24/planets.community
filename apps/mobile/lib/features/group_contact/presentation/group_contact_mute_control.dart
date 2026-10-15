import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/contact_access_changes.dart';
import '../application/contact_attempt.dart';
import '../data/group_contact_gateway.dart';

/// Actor-bound notification preference. Reading or muting never acknowledges
/// messages, and an uncertain write retains its original command and value.
class GroupContactMuteControl extends ConsumerStatefulWidget {
  const GroupContactMuteControl({required this.chatId, super.key});
  final String chatId;

  @override
  ConsumerState<GroupContactMuteControl> createState() =>
      _GroupContactMuteState();
}

class _GroupContactMuteState extends ConsumerState<GroupContactMuteControl> {
  bool? muted;
  bool busy = false, failed = false;
  int revision = 0;
  String get slot => 'chat/${widget.chatId}/mute';
  String? get actor {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
  }

  bool current(String id, int read) =>
      mounted && revision == read && actor == id;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(load);
  }

  @override
  void didUpdateWidget(GroupContactMuteControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId) invalidate();
  }

  void invalidate() {
    revision++;
    setState(() {
      muted = null;
      busy = false;
      failed = false;
    });
    load();
  }

  Future<void> load() async {
    final id = actor, read = ++revision;
    if (id == null) return;
    try {
      final value = await ref
          .read(groupContactGatewayProvider)
          .muted(id, widget.chatId);
      if (current(id, read)) {
        setState(() {
          muted = value;
          failed = false;
        });
      }
    } catch (_) {
      if (current(id, read)) {
        setState(() {
          muted = null;
          failed = true;
        });
      }
    }
  }

  Future<void> save({bool recover = false}) async {
    final id = actor;
    if (id == null || busy) return;
    final retained = ref.read(contactAttemptsProvider)[slot];
    if (retained?.actor != null && retained!.actor != id) return;
    if (retained == null && muted == null) return;
    final action =
        retained ??
        ref
            .read(contactAttemptsProvider.notifier)
            .acquire(slot, id, 'mute', !muted!);
    final read = ++revision;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final gateway = ref.read(groupContactGatewayProvider);
      if (recover) {
        final receipt =
            action.receipt ?? await gateway.recover(id, action.actionId);
        if (!current(id, read)) return;
        if (receipt == null) {
          setState(() => failed = true);
          return;
        }
      } else {
        await action.deliver(
          (key) =>
              gateway.setMuted(id, key, widget.chatId, action.intent as bool),
        );
        if (!current(id, read)) return;
      }
      ref.read(contactAttemptsProvider.notifier).clear(slot);
      setState(() => busy = false);
      await load();
    } catch (_) {
      if (current(id, read)) {
        if (!action.ambiguous) {
          ref.read(contactAttemptsProvider.notifier).clear(slot);
        }
        setState(() => failed = true);
      }
    } finally {
      if (current(id, read)) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authSessionProvider.select((s) => (s.identity?.id, s.phase)),
      (_, _) => invalidate(),
    );
    ref.listen(contactAccessChangesProvider, (_, _) => invalidate());
    final attempt = ref.watch(contactAttemptsProvider)[slot];
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attempt?.ambiguous == true || attempt?.receipt != null) ...[
          Text(l.contactDeliveryPending),
          TextButton(
            key: const Key('contact-mute-recover'),
            onPressed: busy ? null : () => save(recover: true),
            child: Text(l.contactRecover),
          ),
          if (attempt?.ambiguous == true)
            TextButton(
              key: const Key('contact-mute-retry'),
              onPressed: busy ? null : save,
              child: Text(l.retryAction),
            ),
        ] else if (muted != null)
          TextButton.icon(
            key: const Key('contact-mute'),
            onPressed: busy ? null : save,
            icon: Icon(
              muted!
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_outlined,
            ),
            label: Text(muted! ? l.contactUnmute : l.contactMute),
          ),
        if (failed) ...[
          Text(l.contactFailure),
          if (attempt == null)
            TextButton(
              onPressed: busy ? null : load,
              child: Text(l.retryAction),
            ),
        ],
      ],
    );
  }
}
