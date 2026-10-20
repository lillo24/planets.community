import 'dart:convert';

import 'package:flutter/material.dart';

import '../../group_contact/presentation/contact_button_style.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../blocking/presentation/blocking_action.dart';
import '../../group_contact/application/contact_attempt.dart';
import '../../group_contact/application/contact_access_changes.dart';
import '../../group_contact/data/group_contact_gateway.dart';
import '../../group_contact/domain/group_contact_models.dart';
import '../../group_contact/presentation/group_contact_routes.dart';
import '../../messages/application/message_chats_refresh.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../data/coordination_gateway.dart';
import '../domain/coordination_models.dart';
import 'coordination_group_picker.dart';
import 'coordination_routes.dart';

class CoordinationScreen extends ConsumerStatefulWidget {
  const CoordinationScreen({this.proposalId, this.sourceChatId, super.key})
    : assert((proposalId == null) != (sourceChatId == null));
  final String? proposalId, sourceChatId;
  @override
  ConsumerState<CoordinationScreen> createState() => _CoordinationScreenState();
}

class _CoordinationScreenState extends ConsumerState<CoordinationScreen>
    with WidgetsBindingObserver {
  final title = TextEditingController(), note = TextEditingController();
  Map<String, String> selected = {};
  CoordinationProposal? proposal;
  GroupContactConversation? source;
  ContactAttempt? attempt;
  String? actor, knownPeer;
  BuildContext? confirmationContext;
  bool loading = true,
      busy = false,
      failed = false,
      denied = false,
      knownNote = false;
  int epoch = 0, revision = 0;
  String get slot =>
      'coordination/${widget.proposalId ?? 'new/${widget.sourceChatId}'}';
  bool current(String id, int generation) =>
      mounted &&
      epoch == generation &&
      actor == id &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == id;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(bind);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    title.dispose();
    note.dispose();
    super.dispose();
  }

  void bind() {
    dismissConfirmation();
    final s = ref.read(authSessionProvider);
    actor = s.phase == AuthSessionPhase.ready ? s.identity?.id : null;
    epoch++;
    revision++;
    source = null;
    proposal = null;
    knownPeer = null;
    knownNote = false;
    title.clear();
    note.clear();
    selected = {};
    busy = false;
    failed = false;
    denied = false;
    final retained = ref.read(contactAttemptsProvider)[slot];
    attempt = retained?.actor == actor ? retained : null;
    loading = actor != null;
    if (mounted) setState(() {});
    load();
  }

  void clearAccess() {
    dismissConfirmation();
    epoch++;
    revision++;
    source = null;
    proposal = null;
    busy = false;
    loading = true;
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load();
    } else {
      clearAccess();
    }
  }

  Future<void> load() async {
    final id = actor, generation = epoch, read = ++revision;
    if (id == null) return;
    try {
      if (widget.proposalId case final String target) {
        final result = await ref
            .read(coordinationGatewayProvider)
            .proposal(id, target);
        if (!current(id, generation) || read != revision) return;
        setState(() {
          proposal = result;
          denied = false;
          loading = false;
          failed = false;
          if (result.note != null && result.initiatorId != id) {
            knownNote = true;
            knownPeer = result.initiatorId;
          }
        });
      } else {
        final result = await ref
            .read(groupContactGatewayProvider)
            .conversation(id, widget.sourceChatId!);
        if (!current(id, generation) || read != revision) return;
        setState(() {
          source = result.kind == 'bilateral' && !result.readOnly
              ? result
              : null;
          denied = source == null;
          loading = false;
          failed = false;
        });
      }
    } catch (error) {
      if (current(id, generation) && read == revision) {
        setState(() {
          source = null;
          proposal = null;
          denied = contactAccessDenied(error);
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<bool> confirm(String body) async {
    final l = AppLocalizations.of(context);
    try {
      return await showDialog<bool>(
            context: context,
            builder: (context) {
              confirmationContext = context;
              return AlertDialog(
                title: Text(l.coordinationTitle),
                content: SingleChildScrollView(child: Text(body)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.groupCancel),
                  ),
                  FilledButton(
                    style: contactFilledButtonStyle,
                    key: const Key('coordination-confirm-dialog'),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l.coordinationAgree),
                  ),
                ],
              );
            },
          ) ==
          true;
    } finally {
      confirmationContext = null;
    }
  }

  void dismissConfirmation() {
    final dialog = confirmationContext;
    if (dialog != null &&
        dialog.mounted &&
        ModalRoute.of(dialog)?.isCurrent == true) {
      Navigator.of(dialog).pop();
    }
    confirmationContext = null;
  }

  Future<void> choose({bool replace = false}) async {
    final id = actor, generation = epoch, p = proposal;
    if (id == null || busy || attempt?.ambiguous == true) return;
    final excluded =
        source?.audience.map((a) => a.groupId).toSet() ?? <String>{};
    // On replacement the server preserves the two original seats; selected
    // additional groups are revalidated canonically with the expected version.
    final groups = await chooseCoordinationGroups(
      context,
      replace ? <String>{} : excluded,
    );
    if (groups == null || !current(id, generation)) return;
    if (replace && p != null) {
      await command('targets', groups: groups.keys.toList()..sort());
    } else {
      setState(() => selected = groups);
    }
  }

  Future<void> command(
    String operation, {
    String? group,
    List<String>? groups,
  }) async {
    final id = actor,
        generation = epoch,
        p = proposal,
        l = AppLocalizations.of(context);
    if (id == null || busy) return;
    if (attempt?.ambiguous != true) {
      final body = switch (operation) {
        'propose' => l.coordinationInvitationDisclosure,
        'claim' => l.coordinationClaimDisclosure,
        'confirm' =>
          '${l.coordinationConfirmDisclosure}\n\n${p?.audience.map((a) => '${a.person.displayName ?? l.contactDeletedPerson} · ${a.person.groupName}').join('\n') ?? ''}',
        'targets' => l.coordinationChangeDisclosure,
        'cancel' => l.coordinationCancelDisclosure,
        'decline' => l.coordinationDeclineDisclosure,
        _ => throw StateError('Unsupported coordination command.'),
      };
      if (!await confirm(body) || !current(id, generation)) return;
    }
    final intent = attempt?.ambiguous == true
        ? attempt!.intent as String
        : jsonEncode({
            'id': widget.proposalId ?? widget.sourceChatId,
            'version': p?.version,
            'group': group,
            'groups': groups ?? (selected.keys.toList()..sort()),
            'title': title.text,
            'note': note.text,
          });
    final action = ref
        .read(contactAttemptsProvider.notifier)
        .acquire(slot, id, operation, intent);
    setState(() {
      attempt = action;
      busy = true;
      failed = false;
    });
    final frozen = jsonDecode(intent) as Map<String, dynamic>;
    try {
      final receipt = await action.deliver(
        (key) => operation == 'propose'
            ? ref
                  .read(coordinationGatewayProvider)
                  .submit(
                    id,
                    key,
                    frozen['id'] as String,
                    (frozen['groups'] as List).cast<String>(),
                    frozen['title'] as String,
                    frozen['note'] as String,
                  )
            : ref
                  .read(coordinationGatewayProvider)
                  .decide(
                    id,
                    key,
                    frozen['id'] as String,
                    frozen['version'] as int,
                    operation,
                    group: frozen['group'] as String?,
                    groups: (frozen['groups'] as List).cast<String>(),
                  ),
      );
      if (current(id, generation)) await finish(receipt);
    } catch (_) {
      if (current(id, generation)) {
        setState(() => failed = true);
        if (!action.ambiguous) await load();
      }
    } finally {
      if (current(id, generation)) setState(() => busy = false);
    }
  }

  Future<void> finish(ContactReceipt receipt) async {
    if (receipt.coordinationId == null ||
        widget.proposalId != null &&
            receipt.coordinationId != widget.proposalId) {
      throw const FormatException('Mismatched coordination receipt.');
    }
    ref.read(contactAttemptsProvider.notifier).clear(slot);
    attempt = null;
    ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
    if (widget.proposalId == null) {
      context.go(coordinationProposalRoute(receipt.coordinationId!));
    } else {
      await load();
    }
  }

  Future<void> recover() async {
    final id = actor, a = attempt, generation = epoch;
    if (id == null || a == null || busy) return;
    setState(() => busy = true);
    try {
      final receipt =
          a.receipt ??
          await ref.read(groupContactGatewayProvider).recover(id, a.actionId);
      if (!current(id, generation)) return;
      if (receipt != null) {
        await finish(receipt);
      } else {
        setState(() => failed = true);
      }
    } catch (_) {
      if (current(id, generation)) setState(() => failed = true);
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
      if (next.$1 == actor) {
        clearAccess();
        load();
      }
    });
    final l = AppLocalizations.of(context),
        p = proposal,
        frozen = attempt?.ambiguous == true || attempt?.receipt != null;
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l.coordinationTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (widget.proposalId == null && source != null) ...[
              Text(l.coordinationFreshHistory),
              Text(l.coordinationInvitationDisclosure),
              for (final person in source!.audience)
                Text(
                  '${person.displayName ?? l.contactDeletedPerson} · ${person.groupName}',
                ),
              TextButton(
                key: const Key('coordination-pick'),
                onPressed: frozen || busy ? null : choose,
                child: Text(l.coordinationChooseGroups),
              ),
              for (final name in selected.values) Text(name),
              TextField(
                key: const Key('coordination-title'),
                controller: title,
                enabled: !frozen && !busy,
                maxLength: 120,
                decoration: InputDecoration(labelText: l.contactSubject),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                key: const Key('coordination-note'),
                controller: note,
                enabled: !frozen && !busy,
                minLines: 3,
                maxLines: 8,
                maxLength: 1000,
                decoration: InputDecoration(labelText: l.contactNote),
                onChanged: (_) => setState(() {}),
              ),
              FilledButton(
                style: contactFilledButtonStyle,
                key: const Key('coordination-propose'),
                onPressed:
                    frozen ||
                        busy ||
                        selected.isEmpty ||
                        title.text.trim().isEmpty ||
                        note.text.trim().isEmpty
                    ? null
                    : () => command('propose'),
                child: Text(l.coordinationPropose),
              ),
            ] else if (p != null) ...[
              Text(
                p.title ?? l.coordinationTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(coordinationStatus(l, p.status)),
              Text(p.note ?? l.contactRequestMetadata),
              if (p.initiatorName != null) Text(p.initiatorName!),
              if (p.note != null) Text(l.coordinationFreshHistory),
              for (final g in p.groups)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${g.name} · ${g.claimed ? l.coordinationSeatNamed : l.coordinationSeatWaiting}',
                  ),
                ),
              if (!p.audienceDisclosed && p.note != null)
                Text(l.coordinationAudienceWithheld),
              for (final a in p.audience)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${a.person.displayName ?? l.contactDeletedPerson} · ${a.person.groupName}\n${a.confirmed ? l.coordinationConfirmed : l.coordinationAwaitingConfirmation}',
                  ),
                ),
              if (!frozen) ...[
                for (final id in p.claimableGroupIds)
                  OutlinedButton(
                    key: Key('coordination-claim-$id'),
                    onPressed: busy ? null : () => command('claim', group: id),
                    child: Text(
                      l.coordinationClaimGroup(
                        p.groups.firstWhere((g) => g.id == id).name,
                      ),
                    ),
                  ),
                if (p.canConfirm)
                  FilledButton(
                    style: contactFilledButtonStyle,
                    key: const Key('coordination-confirm'),
                    onPressed: busy ? null : () => command('confirm'),
                    child: Text(l.coordinationConfirm),
                  ),
                if (p.canChangeAudience)
                  OutlinedButton(
                    key: const Key('coordination-change'),
                    onPressed: busy ? null : () => choose(replace: true),
                    child: Text(l.coordinationChangeAudience),
                  ),
                if (p.canCancel)
                  OutlinedButton(
                    key: const Key('coordination-cancel'),
                    onPressed: busy ? null : () => command('cancel'),
                    child: Text(l.coordinationCancel),
                  ),
                if (p.canDecline)
                  OutlinedButton(
                    key: const Key('coordination-decline'),
                    onPressed: busy ? null : () => command('decline'),
                    child: Text(l.contactDecline),
                  ),
              ],
              if (p.chatId case final String chat)
                FilledButton(
                  style: contactFilledButtonStyle,
                  key: const Key('coordination-open'),
                  onPressed: () => context.push(groupContactChatRoute(chat)),
                  child: Text(l.contactOpen),
                ),
              if (p.sourceChatId case final String chat)
                TextButton(
                  onPressed: () => context.push(groupContactChatRoute(chat)),
                  child: Text(l.coordinationSource),
                ),
            ] else ...[
              Text(denied ? l.contactUnavailable : l.contactFailure),
              TextButton(onPressed: load, child: Text(l.retryAction)),
            ],
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
                key: const Key('coordination-retry'),
                onPressed: busy ? null : () => command(attempt!.operation),
                child: Text(l.retryAction),
              ),
            if (frozen)
              TextButton(
                key: const Key('coordination-recover'),
                onPressed: busy ? null : recover,
                child: Text(l.contactRecover),
              ),
            if (knownNote)
              OutlinedButton.icon(
                onPressed: () => ModerationRoutes.openReport(
                  context,
                  ModerationReportTarget(
                    kind: ModerationTargetKind.groupCoordinationProposal,
                    id: widget.proposalId!,
                    label: l.coordinationReport,
                  ),
                ),
                icon: const Icon(Icons.flag_outlined),
                label: Text(l.coordinationReport),
              ),
            if (knownPeer case final String person)
              BlockingActionButton(
                targetProfileId: person,
                consequence: BlockingContextConsequence.pendingRequest,
                onChanged: (_) => load(),
              ),
          ],
        ),
      ),
    );
  }
}
