import 'package:flutter/material.dart';

import '../../group_contact/presentation/contact_button_style.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../blocking/presentation/blocking_action.dart';
import '../../messages/application/message_chats_refresh.dart';
import '../../messages/presentation/messages_formatters.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../application/member_contact_attempt.dart';
import '../application/member_contact_access_changes.dart';
import '../data/member_contact_gateway.dart';
import '../../group_contact/data/group_contact_gateway.dart'
    show contactAccessDenied;
import '../domain/member_contact_models.dart';
import 'member_contact_routes.dart';
import 'member_contact_widgets.dart';

class MemberContactRequestScreen extends ConsumerStatefulWidget {
  const MemberContactRequestScreen({required this.requestId, super.key});
  final String requestId;
  @override
  ConsumerState<MemberContactRequestScreen> createState() =>
      _MemberContactRequestScreenState();
}

class _MemberContactRequestScreenState
    extends ConsumerState<MemberContactRequestScreen> {
  String? actor, peer;
  MemberContactRequest? request;
  bool loading = true,
      busy = false,
      failed = false,
      denied = false,
      canReport = false;
  int epoch = 0, revision = 0;
  MemberContactAttempt? attempt;
  String get slot => 'request/${widget.requestId}';
  bool current(String id, int generation) =>
      mounted &&
      epoch == generation &&
      actor == id &&
      ref.read(authSessionProvider).identity?.id == id;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(bind);
  }

  void bind() {
    final s = ref.read(authSessionProvider);
    actor = s.phase == AuthSessionPhase.ready ? s.identity?.id : null;
    epoch++;
    revision++;
    request = null;
    peer = null;
    canReport = false;
    busy = false;
    failed = false;
    loading = actor != null;
    final retained = ref.read(memberContactAttemptsProvider)[slot];
    attempt = retained?.actor == actor ? retained : null;
    if (mounted) setState(() {});
    load();
  }

  Future<void> load() async {
    final id = actor;
    final generation = epoch, read = ++revision;
    if (id == null) return;
    try {
      final result = await ref
          .read(memberContactGatewayProvider)
          .request(id, widget.requestId);
      if (!current(id, generation) || read != revision) return;
      setState(() {
        request = result;
        loading = false;
        failed = false;
        denied = false;
        peer = result.senderId == id ? result.recipientId : result.senderId;
        if (result.recipientId == id && result.note != null) {
          canReport = true;
          peer = result.senderId;
        }
      });
    } catch (error) {
      if (current(id, generation) && read == revision) {
        setState(() {
          loading = false;
          failed = true;
          denied = contactAccessDenied(error);
          request = null;
        });
      }
    }
  }

  Future<void> recover() async {
    final id = actor, action = attempt;
    final generation = epoch;
    if (id == null || action == null || busy) return;
    setState(() => busy = true);
    try {
      final receipt =
          action.receipt ??
          await ref
              .read(memberContactGatewayProvider)
              .recover(id, action.actionId);
      if (!current(id, generation)) return;
      if (receipt != null) {
        ref.read(memberContactAttemptsProvider.notifier).clear(slot);
        setState(() => attempt = null);
        await load();
      }
    } catch (_) {
      if (current(id, generation)) setState(() => failed = true);
    } finally {
      if (current(id, generation)) setState(() => busy = false);
    }
  }

  Future<void> decide(String operation) async {
    final id = actor;
    final generation = epoch;
    if (id == null || busy) return;
    final l = AppLocalizations.of(context);
    if (operation == 'accept' && attempt?.ambiguous != true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(l.contactAccept),
          content: Text(l.memberContactAcceptBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.groupCancel),
            ),
            FilledButton(
              style: contactFilledButtonStyle,
              key: const Key('contact-confirm-accept'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.groupAccept),
            ),
          ],
        ),
      );
      if (confirmed != true || !current(id, generation)) return;
    }
    final action = ref
        .read(memberContactAttemptsProvider.notifier)
        .acquire(slot, id, operation, widget.requestId);
    setState(() {
      attempt = action;
      busy = true;
      failed = false;
    });
    try {
      await action.deliver(
        (key) => ref
            .read(memberContactGatewayProvider)
            .decide(id, key, widget.requestId, operation),
      );
      if (!current(id, generation)) return;
      ref.read(memberContactAttemptsProvider.notifier).clear(slot);
      attempt = null;
      ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
      await load();
    } catch (_) {
      if (current(id, generation)) {
        setState(() => failed = true);
        if (!action.ambiguous) await load();
        if (current(id, generation)) setState(() => failed = true);
      }
    } finally {
      if (current(id, generation)) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authSessionProvider.select((s) => (s.identity?.id, s.phase)),
      (_, _) => bind(),
    );
    ref.listen(messageChatsRefreshProvider, (_, _) => load());
    ref.listen(memberContactAccessChangesProvider, (_, next) {
      if (next.$1 == actor && mounted) {
        revision++;
        setState(() => request = null);
        load();
      }
    });
    final l = AppLocalizations.of(context), r = request;
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l.memberContactRequest)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (r == null) ...[
              Text(denied ? l.contactRequestUnavailable : l.contactFailure),
              TextButton(onPressed: load, child: Text(l.retryAction)),
            ] else ...[
              Text(
                l.memberContactRequest,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(memberContactStatusLabel(l, r.status)),
              Text(messageDate(context, r.activityAt)),
              Text(l.memberContactOrigin(r.groupName)),
              Text('${r.senderName} → ${r.recipientName}'),
              const SizedBox(height: 16),
              if (r.note != null) Text(r.note!),
              if (failed)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    attempt?.ambiguous == true
                        ? l.contactDeliveryPending
                        : l.contactFailure,
                  ),
                ),
              if (attempt?.ambiguous == true)
                FilledButton(
                  style: contactFilledButtonStyle,
                  key: const Key('contact-request-retry'),
                  onPressed: busy ? null : () => decide(attempt!.operation),
                  child: Text(l.retryAction),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (r.canAccept)
                      FilledButton(
                        style: contactFilledButtonStyle,
                        key: const Key('contact-accept'),
                        onPressed: busy ? null : () => decide('accept'),
                        child: Text(l.contactAccept),
                      ),
                    if (r.canDecline)
                      OutlinedButton(
                        key: const Key('contact-decline'),
                        onPressed: busy ? null : () => decide('decline'),
                        child: Text(l.contactDecline),
                      ),
                    if (r.canWithdraw)
                      OutlinedButton(
                        key: const Key('contact-withdraw'),
                        onPressed: busy ? null : () => decide('withdraw'),
                        child: Text(l.contactWithdraw),
                      ),
                  ],
                ),
              if (r.chatId case final String chat)
                FilledButton(
                  style: contactFilledButtonStyle,
                  onPressed: () => context.push(memberContactChatRoute(chat)),
                  child: Text(l.contactOpen),
                ),
            ],
            if (attempt?.ambiguous == true || attempt?.receipt != null)
              TextButton(
                key: const Key('contact-recover-request'),
                onPressed: busy ? null : recover,
                child: Text(l.contactRecover),
              ),
            if (canReport)
              OutlinedButton.icon(
                onPressed: () => ModerationRoutes.openReport(
                  context,
                  ModerationReportTarget(
                    kind: ModerationTargetKind.memberContactRequest,
                    id: widget.requestId,
                    label: l.contactInitialReport,
                  ),
                ),
                icon: const Icon(Icons.flag_outlined),
                label: Text(l.contactInitialReport),
              ),
            if (peer case final String person)
              BlockingActionButton(
                targetProfileId: person,
                consequence: BlockingContextConsequence.memberContact,
                onChanged: (_) => load(),
              ),
          ],
        ),
      ),
    );
  }
}
