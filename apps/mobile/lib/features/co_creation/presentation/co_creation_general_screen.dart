import '../application/people_attempt.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../messages/presentation/conversation_history_list.dart';
import '../../messages/presentation/message_read_viewport.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../data/co_creation_rooms_gateway.dart';
import '../domain/co_creation_rooms.dart';
import '../domain/co_creation_identity.dart';
import '../../messages/application/message_unread_controller.dart';
import '../application/people_signals.dart';
import '../domain/people_private.dart';
import 'people_widgets.dart';

import 'package:go_router/go_router.dart';

class CoCreationGeneralScreen extends ConsumerStatefulWidget {
  const CoCreationGeneralScreen({
    required this.hubId,
    required this.roomId,
    required this.episodeId,
    super.key,
  });
  final HubId hubId;
  final CoRoomId roomId;
  final CoEpisodeId episodeId;
  @override
  ConsumerState<CoCreationGeneralScreen> createState() =>
      _CoCreationGeneralScreenState();
}

class _CoCreationGeneralScreenState
    extends ConsumerState<CoCreationGeneralScreen>
    with WidgetsBindingObserver {
  final body = TextEditingController(), scroll = ScrollController();
  List<PeopleMessage> messages = [];
  String? token;
  CoGeneralContext? roomContext;
  bool busy = true,
      olderBusy = false,
      failed = false,
      olderFailed = false,
      more = false,
      closed = true;
  int epoch = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(load);
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          TickerMode.valuesOf(context).enabled &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
        load();
      }
    });
  }

  void invalidate() {
    epoch++;
    messages = [];
    token = null;
    roomContext = null;
    closed = true;
  }

  @override
  void dispose() {
    epoch++;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    body.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load();
    } else {
      setState(invalidate);
    }
  }

  Future<void> load({bool older = false}) async {
    if (older && (olderBusy || messages.isEmpty || !more)) return;
    final actor = ref.read(authSessionProvider).identity?.id;
    if (actor == null) return;
    final generation = older ? epoch : ++epoch;
    final before = older ? messages.first.sequence : null;
    setState(() {
      if (older) {
        olderBusy = true;
        olderFailed = false;
      } else {
        busy = true;
        failed = false;
        messages = [];
        token = null;
      }
    });
    try {
      final meta = await ref
          .read(coCreationRoomsGatewayProvider)
          .context(actor, widget.hubId, widget.roomId, widget.episodeId);
      final page = await ref
          .read(coCreationRoomsGatewayProvider)
          .feed(actor, widget.roomId, widget.episodeId, before: before);
      if (!mounted ||
          generation != epoch ||
          ref.read(authSessionProvider).identity?.id != actor) {
        return;
      }
      setState(() {
        messages = [...page.messages.reversed, if (older) ...messages];
        closed = page.closed;
        roomContext = meta;
        if (!older) token = page.readToken;
        busy = false;
        olderBusy = false;
        more = page.messages.length == 30;
      });
    } catch (_) {
      if (mounted && generation == epoch) {
        setState(() {
          invalidate();
          busy = false;
          olderBusy = false;
          failed = true;
          olderFailed = older;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(peopleSignalsProvider, (_, next) {
      setState(invalidate);
      if (next.asData?.value.connected == true) {
        Future<void>.microtask(load);
      } else {
        setState(() => failed = true);
      }
    });
    ref.listen(authSessionProvider.select((s) => (s.identity?.id, s.phase)), (
      _,
      _,
    ) {
      setState(() {
        invalidate();
        body.clear();
      });
      Future<void>.microtask(load);
    });
    ref.listen(policyAcceptanceProvider, (_, _) {
      setState(invalidate);
      Future<void>.microtask(load);
    });
    final attempt = ref.watch(
      peopleAttemptsProvider,
    )['room/${widget.roomId.value}/${widget.episodeId.value}/send'];
    final locked = attempt?.uncertain == true || attempt?.busy == true;
    final l = AppLocalizations.of(context),
        actor = ref.watch(authSessionProvider).identity?.id;
    return PeoplePage(
      title: l.coRoomsGeneral,
      child: PeopleAccess(
        child: Column(
          children: [
            if (roomContext != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(roomContext!.label),
              ),
            if (busy) const LinearProgressIndicator(),
            if (failed) Text(l.coPeopleError),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => context.push(
                    coHubLeaveRoute(widget.hubId, widget.episodeId),
                  ),
                  child: Text(l.coRoomsLeave),
                ),
                if (!closed)
                  TextButton(
                    onPressed: () => context.push(
                      '${coGeneralRoute(widget.hubId, widget.roomId, widget.episodeId)}/people',
                    ),
                    child: Text(l.coRoomsPeople),
                  ),
                TextButton(
                  onPressed: () => load(),
                  child: Text(l.coPeopleRefresh),
                ),
              ],
            ),
            Expanded(
              child: MessageReadViewport(
                profileId: actor,
                kind: 'cocreate_room',
                chatId: '${widget.roomId.value}:${widget.episodeId.value}',
                acknowledge: (profile, scope, boundary) async {
                  try {
                    await ref
                        .read(coCreationRoomsGatewayProvider)
                        .acknowledge(
                          profile,
                          widget.roomId,
                          widget.episodeId,
                          boundary,
                        );
                    if (mounted) {
                      await ref
                          .read(messageUnreadProvider.notifier)
                          .refresh(profile);
                    }
                    return true;
                  } catch (_) {
                    if (mounted) setState(invalidate);
                    return false;
                  }
                },
                boundary: olderBusy ? null : token,
                scrollController: scroll,
                child: ConversationHistoryList<PeopleMessage>(
                  items: messages,
                  itemKey: (m) => m.id,
                  itemBuilder: (context, m) => ListTile(
                    title: Text(m.body),
                    subtitle: Text(m.createdAt.toLocal().toString()),
                    trailing: m.senderId == actor
                        ? null
                        : IconButton(
                            tooltip: l.coPeopleReport,
                            icon: const Icon(Icons.flag_outlined),
                            onPressed: () => ModerationRoutes.openReport(
                              context,
                              ModerationReportTarget(
                                kind: ModerationTargetKind.cocreateRoomMessage,
                                id: m.id,
                                label: l.coPeopleChat,
                              ),
                            ),
                          ),
                  ),
                  controller: scroll,
                  enabled: !busy,
                  hasMore: more,
                  loading: olderBusy,
                  failed: olderFailed,
                  onLoadOlder: () => load(older: true),
                  fallbackLabel: l.coPeopleMore,
                  buttonKey: const Key('co-general-older'),
                  empty: Text(l.coPeopleEmpty),
                ),
              ),
            ),
            if (closed)
              Text(l.coPeopleClosed)
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: body,
                      enabled: !locked,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(labelText: l.coPeopleMessage),
                    ),
                    ListenableBuilder(
                      listenable: body,
                      builder: (context, _) => PeopleCommand(
                        slot:
                            'room/${widget.roomId.value}/${widget.episodeId.value}/send',
                        rpc: 'send_cocreate_room_message',
                        gateway: (ref) =>
                            ref.read(coCreationRoomsGatewayProvider),
                        intent: {
                          'p_room_id': widget.roomId.value,
                          'p_episode_id': widget.episodeId.value,
                          'p_body': body.text,
                        },
                        label: l.coPeopleSend,
                        onSuccess: (_) async {
                          body.clear();
                          await load();
                        },
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
