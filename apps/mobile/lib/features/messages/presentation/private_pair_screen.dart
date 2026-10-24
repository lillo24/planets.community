import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../blocking/presentation/blocking_action.dart';
import '../../member_contact/presentation/member_contact_routes.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../application/message_unread_controller.dart';
import '../application/message_chats_refresh.dart';
import '../data/private_pair_gateway.dart';
import '../domain/private_pair_models.dart';
import 'conversation_history_list.dart';
import 'message_read_viewport.dart';
import 'messages_routes.dart';
import 'messages_formatters.dart';

/// Both person rows and retained exact-source routes open this same timeline.
/// Source routes must resolve successfully before any pair history is requested.
class PrivatePairScreen extends ConsumerStatefulWidget {
  const PrivatePairScreen({
    this.peerProfileId,
    this.contextKind,
    this.contextId,
    super.key,
  }) : assert(
         peerProfileId != null || (contextKind != null && contextId != null),
       );
  final String? peerProfileId, contextKind, contextId;
  @override
  ConsumerState<PrivatePairScreen> createState() => _PrivatePairScreenState();
}

class _PrivatePairScreenState extends ConsumerState<PrivatePairScreen>
    with WidgetsBindingObserver {
  final body = TextEditingController();
  late final ScrollController scroll;
  final viewport = GlobalKey();
  final messageKeys = <String, GlobalKey>{};
  final seen = <String, PrivatePairItem>{};
  List<PrivatePairItem> items = [];
  List<PrivatePairContext> contexts = [];
  String? actor, peer, name, boundary, selected;
  PrivatePairSend? attempt;
  bool busy = true,
      failed = false,
      more = false,
      olderBusy = false,
      olderFailed = false,
      moreContexts = false,
      sending = false,
      sendFailed = false,
      needsSelection = false,
      hasResourceCoordination = false;
  int revision = 0;
  int retainedWindow = 30;
  bool returnToLatest = true;
  String? retainedOldestKey, anchorKey, historyOrigin;
  double savedOffset = 0, anchorDelta = 0;
  bool restoreAnchor = false;
  bool readingPositionReady = false;
  Timer? poll, refresh;
  bool get current =>
      mounted &&
      actor != null &&
      ref.read(authSessionProvider).identity?.id == actor;
  bool get foreground =>
      current &&
      ModalRoute.of(context)?.isCurrent == true &&
      TickerMode.valuesOf(context).enabled &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;
  @override
  void initState() {
    super.initState();
    scroll = ScrollController(
      onAttach: (position) =>
          position.isScrollingNotifier.addListener(scheduleVisible),
      onDetach: (position) =>
          position.isScrollingNotifier.removeListener(scheduleVisible),
    );
    WidgetsBinding.instance.addObserver(this);
    scroll.addListener(scheduleVisible);
    actor = ref.read(authSessionProvider).identity?.id;
    peer = widget.peerProfileId;
    Future.microtask(load);
    poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (foreground) unawaited(load());
    });
  }

  void clearProtected() {
    rememberWindow();
    restoreAnchor = true;
    items = [];
    contexts = [];
    seen.clear();
    messageKeys.clear();
    boundary = null;
    readingPositionReady = false;
    name = null;
    hasResourceCoordination = false;
    busy = true;
  }

  void rememberWindow() {
    if (items.isEmpty) return;
    retainedWindow = items.length;
    retainedOldestKey = items.first.key;
    returnToLatest = !scroll.hasClients || scroll.position.extentAfter <= 1;
    if (scroll.hasClients) savedOffset = scroll.offset;
    anchorKey = null;
    final region = viewport.currentContext?.findRenderObject();
    if (returnToLatest || region is! RenderBox || !region.hasSize) return;
    final top = region.localToGlobal(Offset.zero).dy;
    for (final item in items) {
      final box = messageKeys[item.key]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final y = box.localToGlobal(Offset.zero).dy;
        if (y + box.size.height > top) {
          anchorKey = item.key;
          anchorDelta = y - top;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    revision++;
    poll?.cancel();
    refresh?.cancel();
    body.dispose();
    scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && current) {
      unawaited(load(scrub: true));
    }
  }

  Future<void> load({bool scrub = false, bool older = false}) async {
    if (!current || (older && (olderBusy || !more))) return;
    final gateway = ref.read(privatePairGatewayProvider);
    final epoch = ++revision;
    if (!older) rememberWindow();
    setState(() {
      if (scrub) {
        clearProtected();
      }
      if (older) {
        olderBusy = true;
        olderFailed = false;
      } else {
        boundary = null;
        readingPositionReady = false;
        busy = items.isEmpty;
        failed = false;
      }
    });
    try {
      PrivatePairContext? focused;
      var targetPeer = peer;
      // Reauthorize a retained source link on EVERY refresh, including revocation.
      if (widget.contextKind != null) {
        final resolved = await gateway.resolve(
          actor!,
          widget.contextKind!,
          widget.contextId!,
        );
        if (!current || epoch != revision) return;
        targetPeer = resolved.peer;
        focused = resolved.context;
      }
      if (!current || epoch != revision || targetPeer == null) return;
      final page = await gateway.feed(
        actor!,
        targetPeer,
        before: older && items.isNotEmpty ? items.first : null,
      );
      final available = older
          ? contexts
          : await gateway.contexts(actor!, targetPeer, onlyWritable: true);
      if (!current || epoch != revision) return;
      final next = page.items.take(30).toList();
      var hasMore = page.items.length > 30;
      while (!older &&
          hasMore &&
          (next.length < retainedWindow ||
              (retainedOldestKey != null &&
                  !next.any((m) => m.key == retainedOldestKey) &&
                  next.length < retainedWindow + 30))) {
        final extra = await gateway.feed(actor!, targetPeer, before: next.last);
        if (!current || epoch != revision) return;
        next.addAll(extra.items.take(30));
        hasMore = extra.items.length > 30;
      }
      if (!older && retainedOldestKey != null) {
        final stop = next.indexWhere((m) => m.key == retainedOldestKey);
        if (stop >= 0 && stop + 1 < next.length) {
          next.removeRange(stop + 1, next.length);
          hasMore = true;
        }
      }
      next.sort(comparePrivateItems);
      final all = older ? [...next, ...items] : next;
      if (all.map((m) => m.key).toSet().length != all.length) {
        throw const FormatException('Repeated personal message.');
      }
      setState(() {
        peer = targetPeer;
        items = all;
        historyOrigin ??= all.firstOrNull?.key;
        name = page.name;
        hasResourceCoordination = page.hasResourceCoordination;
        more = hasMore;
        retainedWindow = all.length < 30 ? 30 : all.length;
        busy = false;
        failed = false;
        olderBusy = false;
        if (!older) {
          boundary = page.boundary;
          contexts = [
            if (focused != null &&
                focused.canSend &&
                !available.any((c) => c.key == focused!.key))
              focused,
            ...available,
          ];
          moreContexts = available.length == 50;
        }
        final selectedContext = contexts.where(
          (c) => c.entitlementKey == selected,
        );
        if (selectedContext.isEmpty) {
          if (selected != null && body.text.isNotEmpty) needsSelection = true;
          selected = null;
        }
        if (selected == null && attempt == null && !needsSelection) {
          final focused = contexts.where(
            (c) => c.kind == widget.contextKind && c.id == widget.contextId,
          );
          if (focused.isNotEmpty) {
            selected = focused.first.entitlementKey;
          } else if (contexts.length == 1 && !moreContexts) {
            selected = contexts.single.entitlementKey;
          }
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!current || epoch != revision) return;
        if (!older && returnToLatest && scroll.hasClients) {
          scroll.jumpTo(scroll.position.maxScrollExtent);
        } else if (!older && restoreAnchor && scroll.hasClients) {
          scroll.jumpTo(
            savedOffset.clamp(
              scroll.position.minScrollExtent,
              scroll.position.maxScrollExtent,
            ),
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!current || epoch != revision || !scroll.hasClients) return;
            final box = messageKeys[anchorKey]?.currentContext
                ?.findRenderObject();
            final region = viewport.currentContext?.findRenderObject();
            if (box is RenderBox &&
                box.hasSize &&
                region is RenderBox &&
                region.hasSize) {
              final shift =
                  box.localToGlobal(Offset.zero).dy -
                  region.localToGlobal(Offset.zero).dy -
                  anchorDelta;
              scroll.jumpTo(
                (scroll.offset + shift).clamp(
                  scroll.position.minScrollExtent,
                  scroll.position.maxScrollExtent,
                ),
              );
            }
          });
        }
        restoreAnchor = false;
        // The initial frame can still contain widgets from the zero-origin
        // viewport. Wait for the latest/retained scroll layout before recording.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!current || epoch != revision) return;
          readingPositionReady = true;
          recordVisible();
        });
        WidgetsBinding.instance.scheduleFrame();
      });
    } catch (error) {
      if (mounted &&
          current &&
          epoch == revision &&
          widget.contextKind == 'participation_request' &&
          error is PostgrestException &&
          error.code == '42501' &&
          peer == null) {
        // The original request-details owner reauthorizes manager access. This
        // never substitutes another person's source or reveals a pair history.
        context.replace(participationRequestMessageRoute(widget.contextId!));
        return;
      }
      if (current && epoch == revision) {
        setState(() {
          if (older) {
            olderBusy = false;
            olderFailed = true;
          } else {
            items = [];
            contexts = [];
            seen.clear();
            boundary = null;
            busy = false;
            failed = true;
          }
        });
      }
    }
  }

  Future<void> loadContexts() async {
    if (!current || contexts.isEmpty) return;
    final epoch = revision;
    try {
      final next = await ref
          .read(privatePairGatewayProvider)
          .contexts(actor!, peer!, before: contexts.last, onlyWritable: true);
      if (current && epoch == revision) {
        setState(() {
          contexts = [
            ...contexts,
            ...next.where((n) => !contexts.any((c) => c.key == n.key)),
          ];
          moreContexts = next.length == 50;
        });
      }
    } catch (_) {
      if (current) setState(() => sendFailed = true);
    }
  }

  void scheduleVisible() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => recordVisible());
    WidgetsBinding.instance.scheduleFrame();
  }

  void recordVisible() {
    if (!foreground ||
        busy ||
        olderBusy ||
        !readingPositionReady ||
        !scroll.hasClients ||
        !scroll.position.hasContentDimensions ||
        scroll.position.isScrollingNotifier.value) {
      return;
    }
    final region = viewport.currentContext?.findRenderObject();
    if (region is! RenderBox || !region.hasSize) return;
    final bounds = region.localToGlobal(Offset.zero) & region.size;
    var changed = false;
    for (final message in items.where((m) => m.human)) {
      final box = messageKeys[message.key]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.overlaps(bounds) && !seen.containsKey(message.key)) {
        seen[message.key] = message;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<bool> acknowledge(String profile, String scope, String encoded) async {
    if (!foreground || profile != actor || scope != peer) return false;
    final data = jsonDecode(encoded) as Map<String, dynamic>;
    final keys = (data['keys'] as List).cast<String>();
    final gateway = ref.read(privatePairGatewayProvider);
    for (var n = 0; n < keys.length; n += 200) {
      if (!foreground) return false;
      await gateway.acknowledge(
        profile,
        scope,
        data['token'] as String,
        keys.sublist(n, (n + 200).clamp(0, keys.length)),
      );
    }
    if (current) {
      await ref.read(messageUnreadProvider.notifier).refresh(profile);
    }
    return current;
  }

  Future<void> send() async {
    if (!current || sending || peer == null) return;
    if (attempt == null) {
      final available = contexts.where(
        (c) => c.entitlementKey == selected && c.canSend,
      );
      if (available.length != 1 || body.text.trim().isEmpty) return;
      attempt = PrivatePairSend(
        actor!,
        peer!,
        const Uuid().v4(),
        available.single,
        body.text,
      );
    }
    final frozen = attempt!;
    setState(() {
      sending = true;
      sendFailed = false;
    });
    try {
      await ref.read(privatePairGatewayProvider).send(frozen);
      if (!current || attempt != frozen) return;
      body.clear();
      needsSelection = false;
      attempt = null;
      await load(scrub: true);
    } on PostgrestException catch (error) {
      if (!current) return;
      // These are explicit rejected transactions. A transport failure retains
      // the original command, source, episode and exact unsent body for retry.
      if ({'PT409', '42501', '22023', '55000', 'PT429'}.contains(error.code)) {
        attempt = null;
        selected = null;
        needsSelection = true;
        await load(scrub: true);
      }
      if (current) setState(() => sendFailed = true);
    } catch (_) {
      if (current) setState(() => sendFailed = true);
    } finally {
      if (current) setState(() => sending = false);
    }
  }

  String contextLabel(AppLocalizations l, String kind, String title) =>
      switch (kind) {
        'participation_request' => l.privatePairProjectContext(title),
        'resource_chat' => l.privatePairResourceContext(title),
        'member_contact_chat' => l.privatePairMemberContext(title),
        _ => l.privatePairPeopleContext(title),
      };
  Future<void> openContext(PrivatePairItem m) async {
    final id = m.contextId!;
    final route = switch (m.contextKind) {
      'participation_request' => participationRequestMessageRoute(id),
      'resource_chat' => '${resourceChatRoute(m.sourceId)}/manage',
      'member_contact_chat' => memberContactInfoRoute(id),
      _ => '/messages/cocreate/contacts/$id/manage',
    };
    await context.push(route);
    if (current) await load(scrub: true);
  }

  void report(PrivatePairItem m) {
    final l = AppLocalizations.of(context);
    final kind = switch (m.kind) {
      'resource_message' => ModerationTargetKind.resourceChatMessage,
      'member_contact_message' => ModerationTargetKind.memberContactMessage,
      'cocreate_contact_message' => ModerationTargetKind.cocreateContactMessage,
      _ => null,
    };
    if (kind == null) return;
    ModerationRoutes.openReport(
      context,
      ModerationReportTarget(
        kind: kind,
        id: m.id,
        label: l.contactMessageReport,
        contextKind: kind == ModerationTargetKind.memberContactMessage
            ? ModerationContextKind.memberContactChat
            : null,
        contextId: kind == ModerationTargetKind.memberContactMessage
            ? m.sourceId
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(privatePairSignalsProvider, (_, _) {
      if (!current) return;
      revision++;
      setState(clearProtected);
      refresh?.cancel();
      refresh = Timer(const Duration(milliseconds: 180), () => load());
    });
    ref.listen(messageChatsRefreshProvider, (_, _) {
      if (current) unawaited(load(scrub: true));
    });
    ref.listen(privatePairGatewayProvider, (_, _) {
      if (!current) return;
      setState(() {
        revision++;
        clearProtected();
        retainedWindow = 30;
        retainedOldestKey = null;
        historyOrigin = null;
        anchorKey = null;
        savedOffset = 0;
        returnToLatest = true;
        peer = widget.peerProfileId;
        attempt = null;
        body.clear();
        selected = null;
      });
      unawaited(load());
    });
    final session = ref.watch(authSessionProvider),
        l = AppLocalizations.of(context);
    if (session.identity?.id != actor) {
      items = [];
      contexts = [];
      seen.clear();
      attempt = null;
      body.clear();
      boundary = null;
      return Scaffold(
        appBar: pageAppBar(context, title: Text(l.messageChatsPrivate)),
        body: const SizedBox.shrink(),
      );
    }
    final rendered = seen.values.toList()
      ..sort((a, b) {
        final source = '${a.sourceKind}:${a.sourceId}'.compareTo(
          '${b.sourceKind}:${b.sourceId}',
        );
        return source != 0 ? source : a.ordinal!.compareTo(b.ordinal!);
      });
    final receipt = boundary == null || rendered.isEmpty || olderBusy
        ? null
        : jsonEncode({
            'token': boundary,
            'keys': rendered.map((m) => m.key).toList(),
          });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) recordVisible();
    });
    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(name ?? l.messageChatsPrivate),
        actions: [
          if (peer != null && !failed && !busy)
            BlockingActionButton(
              targetProfileId: peer!,
              targetDisplayName: name,
              compact: true,
              consequence: hasResourceCoordination
                  ? BlockingContextConsequence.acceptedResourceCoordination
                  : BlockingContextConsequence.none,
              onChanged: (_) => load(scrub: true),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (busy)
              Expanded(child: LoadingState(message: l.messageChatsLoading))
            else if (failed)
              Expanded(
                child: ErrorState(
                  message: l.privatePairUnavailable,
                  onRetry: () => load(scrub: true),
                ),
              )
            else
              Expanded(
                key: viewport,
                child: MessageReadViewport(
                  profileId: actor,
                  kind: 'private_pair',
                  chatId: peer,
                  boundary: receipt,
                  scrollController: scroll,
                  acknowledge: acknowledge,
                  child: ConversationHistoryList<PrivatePairItem>(
                    initialOriginKey: historyOrigin,
                    items: items,
                    itemKey: (m) => m.key,
                    controller: scroll,
                    enabled: foreground,
                    hasMore: more,
                    loading: olderBusy,
                    failed: olderFailed,
                    onLoadOlder: () => load(older: true),
                    fallbackLabel: l.privatePairLoadOlder,
                    buttonKey: const Key('private-pair-older'),
                    empty: Text(l.projectChatNoMessages),
                    itemBuilder: (context, m) {
                      if (!m.human) {
                        return Card(
                          key: messageKeys.putIfAbsent(m.key, GlobalKey.new),
                          child: ListTile(
                            leading: const Icon(Icons.link),
                            title: Text(
                              contextLabel(l, m.contextKind!, m.title!),
                            ),
                            subtitle: Text(
                              m.status == 'open'
                                  ? l.privatePairContextOpen
                                  : m.status == 'closed'
                                  ? l.privatePairContextClosed
                                  : m.status == 'pending'
                                  ? l.privatePairContextPending
                                  : l.privatePairContextResolved,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => openContext(m),
                          ),
                        );
                      }
                      final own = m.sender == actor;
                      return Align(
                        alignment: own
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          key: messageKeys.putIfAbsent(m.key, GlobalKey.new),
                          constraints: const BoxConstraints(maxWidth: 560),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: own
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!own && m.sender != peer)
                                Text(
                                  m.senderName!,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              Text(m.body!),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      messageActivityDate(context, m.createdAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ),
                                  if (!own &&
                                      {
                                        'resource_message',
                                        'member_contact_message',
                                        'cocreate_contact_message',
                                      }.contains(m.kind))
                                    IconButton(
                                      tooltip: l.contactMessageReport,
                                      onPressed: () => report(m),
                                      icon: const Icon(
                                        Icons.flag_outlined,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (sendFailed)
              Text(
                l.privatePairSendFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!busy && !failed)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (contexts.length > 1 || moreContexts || needsSelection)
                      DropdownButtonFormField<String>(
                        key: ValueKey((selected, contexts.length)),
                        initialValue: selected,
                        isExpanded: true,
                        itemHeight: null,
                        decoration: InputDecoration(
                          labelText: l.privatePairRegarding,
                        ),
                        items: contexts
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.entitlementKey,
                                child: Text(
                                  contextLabel(l, c.kind, c.title),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: sending || attempt != null
                            ? null
                            : (value) => setState(() {
                                selected = value;
                                needsSelection = false;
                              }),
                      ),
                    if (moreContexts)
                      TextButton(
                        onPressed: loadContexts,
                        child: Text(l.privatePairMoreContexts),
                      ),
                    if (contexts.isEmpty)
                      Text(
                        l.privatePairReadOnly,
                        key: const Key('private-pair-read-only'),
                      ),
                    if (contexts.isNotEmpty ||
                        attempt != null ||
                        body.text.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('private-pair-composer'),
                              controller: body,
                              readOnly:
                                  sending ||
                                  attempt != null ||
                                  contexts.isEmpty,
                              minLines: 1,
                              maxLines: 5,
                              maxLength:
                                  contexts
                                      .where(
                                        (c) =>
                                            c.entitlementKey == selected &&
                                            c.kind == 'cocreate_contact',
                                      )
                                      .isNotEmpty
                                  ? 2000
                                  : 4000,
                              decoration: InputDecoration(
                                hintText: l.privatePairWriteMessage,
                                counterText: '',
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('private-pair-send'),
                            tooltip: attempt != null
                                ? l.privatePairRetrySend
                                : l.privatePairSend,
                            onPressed:
                                sending || (selected == null && attempt == null)
                                ? null
                                : send,
                            icon: sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    attempt != null
                                        ? Icons.refresh
                                        : Icons.send,
                                  ),
                          ),
                        ],
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
