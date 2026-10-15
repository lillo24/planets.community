import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../blocking/presentation/blocking_action.dart';
import '../../messages/application/message_chats_refresh.dart';
import '../application/member_contact_attempt.dart';
import '../application/member_contact_access_changes.dart';
import '../data/member_contact_gateway.dart';
import '../domain/member_contact_models.dart';

class MemberContactInfoScreen extends ConsumerStatefulWidget {
  const MemberContactInfoScreen({required this.chatId, super.key});
  final String chatId;
  @override
  ConsumerState<MemberContactInfoScreen> createState() => _InfoState();
}

class _InfoState extends ConsumerState<MemberContactInfoScreen> {
  String? actor;
  MemberContactConversation? value;
  MemberContactAttempt? attempt;
  int epoch = 0, readRevision = 0;
  bool busy = false, failed = false, loading = true;
  String get slot => 'chat/${widget.chatId}/settings';
  bool current(String id, int generation) =>
      mounted &&
      generation == epoch &&
      ref.read(authSessionProvider).identity?.id == id;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(bind);
  }

  void bind() {
    actor = ref.read(authSessionProvider).identity?.id;
    epoch++;
    value = null;
    failed = false;
    busy = false;
    loading = actor != null;
    final retained = ref.read(memberContactAttemptsProvider)[slot];
    attempt = retained?.actor == actor ? retained : null;
    setState(() {});
    load();
  }

  Future<void> load() async {
    final read = ++readRevision;
    final id = actor, generation = epoch;
    if (id == null) return;
    try {
      final result = await ref
          .read(memberContactGatewayProvider)
          .conversation(id, widget.chatId);
      if (current(id, generation) && read == readRevision) {
        setState(() {
          value = result;
          loading = false;
          failed = false;
        });
      }
    } catch (_) {
      if (current(id, generation) && read == readRevision) {
        setState(() {
          value = null;
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<void> command(String operation, {bool recoverOnly = false}) async {
    final id = actor, generation = epoch, c = value;
    if (id == null || busy || (c == null && attempt == null)) return;
    final retained = attempt;
    final intent = retained?.ambiguous == true
        ? retained!.intent as (String?, bool)
        : (c?.episodeId, !(c?.muted ?? false));
    if (!recoverOnly && retained?.ambiguous != true && operation != 'mute') {
      final l = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(operation == 'leave' ? l.contactLeave : l.contactClose),
          content: Text(l.memberContactExitBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.groupCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                operation == 'leave' ? l.contactLeave : l.contactClose,
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !current(id, generation)) return;
    }
    final action =
        retained ??
        ref
            .read(memberContactAttemptsProvider.notifier)
            .acquire(slot, id, operation, intent);
    setState(() {
      busy = true;
      failed = false;
      attempt = action;
    });
    try {
      final gateway = ref.read(memberContactGatewayProvider);
      final result = recoverOnly
          ? action.receipt ?? await gateway.recover(id, action.actionId)
          : await action.deliver((key) {
              if (operation == 'mute') {
                return gateway.mute(id, key, widget.chatId, intent.$2);
              }
              if (intent.$1 == null) {
                throw StateError('Missing accepted member episode.');
              }
              return gateway.exit(
                id,
                key,
                widget.chatId,
                intent.$1!,
                leave: operation == 'leave',
              );
            });
      if (!current(id, generation)) return;
      if (result != null) {
        ref.read(memberContactAttemptsProvider.notifier).clear(slot);
        attempt = null;
        ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
        await load();
      }
    } catch (_) {
      if (current(id, generation)) {
        setState(() => failed = true);
        if (!action.ambiguous) {
          ref.read(memberContactAttemptsProvider.notifier).clear(slot);
          attempt = null;
          await load();
          if (current(id, generation)) setState(() => failed = true);
        }
      }
    } finally {
      if (current(id, generation)) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(messageChatsRefreshProvider, (_, _) => load());
    ref.listen(
      authSessionProvider.select((s) => (s.identity?.id, s.phase)),
      (_, _) => bind(),
    );
    ref.listen(memberContactAccessChangesProvider, (_, next) {
      if (next.$1 == actor) {
        epoch++;
        setState(() {
          value = null;
          busy = false;
        });
        load();
      }
    });
    final l = AppLocalizations.of(context), c = value;
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l.memberContactInfo)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (loading) const LinearProgressIndicator(),
            if (c != null) ...[
              Text(c.peerName, style: Theme.of(context).textTheme.titleLarge),
              Text(l.memberContactOrigin(c.groupName)),
              Text(l.memberContactPrivacy),
              if (c.readOnly) Text(l.memberContactReadOnly),
              if (attempt?.ambiguous != true) ...[
                SwitchListTile(
                  key: const Key('member-contact-mute'),
                  value: c.muted,
                  onChanged: busy ? null : (_) => command('mute'),
                  title: Text(l.memberContactMute),
                ),
                if (!c.readOnly) ...[
                  OutlinedButton(
                    key: const Key('member-contact-close'),
                    onPressed: busy ? null : () => command('close'),
                    child: Text(l.contactClose),
                  ),
                  OutlinedButton(
                    key: const Key('member-contact-leave'),
                    onPressed: busy ? null : () => command('leave'),
                    child: Text(l.contactLeave),
                  ),
                ],
              ],
              BlockingActionButton(
                targetProfileId: c.peerId,
                consequence: BlockingContextConsequence.memberContact,
                onChanged: (_) => load(),
              ),
            ] else if (!loading) ...[
              Text(l.contactUnavailable),
              TextButton(onPressed: load, child: Text(l.retryAction)),
            ],
            if (failed || attempt?.ambiguous == true)
              Text(
                attempt?.ambiguous == true
                    ? l.contactDeliveryPending
                    : l.contactFailure,
              ),
            if (attempt?.ambiguous == true) ...[
              FilledButton(
                onPressed: busy ? null : () => command(attempt!.operation),
                child: Text(l.retryAction),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => command(attempt!.operation, recoverOnly: true),
                child: Text(l.contactRecover),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
