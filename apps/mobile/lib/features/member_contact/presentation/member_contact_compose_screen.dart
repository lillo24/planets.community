import '../application/member_contact_drafts.dart';

import 'package:flutter/material.dart';

import '../../group_contact/presentation/contact_button_style.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../messages/application/message_chats_refresh.dart';
import '../application/member_contact_attempt.dart';
import '../application/member_contact_access_changes.dart';
import '../data/member_contact_gateway.dart';
import '../domain/member_contact_models.dart';
import 'member_contact_routes.dart';

class MemberContactComposeScreen extends ConsumerStatefulWidget {
  const MemberContactComposeScreen({
    required this.groupId,
    required this.recipientId,
    super.key,
  });
  final String groupId, recipientId;
  @override
  ConsumerState<MemberContactComposeScreen> createState() => _ComposeState();
}

class _ComposeState extends ConsumerState<MemberContactComposeScreen> {
  final note = TextEditingController();
  String? actor;
  MemberContactContext? value;
  MemberContactAttempt? attempt;
  bool loading = true, busy = false, failed = false;
  int epoch = 0, readRevision = 0;
  String get slot => 'compose/${widget.groupId}/${widget.recipientId}';
  bool current(String id, int generation) =>
      mounted &&
      generation == epoch &&
      actor == id &&
      ref.read(authSessionProvider).identity?.id == id;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(bind);
  }

  @override
  void dispose() {
    epoch++;
    note.dispose();
    super.dispose();
  }

  void bind() {
    final session = ref.read(authSessionProvider);
    actor = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    epoch++;
    value = null;
    busy = false;
    failed = false;
    loading = actor != null;
    note.text = ref.read(memberContactDraftsProvider)[slot] ?? '';
    final retained = ref.read(memberContactAttemptsProvider)[slot];
    attempt = retained?.actor == actor ? retained : null;
    if (attempt != null) note.text = attempt!.intent as String;
    if (mounted) setState(() {});
    load();
  }

  Future<void> load() async {
    final read = ++readRevision;
    final id = actor, generation = epoch;
    if (id == null) return;
    try {
      final result = await ref
          .read(memberContactGatewayProvider)
          .context(id, widget.groupId, widget.recipientId);
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

  Future<void> send({bool recoverOnly = false}) async {
    final id = actor, generation = epoch;
    if (id == null ||
        busy ||
        (!recoverOnly &&
            attempt?.ambiguous != true &&
            value?.canRequest != true)) {
      return;
    }
    final text = note.text;
    if (text.runes.length > 500) {
      setState(() => failed = true);
      return;
    }
    final action =
        attempt ??
        ref
            .read(memberContactAttemptsProvider.notifier)
            .acquire(slot, id, 'request', text);
    setState(() {
      busy = true;
      failed = false;
      attempt = action;
    });
    try {
      final gateway = ref.read(memberContactGatewayProvider);
      final receipt = recoverOnly
          ? action.receipt ?? await gateway.recover(id, action.actionId)
          : await action.deliver(
              (key) => gateway.submit(
                id,
                key,
                widget.groupId,
                widget.recipientId,
                text.trim().isEmpty ? null : text,
              ),
            );
      if (!mounted || !current(id, generation)) return;
      if (receipt != null) {
        if (receipt.requestId == null) {
          throw const FormatException('Member request receipt lacks request.');
        }
        ref.read(memberContactAttemptsProvider.notifier).clear(slot);
        attempt = null;
        ref.read(memberContactDraftsProvider.notifier).clear(slot);
        ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
        context.pushReplacement(memberContactRequestRoute(receipt.requestId!));
      }
    } catch (_) {
      if (current(id, generation)) {
        setState(() => failed = true);
        if (!action.ambiguous) {
          ref.read(memberContactAttemptsProvider.notifier).clear(slot);
          attempt = null;
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
      appBar: pageAppBar(context, title: Text(l.memberContactAction)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (loading) const LinearProgressIndicator(),
            if (c != null) ...[
              Text(
                c.recipientName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(l.memberContactOrigin(c.groupName)),
              Text(l.memberContactPrivacy),
              // The pending request may be this unresolved delivery itself.
              if (!c.canRequest && attempt?.ambiguous != true)
                Text(l.memberContactNotEligible),
            ] else if (!loading) ...[
              Text(l.contactRequestUnavailable),
              TextButton(onPressed: load, child: Text(l.retryAction)),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const Key('member-contact-note'),
              controller: note,
              onChanged: (text) => ref
                  .read(memberContactDraftsProvider.notifier)
                  .save(slot, text),
              enabled: !busy && attempt?.ambiguous != true,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              decoration: InputDecoration(labelText: l.memberContactNote),
            ),
            if (failed || attempt?.ambiguous == true)
              Semantics(
                liveRegion: true,
                child: Text(
                  attempt?.ambiguous == true
                      ? l.contactDeliveryPending
                      : l.contactFailure,
                ),
              ),
            FilledButton(
              style: contactFilledButtonStyle,
              key: const Key('member-contact-submit'),
              onPressed:
                  busy || (c?.canRequest != true && attempt?.ambiguous != true)
                  ? null
                  : send,
              child: Text(
                attempt?.ambiguous == true
                    ? l.retryAction
                    : l.memberContactAction,
              ),
            ),
            if (attempt?.ambiguous == true)
              TextButton(
                onPressed: busy ? null : () => send(recoverOnly: true),
                child: Text(l.contactRecover),
              ),
          ],
        ),
      ),
    );
  }
}
