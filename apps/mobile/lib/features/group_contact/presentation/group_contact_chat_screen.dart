import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../messages/application/message_chats_refresh.dart';
import '../../messages/presentation/conversation_history_list.dart';
import '../../messages/presentation/message_read_viewport.dart';
import '../../messages/presentation/messages_formatters.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../application/contact_attempt.dart';
import '../application/contact_access_changes.dart';
import '../data/group_contact_gateway.dart';
import '../domain/group_contact_models.dart';
import 'group_contact_routes.dart';

class GroupContactChatScreen extends ConsumerStatefulWidget {
  const GroupContactChatScreen({required this.chatId, super.key});
  final String chatId;
  @override
  ConsumerState<GroupContactChatScreen> createState() =>
      _GroupContactChatScreenState();
}

class _GroupContactChatScreenState extends ConsumerState<GroupContactChatScreen>
    with WidgetsBindingObserver {
  final scroll = ScrollController(), body = TextEditingController();
  String? actor, boundary, knownReport;
  GroupContactConversation? conversation;
  List<ContactHumanMessage> items = [];
  ContactAttempt? attempt;
  bool loading = true,
      loadingOlder = false,
      hasMore = false,
      failed = false,
      denied = false,
      sendFailed = false,
      olderFailed = false,
      sending = false;
  int epoch = 0, revision = 0;
  String get slot => 'chat/${widget.chatId}/send';
  bool current(String id, int generation) =>
      mounted &&
      epoch == generation &&
      actor == id &&
      ref.read(authSessionProvider).identity?.id == id;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(bind);
  }

  @override
  void dispose() {
    epoch++;
    WidgetsBinding.instance.removeObserver(this);
    scroll.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  void bind() {
    final s = ref.read(authSessionProvider);
    actor = s.phase == AuthSessionPhase.ready ? s.identity?.id : null;
    epoch++;
    revision++;
    conversation = null;
    items = [];
    boundary = null;
    knownReport = null;
    failed = false;
    denied = false;
    sendFailed = false;
    olderFailed = false;
    hasMore = false;
    loading = actor != null;
    loadingOlder = false;
    sending = false;
    attempt = null;
    body.clear();
    final retained = ref.read(contactAttemptsProvider)[slot];
    if (retained?.actor == actor &&
        (retained?.ambiguous == true || retained?.receipt != null)) {
      attempt = retained;
      body.text = retained!.intent as String;
    }
    if (mounted) setState(() {});
    load();
  }

  Future<void> load() async {
    final id = actor;
    final generation = epoch, read = ++revision;
    if (id == null) return;
    final follow =
        items.isEmpty ||
        (scroll.hasClients &&
            scroll.position.hasContentDimensions &&
            scroll.position.extentAfter <= 1);
    try {
      final gateway = ref.read(groupContactGatewayProvider);
      final received = await gateway.conversation(id, widget.chatId);
      final page = await gateway.feed(id, widget.chatId);
      if (!current(id, generation) || read != revision) return;
      final overlap =
          items.isNotEmpty &&
          (page.items.isEmpty ||
              page.items.first.ordinal <= items.last.ordinal + 1);
      final merged = <String, ContactHumanMessage>{
        if (overlap)
          for (final item in items) item.id: item,
        for (final item in page.items) item.id: item,
      }.values.toList()..sort((a, b) => a.ordinal.compareTo(b.ordinal));
      setState(() {
        conversation = received;
        items = merged;
        boundary = page.boundary;
        loading = false;
        loadingOlder = false;
        olderFailed = false;
        failed = false;
        denied = false;
        hasMore = overlap ? hasMore : page.hasMore;
        final incoming = items.where((m) => m.senderId != id);
        if (incoming.isNotEmpty) knownReport = incoming.last.id;
      });
      if (follow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (current(id, generation) &&
              ModalRoute.of(context)?.isCurrent == true &&
              scroll.hasClients &&
              scroll.position.hasContentDimensions) {
            scroll.jumpTo(scroll.position.maxScrollExtent);
          }
        });
      }
    } catch (error) {
      if (current(id, generation) && read == revision) {
        setState(() {
          loading = false;
          failed = true;
          denied = contactAccessDenied(error);
          conversation = null;
          items = [];
          boundary = null;
          hasMore = false;
        });
      }
    }
  }

  Future<void> older() async {
    final id = actor;
    final generation = epoch, read = revision;
    if (id == null || items.isEmpty || loadingOlder || !hasMore) return;
    final before = items.first;
    setState(() {
      loadingOlder = true;
      olderFailed = false;
    });
    try {
      final page = await ref
          .read(groupContactGatewayProvider)
          .feed(id, widget.chatId, before: before);
      if (!current(id, generation) || read != revision) return;
      final merged = <String, ContactHumanMessage>{
        for (final item in page.items) item.id: item,
        for (final item in items) item.id: item,
      }.values.toList()..sort((a, b) => a.ordinal.compareTo(b.ordinal));
      setState(() {
        items = merged;
        hasMore = page.hasMore;
        loadingOlder = false;
      });
    } catch (_) {
      if (current(id, generation) && read == revision) {
        setState(() {
          loadingOlder = false;
          olderFailed = true;
        });
      }
    }
  }

  Future<void> send() async {
    final id = actor;
    final generation = epoch;
    if (id == null || sending || conversation?.readOnly != false) return;
    final submitted = body.text;
    if (submitted.trim().isEmpty || submitted.runes.length > 4000) return;
    final action = ref
        .read(contactAttemptsProvider.notifier)
        .acquire(slot, id, 'send', submitted);
    setState(() {
      attempt = action;
      sending = true;
      sendFailed = false;
    });
    try {
      await action.deliver(
        (key) => ref
            .read(groupContactGatewayProvider)
            .send(id, key, widget.chatId, submitted),
      );
      if (!current(id, generation)) return;
      ref.read(contactAttemptsProvider.notifier).clear(slot);
      attempt = null;
      body.clear();
      await load();
    } catch (_) {
      if (current(id, generation)) {
        setState(() => sendFailed = true);
        if (!action.ambiguous) await load();
      }
    } finally {
      if (current(id, generation)) setState(() => sending = false);
    }
  }

  Future<void> recover() async {
    final id = actor, action = attempt;
    final generation = epoch;
    if (id == null || action == null || sending) return;
    setState(() => sending = true);
    try {
      final receipt =
          action.receipt ??
          await ref
              .read(groupContactGatewayProvider)
              .recover(id, action.actionId);
      if (!current(id, generation)) return;
      if (receipt != null) {
        ref.read(contactAttemptsProvider.notifier).clear(slot);
        setState(() {
          attempt = null;
          sendFailed = false;
          body.clear();
        });
        await load();
      }
    } catch (_) {
      if (current(id, generation)) setState(() => sendFailed = true);
    } finally {
      if (current(id, generation)) setState(() => sending = false);
    }
  }

  void report(String message) => ModerationRoutes.openReport(
    context,
    ModerationReportTarget(
      kind: ModerationTargetKind.groupContactMessage,
      id: message,
      label: AppLocalizations.of(context).contactMessageReport,
    ),
  );
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
        setState(() {
          conversation = null;
          items = [];
          boundary = null;
          hasMore = false;
        });
        load();
      }
    });
    final l = AppLocalizations.of(context), c = conversation;
    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(c?.title ?? l.contactConversationLabel),
        actions: [
          IconButton(
            key: const Key('contact-chat-info'),
            tooltip: l.contactAudience,
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(groupContactInfoRoute(widget.chatId)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (loading) const LinearProgressIndicator(),
            if (c == null && !loading)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(denied ? l.contactUnavailable : l.contactFailure),
                    TextButton(onPressed: load, child: Text(l.retryAction)),
                    if (knownReport case final String message)
                      TextButton(
                        onPressed: () => report(message),
                        child: Text(l.contactKnownReport),
                      ),
                  ],
                ),
              ),
            if (c != null && c.readOnly)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(l.contactReadOnly),
              ),
            if (attempt != null &&
                (c == null || c.readOnly || attempt!.receipt != null))
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(l.contactDeliveryPending),
                    TextButton(
                      key: const Key('contact-recover-send'),
                      onPressed: sending ? null : recover,
                      child: Text(l.contactRecover),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: MessageReadViewport(
                profileId: actor,
                kind: 'group_contact_chat',
                chatId: c?.id,
                boundary: c == null ? null : boundary,
                scrollController: scroll,
                child: ConversationHistoryList<ContactHumanMessage>(
                  key: ValueKey((widget.chatId, actor, epoch)),
                  items: items,
                  itemKey: (m) => m.id,
                  controller: scroll,
                  enabled: c != null,
                  hasMore: hasMore,
                  loading: loadingOlder,
                  failed: olderFailed,
                  onLoadOlder: older,
                  fallbackLabel: l.projectChatLoadOlder,
                  buttonKey: const Key('contact-history-more'),
                  empty: Center(
                    child: Text(c == null ? '' : l.projectChatNoMessages),
                  ),
                  itemBuilder: (context, m) {
                    final people = c?.audience.where(
                      (p) => p.profileId == m.senderId,
                    );
                    final name = people == null || people.isEmpty
                        ? l.contactDeletedPerson
                        : people.first.displayName ?? l.contactDeletedPerson;
                    return Card(
                      key: Key('contact-human-${m.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$name · ${m.groupName}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Text(m.body),
                            Text(
                              messageDate(context, m.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (m.senderId != actor)
                              TextButton.icon(
                                onPressed: () => report(m.id),
                                icon: const Icon(Icons.flag_outlined),
                                label: Text(l.contactMessageReport),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (c != null && !c.readOnly)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sendFailed && attempt?.ambiguous != true)
                      Semantics(
                        liveRegion: true,
                        child: Text(l.contactFailure),
                      ),
                    if (attempt?.ambiguous == true)
                      Semantics(
                        liveRegion: true,
                        child: Text(l.contactDeliveryPending),
                      ),
                    if (attempt?.ambiguous == true)
                      TextButton(
                        onPressed: sending ? null : recover,
                        child: Text(l.contactRecover),
                      ),
                    TextField(
                      key: const Key('contact-message-body'),
                      controller: body,
                      enabled: !sending && attempt?.ambiguous != true,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l.contactMessageHint,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        key: const Key('contact-message-send'),
                        onPressed: sending ? null : send,
                        icon: const Icon(Icons.send_outlined),
                        label: Text(
                          sending
                              ? l.contactSending
                              : attempt?.ambiguous == true
                              ? l.retryAction
                              : l.contactMessageSend,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
