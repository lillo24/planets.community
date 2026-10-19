import '../application/member_contact_drafts.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../group_contact/presentation/contact_button_style.dart';

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
import '../application/member_contact_attempt.dart';
import '../application/member_contact_access_changes.dart';
import '../data/member_contact_gateway.dart';
import '../../group_contact/data/group_contact_gateway.dart'
    show contactAccessDenied;
import '../domain/member_contact_models.dart';
import 'member_contact_routes.dart';

class MemberContactChatScreen extends ConsumerStatefulWidget {
  const MemberContactChatScreen({required this.chatId, super.key});
  final String chatId;
  @override
  ConsumerState<MemberContactChatScreen> createState() =>
      _MemberContactChatScreenState();
}

class _MemberContactChatScreenState
    extends ConsumerState<MemberContactChatScreen>
    with WidgetsBindingObserver {
  final scroll = ScrollController(), body = TextEditingController();
  String? actor, boundary, knownReport;
  MemberContactConversation? conversation;
  List<MemberContactMessage> items = [];
  MemberContactAttempt? attempt;
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
    body.text = ref.read(memberContactDraftsProvider)[slot] ?? '';
    final retained = ref.read(memberContactAttemptsProvider)[slot];
    if (retained?.actor == actor &&
        (retained?.ambiguous == true || retained?.receipt != null)) {
      attempt = retained;
      body.text = (retained!.intent as (String, String)).$2;
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
      final gateway = ref.read(memberContactGatewayProvider);
      final received = await gateway.conversation(id, widget.chatId);
      final page = await gateway.feed(id, widget.chatId);
      if (!current(id, generation) || read != revision) return;
      final overlap =
          items.isNotEmpty &&
          (page.items.isEmpty ||
              page.items.first.ordinal <= items.last.ordinal + 1);
      final merged = <String, MemberContactMessage>{
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
          .read(memberContactGatewayProvider)
          .feed(id, widget.chatId, before: before);
      if (!current(id, generation) || read != revision) return;
      final merged = <String, MemberContactMessage>{
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
    final episode = attempt?.ambiguous == true
        ? (attempt!.intent as (String, String)).$1
        : conversation?.episodeId;
    if (episode == null) return;
    if (submitted.trim().isEmpty || submitted.runes.length > 4000) return;
    final action = ref.read(memberContactAttemptsProvider.notifier).acquire(
      slot,
      id,
      'send',
      (episode, submitted),
    );
    setState(() {
      attempt = action;
      sending = true;
      sendFailed = false;
    });
    try {
      await action.deliver(
        (key) => ref
            .read(memberContactGatewayProvider)
            .send(id, key, widget.chatId, episode, submitted),
      );
      if (!current(id, generation)) return;
      ref.read(memberContactAttemptsProvider.notifier).clear(slot);
      attempt = null;
      body.clear();
      ref.read(memberContactDraftsProvider.notifier).clear(slot);
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
              .read(memberContactGatewayProvider)
              .recover(id, action.actionId);
      if (!current(id, generation)) return;
      if (receipt != null) {
        ref.read(memberContactAttemptsProvider.notifier).clear(slot);
        setState(() {
          attempt = null;
          sendFailed = false;
          body.clear();
          ref.read(memberContactDraftsProvider.notifier).clear(slot);
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
      kind: ModerationTargetKind.memberContactMessage,
      contextKind: ModerationContextKind.memberContactChat,
      contextId: widget.chatId,
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
    ref.listen(memberContactAccessChangesProvider, (_, next) {
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
        title: Text(c?.peerName ?? l.memberContactTitle),
        actions: [
          IconButton(
            key: const Key('contact-chat-info'),
            tooltip: l.memberContactInfo,
            icon: const Icon(Icons.info_outline),
            onPressed: () =>
                context.push(memberContactInfoRoute(widget.chatId)),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              // The keyboard and large text can consume most of the body. Bound
              // both contextual notices and the composer so history stays visible;
              // scroll their full content instead of clipping consent/recovery text.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight / 4,
                ),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (loading) const LinearProgressIndicator(),
                      if (c == null && !loading)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                denied
                                    ? l.contactUnavailable
                                    : l.contactFailure,
                              ),
                              TextButton(
                                onPressed: load,
                                child: Text(l.retryAction),
                              ),
                              if (knownReport case final String message)
                                TextButton(
                                  onPressed: () => report(message),
                                  child: Text(l.contactKnownReport),
                                ),
                            ],
                          ),
                        ),
                      if (c != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(l.memberContactOrigin(c.groupName)),
                        ),
                      if (c != null && c.readOnly)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(l.memberContactReadOnly),
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
                    ],
                  ),
                ),
              ),
              Expanded(
                child: MessageReadViewport(
                  profileId: actor,
                  kind: 'member_contact_chat',
                  chatId: c?.id,
                  boundary: c == null ? null : boundary,
                  scrollController: scroll,
                  child: ConversationHistoryList<MemberContactMessage>(
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
                      final name = m.senderName;
                      return Card(
                        key: Key('contact-human-${m.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
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
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight / 2,
                  ),
                  child: SingleChildScrollView(
                    key: const Key('member-contact-composer-scroll'),
                    primary: false,
                    child: Padding(
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
                            onChanged: (text) => ref
                                .read(memberContactDraftsProvider.notifier)
                                .save(slot, text),
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
                              style: contactFilledButtonStyle,
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
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
