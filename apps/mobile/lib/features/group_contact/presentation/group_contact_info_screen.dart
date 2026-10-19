import 'package:flutter/material.dart';

import 'contact_button_style.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../blocking/presentation/blocking_action.dart';
import '../../messages/application/message_chats_refresh.dart';
import '../application/contact_attempt.dart';
import '../application/contact_access_changes.dart';
import '../data/group_contact_gateway.dart';
import '../domain/group_contact_models.dart';
import 'group_contact_mute_control.dart';
import '../../group_coordination/data/coordination_gateway.dart';
import '../../group_coordination/presentation/coordination_routes.dart';

class GroupContactInfoScreen extends ConsumerStatefulWidget {
  const GroupContactInfoScreen({required this.chatId, super.key});
  final String chatId;
  @override
  ConsumerState<GroupContactInfoScreen> createState() =>
      _GroupContactInfoScreenState();
}

class _GroupContactInfoScreenState
    extends ConsumerState<GroupContactInfoScreen> {
  String? actor;
  GroupContactConversation? conversation;
  ContactAttempt? attempt;
  int epoch = 0, revision = 0;
  bool loading = true,
      busy = false,
      failed = false,
      denied = false,
      knownAdmission = false;
  String get slot => 'chat/${widget.chatId}/exit';
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
    conversation = null;
    attempt = null;
    final retained = ref.read(contactAttemptsProvider)[slot];
    if (retained?.actor == actor &&
        (retained?.ambiguous == true || retained?.receipt != null)) {
      attempt = retained;
    }
    loading = actor != null;
    busy = false;
    failed = false;
    knownAdmission = false;
    if (mounted) setState(() {});
    load();
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
              .read(groupContactGatewayProvider)
              .recover(id, action.actionId);
      if (!mounted || !current(id, generation)) return;
      if (receipt != null) {
        ref.read(contactAttemptsProvider.notifier).clear(slot);
        setState(() => attempt = null);
        if (receipt.outcome == 'left') {
          context.go('/messages');
        } else {
          await load();
        }
      }
    } catch (_) {
      if (current(id, generation)) setState(() => failed = true);
    } finally {
      if (current(id, generation)) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    final id = actor;
    final generation = epoch, read = ++revision;
    if (id == null) return;
    try {
      final own = await ref
          .read(groupContactGatewayProvider)
          .hasOwnAdmission(id, widget.chatId);
      if (!current(id, generation) || read != revision) return;
      setState(() => knownAdmission = own);
    } catch (_) {
      if (!current(id, generation) || read != revision) return;
    }
    try {
      final result = await ref
          .read(groupContactGatewayProvider)
          .conversation(id, widget.chatId);
      if (!current(id, generation) || read != revision) return;
      setState(() {
        conversation = result;
        knownAdmission = true;
        loading = false;
        failed = false;
        denied = false;
      });
    } catch (error) {
      if (current(id, generation) && read == revision) {
        setState(() {
          conversation = null;
          loading = false;
          failed = true;
          denied = contactAccessDenied(error);
        });
      }
    }
  }

  Future<void> exit(bool leave) async {
    final id = actor;
    final generation = epoch;
    if (id == null || busy) return;
    final l = AppLocalizations.of(context);
    if (attempt?.ambiguous != true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(leave ? l.contactLeave : l.contactClose),
          content: Text(leave ? l.contactLeaveBody : l.contactCloseBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.groupCancel),
            ),
            FilledButton(
              style: contactFilledButtonStyle,
              key: const Key('contact-confirm-exit'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(leave ? l.contactLeave : l.contactClose),
            ),
          ],
        ),
      );
      if (confirmed != true || !current(id, generation)) return;
    }
    final action = ref
        .read(contactAttemptsProvider.notifier)
        .acquire(slot, id, leave ? 'leave' : 'close', widget.chatId);
    setState(() {
      attempt = action;
      busy = true;
      failed = false;
    });
    try {
      await action.deliver(
        (key) => ref
            .read(groupContactGatewayProvider)
            .exit(id, key, widget.chatId, leave: leave),
      );
      if (!mounted || !current(id, generation)) return;
      ref.read(contactAttemptsProvider.notifier).clear(slot);
      attempt = null;
      ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
      if (leave) {
        context.go('/messages');
        return;
      }
      await load();
    } catch (_) {
      if (current(id, generation)) {
        setState(() => failed = true);
        if (!action.ambiguous) await load();
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
    ref.listen(contactAccessChangesProvider, (_, next) {
      if (next.$1 == actor && mounted) {
        revision++;
        setState(() => conversation = null);
        load();
      }
    });
    final l = AppLocalizations.of(context), c = conversation;
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l.contactAudience)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (c == null) ...[
              Text(denied ? l.contactUnavailable : l.contactFailure),
              TextButton(onPressed: load, child: Text(l.retryAction)),
            ] else ...[
              Text(c.title, style: Theme.of(context).textTheme.titleLarge),
              Text(c.summary),
              GroupContactMuteControl(chatId: c.id),
              if (c.kind == 'bilateral' && !c.readOnly)
                OutlinedButton(
                  key: const Key('contact-coordinate'),
                  onPressed: () => context.push(coordinationComposeRoute(c.id)),
                  child: Text(l.coordinationPropose),
                ),
              if (c.kind == 'coordination')
                TextButton(
                  key: const Key('contact-coordination-context'),
                  onPressed: () async {
                    final id = actor, generation = epoch;
                    if (id == null) return;
                    try {
                      final result = await ref
                          .read(coordinationGatewayProvider)
                          .context(id, c.id);
                      if (!current(id, generation) || !context.mounted) return;
                      if (result == null) {
                        throw const FormatException(
                          'Missing coordination origin.',
                        );
                      }
                      context.push(coordinationProposalRoute(result.id));
                    } catch (_) {
                      if (current(id, generation)) {
                        setState(() => failed = true);
                      }
                    }
                  },
                  child: Text(l.coordinationTitle),
                ),
              const SizedBox(height: 16),
              for (final person in c.audience)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${person.displayName ?? l.contactDeletedPerson} · ${person.groupName}',
                      ),
                      if (!person.active) Text(l.contactUnavailable),
                      if (person.profileId != actor)
                        BlockingActionButton(
                          targetProfileId: person.profileId,
                          targetDisplayName: person.displayName,
                          consequence: BlockingContextConsequence.groupContact,
                          onChanged: (_) => load(),
                        ),
                    ],
                  ),
                ),
              if (c.closedAt == null &&
                  attempt?.ambiguous != true &&
                  attempt?.receipt == null)
                OutlinedButton(
                  key: const Key('contact-close'),
                  onPressed: busy ? null : () => exit(false),
                  child: Text(l.contactClose),
                ),
            ],
            if (attempt?.ambiguous == true || attempt?.receipt != null)
              TextButton(
                onPressed: busy ? null : recover,
                child: Text(l.contactRecover),
              ),
            if (failed && attempt?.ambiguous == true)
              Semantics(
                liveRegion: true,
                child: Text(l.contactDeliveryPending),
              ),
            if (failed && attempt?.ambiguous != true) Text(l.contactFailure),
            if (attempt?.ambiguous == true)
              FilledButton(
                style: contactFilledButtonStyle,
                onPressed: busy
                    ? null
                    : () => exit(attempt!.operation == 'leave'),
                child: Text(l.retryAction),
              )
            else if (attempt?.receipt == null && (c != null || knownAdmission))
              OutlinedButton(
                key: const Key('contact-leave'),
                onPressed: busy ? null : () => exit(true),
                child: Text(l.contactLeave),
              ),
          ],
        ),
      ),
    );
  }
}
