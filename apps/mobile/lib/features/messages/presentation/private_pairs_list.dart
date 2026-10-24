import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/pagination_control.dart';
import '../../../core/widgets/user_scroll_pagination.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../profile_photo/application/visible_profile_photo_controller.dart';
import '../../profile_photo/presentation/visible_profile_photo_avatar.dart';
import '../data/private_pair_gateway.dart';
import '../application/message_chats_refresh.dart';
import '../domain/private_pair_models.dart';
import 'message_unread_badge.dart';
import 'messages_formatters.dart';

String privatePairRoute(String peer) =>
    '/messages/private/${Uri.encodeComponent(peer)}';

class PrivatePairsList extends ConsumerStatefulWidget {
  const PrivatePairsList({required this.actor, super.key});
  final String actor;
  @override
  ConsumerState<PrivatePairsList> createState() => _PrivatePairsListState();
}

class _PrivatePairsListState extends ConsumerState<PrivatePairsList>
    with WidgetsBindingObserver {
  List<PrivatePairRow> rows = [];
  bool busy = true,
      failed = false,
      more = false,
      moreBusy = false,
      moreFailed = false;
  int revision = 0;
  Timer? timer;
  final photosReady = <String>{};
  bool get current =>
      mounted && ref.read(authSessionProvider).identity?.id == widget.actor;
  bool get foreground =>
      current &&
      ModalRoute.of(context)?.isCurrent == true &&
      TickerMode.valuesOf(context).enabled &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(load);
    timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (foreground) unawaited(load());
    });
  }

  @override
  void dispose() {
    revision++;
    timer?.cancel();
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
    if (!current || (older && (moreBusy || !more))) return;
    final epoch = ++revision, gateway = ref.read(privatePairGatewayProvider);
    final retained = rows.length;
    setState(() {
      if (scrub) {
        rows = [];
        photosReady.clear();
      }
      if (older) {
        moreBusy = true;
        moreFailed = false;
      } else {
        busy = rows.isEmpty;
        failed = false;
      }
    });
    try {
      final loaded = older ? [...rows] : <PrivatePairRow>[];
      var hasMore = false;
      do {
        final page = await gateway.list(
          widget.actor,
          before: loaded.isEmpty ? null : loaded.last,
        );
        hasMore = page.length > 20;
        loaded.addAll(page.take(20));
        if (older) break;
      } while (hasMore && loaded.length < retained);
      if (!current || epoch != revision) return;
      if (loaded.map((r) => r.peer).toSet().length != loaded.length) {
        throw const FormatException('Repeated personal pair.');
      }
      setState(() {
        rows = loaded;
        more = hasMore;
        busy = false;
        moreBusy = false;
        failed = false;
      });
      final targets = loaded
          .map((r) => r.peer)
          .where((p) => !photosReady.contains(p))
          .toList();
      for (var n = 0; n < targets.length; n += 50) {
        final batch = targets.sublist(n, (n + 50).clamp(0, targets.length));
        await ref
            .read(visibleProfilePhotoProvider.notifier)
            .loadBatch(batch, force: true);
        if (!current || epoch != revision) return;
        setState(() => photosReady.addAll(batch));
      }
    } catch (_) {
      if (current && epoch == revision) {
        setState(() {
          busy = false;
          moreBusy = false;
          if (older) {
            moreFailed = true;
          } else {
            failed = true;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(privatePairSignalsProvider, (_, _) {
      if (current) unawaited(load(scrub: true));
    });
    ref.listen(messageChatsRefreshProvider, (_, _) {
      if (current) unawaited(load(scrub: true));
    });
    ref.listen(privatePairGatewayProvider, (_, _) {
      if (current) unawaited(load(scrub: true));
    });
    final session = ref.watch(authSessionProvider),
        l = AppLocalizations.of(context);
    final photos = ref.watch(visibleProfilePhotoProvider);
    if (session.identity?.id != widget.actor) return const SizedBox.shrink();
    if (busy) return LoadingState(message: l.messageChatsLoading);
    if (failed && rows.isEmpty) {
      return ErrorState(
        message: l.privatePairUnavailable,
        onRetry: () => load(scrub: true),
      );
    }
    return RefreshIndicator(
      onRefresh: () => load(scrub: true),
      child: UserScrollPagination(
        enabled: foreground && more && !moreBusy && !moreFailed,
        requestKey: rows.length,
        onLoad: () => load(older: true),
        builder: (context, showFallback) => ListView.builder(
          key: const PageStorageKey('private-pair-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: rows.length + 1,
          itemBuilder: (context, index) {
            if (index == rows.length) {
              return Column(
                children: [
                  if (rows.isEmpty)
                    EmptyState(
                      title: l.messageChatsPrivateEmptyTitle,
                      message: l.messageChatsPrivateEmptyMessage,
                    ),
                  if (failed)
                    ErrorState(
                      message: l.privatePairUnavailable,
                      onRetry: () => load(scrub: true),
                    ),
                  if (more)
                    PaginationControl(
                      loading: moreBusy,
                      failed: moreFailed,
                      showFallback: showFallback,
                      onLoad: () => load(older: true),
                      fallbackLabel: l.privatePairLoadMore,
                      buttonKey: const Key('private-pairs-more'),
                    ),
                ],
              );
            }
            final row = rows[index];
            return Card(
              key: ValueKey('private-pair-${row.peer}'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: row.unread > 0
                    ? BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : BorderSide.none,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stack =
                      constraints.maxWidth < 480 &&
                      MediaQuery.textScalerOf(context).scale(14) > 20;
                  final metadata = <Widget>[
                    Text(
                      messageActivityDate(context, row.activity),
                      key: Key('private-pair-time-${row.peer}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (row.unread > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: MessageInlineCount(
                          count: row.unread,
                          label: l.messageUnreadMessages(row.unread),
                        ),
                      ),
                  ];
                  return ListTile(
                    key: Key('private-pair-link-${row.peer}'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: SizedBox(
                      key: ValueKey('chat-thumbnail-private_pair:${row.peer}'),
                      width: 40,
                      height: 40,
                      child: VisibleProfilePhotoAvatar(
                        entry:
                            photosReady.contains(row.peer) &&
                                photos.viewerProfileId == widget.actor
                            ? photos.entryFor(row.peer)
                            : null,
                        imageSemanticsLabel: row.name,
                        placeholderSemanticsLabel: row.name,
                        radius: 20,
                      ),
                    ),
                    title: Text(row.name),
                    subtitle: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.activityKind == 'context'
                              ? l.privatePairContextUpdated
                              : row.body == null
                              ? l.projectChatNoMessages
                              : row.sender == widget.actor
                              ? l.messageOwnPreview(row.body!)
                              : row.sender != row.peer && row.senderName != null
                              ? l.projectChatPreview(row.senderName!, row.body!)
                              : row.body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (stack)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: metadata,
                            ),
                          ),
                      ],
                    ),
                    trailing: stack
                        ? null
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: metadata,
                          ),
                    onTap: () async {
                      await context.push(privatePairRoute(row.peer));
                      if (current) await load(scrub: true);
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
