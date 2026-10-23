import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/people_attempt.dart';
import '../data/co_creation_rooms_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_rooms.dart';
import 'co_creation_recruitment_screen.dart';
import 'people_widgets.dart';

String coMeetingTime(BuildContext context, DateTime instant) {
  final local = instant.toLocal(), material = MaterialLocalizations.of(context);
  final offset = local.timeZoneOffset.inMinutes;
  final zone =
      '${offset < 0 ? '-' : '+'}${(offset.abs() ~/ 60).toString().padLeft(2, '0')}:${(offset.abs() % 60).toString().padLeft(2, '0')}';
  return '${material.formatMediumDate(local)} · ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))} (UTC$zone)';
}

String coMeetingScheduleRoute(
  HubId hub, {
  CoRoomId? room,
  CoEpisodeId? episode,
}) => room == null
    ? '/messages/cocreate/hubs/${hub.value}/schedule'
    : '${coNumberedRoute(hub, room, episode!)}/schedule';

class CoMeetingScheduleScreen extends ConsumerStatefulWidget {
  const CoMeetingScheduleScreen({
    required this.hub,
    this.room,
    this.episode,
    super.key,
  });
  final HubId hub;
  final CoRoomId? room;
  final CoEpisodeId? episode;
  @override
  ConsumerState<CoMeetingScheduleScreen> createState() => _ScheduleState();
}

class _ScheduleState extends ConsumerState<CoMeetingScheduleScreen> {
  DateTime? startsAt;
  int capacity = 5;
  bool invalidTime = false;
  @override
  void initState() {
    super.initState();
    final slot = 'meeting-schedule/${widget.room?.value ?? widget.hub.value}';
    final attempt = ref.read(peopleAttemptsProvider)[slot];
    if (attempt?.pending == true) {
      startsAt = DateTime.parse(attempt!.intent['p_starts_at'] as String)
          .toUtc();
      capacity = attempt.intent['p_capacity'] as int;
    }
  }

  Future<void> choose() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: startsAt?.toLocal() ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 366)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: startsAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(startsAt!.toLocal()),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // A DST gap must never silently turn 02:30 into a different wall-clock time.
    final invalid =
        selected.hour != time.hour ||
        selected.minute != time.minute ||
        !selected.isAfter(DateTime.now());
    setState(() {
      invalidTime = invalid;
      startsAt = invalid ? null : selected.toUtc();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final slot = 'meeting-schedule/${widget.room?.value ?? widget.hub.value}';
    ref.listen(authSessionProvider, (previous, next) {
      if (previous?.identity?.id != null &&
          previous?.identity?.id != next.identity?.id) {
        setState(() {
          startsAt = null;
          capacity = 5;
          invalidTime = false;
        });
      }
    });
    final pending = ref.watch(peopleAttemptsProvider)[slot]?.pending == true;
    return PeoplePage(
      title: l.coMeetingSchedule,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.coMeetingDisclosure),
          Text(l.coGroupsHubRequired),
          TextButton(
            onPressed: () => context.push(
              '/messages/cocreate/hubs/${widget.hub.value}/review',
            ),
            child: Text(l.coCreationHubs),
          ),
          OutlinedButton.icon(
            key: const Key('co-meeting-time'),
            onPressed: pending ? null : choose,
            icon: const Icon(Icons.schedule),
            label: Text(
              startsAt == null
                  ? l.coMeetingChooseTime
                  : coMeetingTime(context, startsAt!),
            ),
          ),
          if (invalidTime)
            Semantics(liveRegion: true, child: Text(l.coMeetingInvalidTime)),
          DropdownButtonFormField<int>(
            initialValue: capacity,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.coMeetingCapacity),
            items: [
              for (var n = 2; n <= 50; n++)
                DropdownMenuItem(value: n, child: Text('$n')),
            ],
            onChanged: pending ? null : (n) => setState(() => capacity = n!),
          ),
          if (startsAt != null)
            PeopleAccess(
              child: PeopleCommand(
                slot: slot,
                rpc: 'schedule_cocreate_meeting',
                gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
                intent: {
                  'p_hub_id': widget.hub.value,
                  'p_starts_at': startsAt!.toIso8601String(),
                  'p_capacity': capacity,
                  if (widget.room != null) 'p_room_id': widget.room!.value,
                  if (widget.episode != null)
                    'p_episode_id': widget.episode!.value,
                },
                label: l.coMeetingPublish,
                onSuccess: (r) async {
                  await context.push(
                    coNumberedRoute(
                      widget.hub,
                      CoRoomId.parse(r['room_id']),
                      CoEpisodeId.parse(r['episode_id']),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class CoMeetingPanel extends ConsumerWidget {
  const CoMeetingPanel({
    required this.hub,
    required this.room,
    required this.episode,
    this.manager = false,
    this.expectedMeetingId,
    super.key,
  });
  final HubId hub;
  final CoRoomId room;
  final CoEpisodeId episode;
  final bool manager;

  /// Calendar links review one exact occurrence; never substitute a newer one.
  final String? expectedMeetingId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final attempts = ref.watch(peopleAttemptsProvider);
    final pendingMeetings = attempts.entries
        .where(
          (entry) =>
              entry.key.startsWith('meeting/') &&
              entry.value.pending &&
              entry.value.intent['p_room_id'] == room.value &&
              entry.value.intent['p_episode_id'] == episode.value,
        )
        .toList(growable: false);
    final pending = pendingMeetings.isNotEmpty;
    final pendingRoom =
        attempts['meeting-schedule/${room.value}']?.pending == true;
    final pendingHub =
        attempts['meeting-schedule/${hub.value}']?.pending == true;
    return PeopleList<CoCurrentMeeting?>(
      load: (ref, actor, before) async => [
        await ref
            .read(coCreationRoomsGatewayProvider)
            .currentMeeting(actor!, room, episode),
      ],
      row: (context, m, refresh) {
        if (expectedMeetingId != null && m?.id != expectedMeetingId) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.coPeopleUnavailable),
              // A new occurrence cannot strand an older frozen operation.
              for (final entry in pendingMeetings.where(
                (entry) =>
                    entry.value.intent['p_meeting_id'] == expectedMeetingId,
              ))
                PeopleCommand(
                  slot: entry.key,
                  rpc: 'mutate_cocreate_meeting',
                  gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
                  intent: Map<String, dynamic>.from(entry.value.intent),
                  label: l.coPeopleRetry,
                  onSuccess: (_) => refresh(),
                ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (m != null) ...[
              Text(coMeetingTime(context, m.startsAt)),
              Text(l.coMeetingPlaces(m.occupied, m.capacity)),
              if (m.cancelled) Text(l.coMeetingCancelled),
              if (m.attending && !m.cancelled) Text(l.coMeetingAttending),
              if (!pending &&
                  !m.cancelled &&
                  m.startsAt.isAfter(DateTime.now())) ...[
                if (m.attending)
                  PeopleCommand(
                    slot: 'meeting/${m.id}',
                    rpc: 'mutate_cocreate_meeting',
                    gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
                    intent: {
                      'p_hub_id': hub.value,
                      'p_room_id': room.value,
                      'p_episode_id': episode.value,
                      'p_meeting_id': m.id,
                      'p_operation': 'decline',
                    },
                    label: l.coMeetingDecline,
                    onSuccess: (_) => refresh(),
                  ),
                if (!m.attending && m.occupied < m.capacity)
                  PeopleCommand(
                    slot: 'meeting/${m.id}',
                    rpc: 'mutate_cocreate_meeting',
                    gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
                    intent: {
                      'p_hub_id': hub.value,
                      'p_room_id': room.value,
                      'p_episode_id': episode.value,
                      'p_meeting_id': m.id,
                      'p_operation': 'attend',
                    },
                    label: l.coMeetingConfirm,
                    onSuccess: (_) => refresh(),
                  ),
                if (manager)
                  for (final operation in ['repost', 'cancel'])
                    PeopleCommand(
                      slot: 'meeting/${m.id}',
                      rpc: 'mutate_cocreate_meeting',
                      gateway: (ref) =>
                          ref.read(coCreationRoomsGatewayProvider),
                      intent: {
                        'p_hub_id': hub.value,
                        'p_room_id': room.value,
                        'p_episode_id': episode.value,
                        'p_meeting_id': m.id,
                        'p_operation': operation,
                      },
                      label: operation == 'repost'
                          ? l.coMeetingRefill
                          : l.coMeetingCancel,
                      onSuccess: (_) => refresh(),
                    ),
              ],
              if (m.card != null) CoRecruitmentCard(card: m.card!),
            ],
            // A different current occurrence cannot replace an unconfirmed
            // operation's immutable meeting ID or strand its recovery control.
            for (final entry in pendingMeetings)
              PeopleCommand(
                slot: entry.key,
                rpc: 'mutate_cocreate_meeting',
                gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
                intent: Map<String, dynamic>.from(entry.value.intent),
                label: l.coPeopleRetry,
                onSuccess: (_) => refresh(),
              ),
            if (manager &&
                !pending &&
                (pendingRoom ||
                    pendingHub ||
                    m == null ||
                    m.cancelled ||
                    !m.startsAt.isAfter(DateTime.now())))
              TextButton.icon(
                onPressed: () async {
                  await context.push(
                    pendingHub
                        ? coMeetingScheduleRoute(hub)
                        : coMeetingScheduleRoute(
                            hub,
                            room: room,
                            episode: episode,
                          ),
                  );
                  await refresh();
                },
                icon: const Icon(Icons.event_available),
                label: Text(
                  pendingRoom || pendingHub
                      ? l.coPeopleRetry
                      : l.coMeetingSchedule,
                ),
              ),
          ],
        );
      },
    );
  }
}
