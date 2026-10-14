import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../groups/data/group_gateway.dart';
import '../application/contact_attempt.dart';
import '../application/contact_access_changes.dart';
import '../data/group_contact_gateway.dart';
import '../domain/group_contact_models.dart';
import 'group_contact_routes.dart';

class GroupContactComposeScreen extends ConsumerStatefulWidget {
  const GroupContactComposeScreen({
    required this.groupId,
    this.projectId,
    this.purpose,
    super.key,
  });
  final String groupId;
  final String? projectId, purpose;
  @override
  ConsumerState<GroupContactComposeScreen> createState() =>
      _GroupContactComposeScreenState();
}

class _GroupContactComposeScreenState
    extends ConsumerState<GroupContactComposeScreen> {
  final title = TextEditingController(), note = TextEditingController();
  String? actor, targetName, source, senderName;
  List<ContactGroup> groups = [];
  ContactGroup? lastGroup;
  GroupContactPurpose purpose = GroupContactPurpose.idea;
  bool loading = true,
      busy = false,
      hasMore = false,
      selfContact = false,
      unavailable = false;
  String? failure;
  int epoch = 0;
  ContactAttempt? attempt;
  String get slot => 'compose/${widget.groupId}/${widget.projectId ?? ''}';
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(bind);
  }

  @override
  void dispose() {
    epoch++;
    title.dispose();
    note.dispose();
    super.dispose();
  }

  bool current(String id, int generation) =>
      mounted &&
      generation == epoch &&
      actor == id &&
      ref.read(authSessionProvider).identity?.id == id;
  void bind() {
    final session = ref.read(authSessionProvider);
    actor = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    epoch++;
    loading = actor != null;
    busy = false;
    groups = [];
    lastGroup = null;
    hasMore = false;
    targetName = null;
    senderName = null;
    source = null;
    failure = null;
    unavailable = false;
    selfContact = false;
    attempt = null;
    title.clear();
    note.clear();
    purpose = widget.purpose == null
        ? GroupContactPurpose.idea
        : GroupContactPurpose.parse(widget.purpose);
    final retained = ref.read(contactAttemptsProvider)[slot];
    if (retained?.actor == actor &&
        (retained?.ambiguous == true || retained?.receipt != null)) {
      attempt = retained;
      final intent =
          retained!.intent
              as (String, String, GroupContactPurpose, String, String, String?);
      source = intent.$1;
      purpose = intent.$3;
      title.text = intent.$4;
      note.text = intent.$5;
    }
    if (mounted) setState(() {});
    final id = actor;
    if (id != null) load(id, epoch);
  }

  Future<void> load(String id, int generation) async {
    try {
      final gateway = ref.read(groupContactGatewayProvider);
      final sender = await gateway.senderName(id);
      final target = await GroupGateway(gateway.call)
          .publicDetail(widget.groupId);
      final role = await gateway.targetRole(id, widget.groupId);
      final page = target != null && role == null
          ? await gateway.groups(id)
          : const <ContactGroup>[];
      if (!mounted || !current(id, generation)) return;
      setState(() {
        loading = false;
        senderName = sender;
        targetName = target?.content.name;
        unavailable = target == null;
        selfContact = role != null;
        groups = page
            .take(contactPageSize)
            .where((g) => g.id != widget.groupId)
            .toList();
        if (attempt == null && !groups.any((g) => g.id == source)) {
          source = null;
        }
        lastGroup = page.length > contactPageSize
            ? page[contactPageSize - 1]
            : null;
        hasMore = page.length > contactPageSize;
      });
    } catch (_) {
      if (current(id, generation)) {
        setState(() {
          loading = false;
          failure = AppLocalizations.of(context).contactFailure;
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
              .read(groupContactGatewayProvider)
              .recover(id, action.actionId);
      if (!mounted || !current(id, generation)) return;
      if (receipt != null) {
        ref.read(contactAttemptsProvider.notifier).clear(slot);
        title.clear();
        note.clear();
        context.go(groupContactRequestRoute(receipt.requestId!));
      }
    } catch (_) {
      if (current(id, generation)) {
        setState(() => failure = AppLocalizations.of(context).contactFailure);
      }
    } finally {
      if (current(id, generation)) setState(() => busy = false);
    }
  }

  Future<void> more() async {
    final id = actor, after = lastGroup;
    final generation = epoch;
    if (id == null || after == null || busy) return;
    setState(() => busy = true);
    try {
      final page = await ref
          .read(groupContactGatewayProvider)
          .groups(id, after: after);
      if (!current(id, generation)) return;
      setState(() {
        busy = false;
        groups = [
          ...groups,
          ...page.take(contactPageSize).where((g) => g.id != widget.groupId),
        ];
        lastGroup = page.length > contactPageSize
            ? page[contactPageSize - 1]
            : null;
        hasMore = page.length > contactPageSize;
      });
    } catch (_) {
      if (current(id, generation)) {
        setState(() {
          busy = false;
          failure = AppLocalizations.of(context).contactFailure;
        });
      }
    }
  }

  Future<void> submit() async {
    final id = actor, group = source;
    final generation = epoch;
    final l = AppLocalizations.of(context);
    if (id == null || group == null || busy) return;
    if (title.text.trim().isEmpty ||
        title.text.runes.length > 120 ||
        note.text.trim().isEmpty ||
        note.text.runes.length > 1000) {
      setState(() => failure = l.contactInvalid);
      return;
    }
    final intent = (
      group,
      widget.groupId,
      purpose,
      title.text,
      note.text,
      widget.projectId,
    );
    final action = ref
        .read(contactAttemptsProvider.notifier)
        .acquire(slot, id, 'submit', intent);
    setState(() {
      attempt = action;
      busy = true;
      failure = null;
    });
    try {
      final receipt = await action.deliver(
        (key) => ref
            .read(groupContactGatewayProvider)
            .submit(
              id,
              key,
              group,
              widget.groupId,
              purpose,
              intent.$4,
              intent.$5,
              project: widget.projectId,
            ),
      );
      if (!mounted || !current(id, generation)) return;
      ref.read(contactAttemptsProvider.notifier).clear(slot);
      title.clear();
      note.clear();
      context.go(groupContactRequestRoute(receipt.requestId!));
    } catch (_) {
      if (current(id, generation)) {
        setState(() {
          busy = false;
          failure = action.ambiguous
              ? l.contactDeliveryPending
              : l.contactFailure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authSessionProvider.select((s) => (s.identity?.id, s.phase)),
      (_, _) => bind(),
    );
    ref.listen(contactAccessChangesProvider, (_, next) {
      final id = actor;
      if (id != null && next.$1 == id && mounted) {
        epoch++;
        setState(() {
          loading = true;
          busy = false;
          groups = [];
          hasMore = false;
          lastGroup = null;
          targetName = null;
          senderName = null;
        });
        load(id, epoch);
      }
    });
    final l = AppLocalizations.of(context);
    final frozen =
        busy || attempt?.ambiguous == true || attempt?.receipt != null;
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l.contactTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (attempt?.ambiguous == true || attempt?.receipt != null) ...[
              Text(
                attempt?.receipt != null
                    ? l.contactConfirmed
                    : l.contactDeliveryPending,
              ),
              TextButton(
                key: const Key('contact-recover-submit'),
                onPressed: busy ? null : recover,
                child: Text(l.contactRecover),
              ),
            ],
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (unavailable || selfContact) ...[
              Text(selfContact ? l.contactOwnRepresentation : l.contactFailure),
              TextButton(onPressed: bind, child: Text(l.contactRefresh)),
            ] else if (groups.isEmpty && !hasMore) ...[
              Text(failure ?? l.contactNoGroup),
              TextButton(onPressed: bind, child: Text(l.contactRefresh)),
            ] else ...[
              Text(
                targetName ?? l.contactTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(l.contactSender(senderName!)),
              const SizedBox(height: 8),
              Text(l.contactReadership),
              const SizedBox(height: 16),
              Text(l.contactSource),
              RadioGroup<String>(
                groupValue: source,
                onChanged: (value) {
                  if (!frozen) setState(() => source = value);
                },
                child: Column(
                  children: [
                    for (final group in groups)
                      RadioListTile<String>(
                        title: Text(group.name),
                        value: group.id,
                        enabled: !frozen,
                      ),
                  ],
                ),
              ),
              if (hasMore)
                TextButton(
                  onPressed: frozen ? null : more,
                  child: Text(l.contactMoreGroups),
                ),
              const SizedBox(height: 16),
              Text(l.contactPurpose),
              DropdownButtonFormField<GroupContactPurpose>(
                itemHeight: null,
                initialValue: purpose,
                isExpanded: true,
                onChanged: frozen
                    ? null
                    : (value) => setState(() => purpose = value!),
                items: [
                  DropdownMenuItem(
                    value: GroupContactPurpose.idea,
                    child: Text(l.contactIdeaAction, softWrap: true),
                  ),
                  DropdownMenuItem(
                    value: GroupContactPurpose.collaboration,
                    child: Text(l.contactCollaborationAction, softWrap: true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('contact-title'),
                controller: title,
                enabled: !frozen,
                decoration: InputDecoration(labelText: l.contactSubject),
                maxLength: 120,
              ),
              TextField(
                key: const Key('contact-note'),
                controller: note,
                enabled: !frozen,
                decoration: InputDecoration(labelText: l.contactNote),
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
              ),
              if (widget.projectId != null) Text(l.contactSavedReference),
              if (failure != null)
                Semantics(liveRegion: true, child: Text(failure!)),
              FilledButton(
                key: const Key('contact-submit'),
                onPressed: busy || source == null || attempt?.receipt != null
                    ? null
                    : submit,
                child: Text(
                  busy
                      ? l.contactSending
                      : attempt?.ambiguous == true
                      ? l.retryAction
                      : l.contactSend,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
