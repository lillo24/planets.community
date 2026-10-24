import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../../policies/application/policy_documents.dart';
import '../application/people_attempt.dart';
import '../data/co_creation_rooms_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_rooms.dart';
import '../domain/people_post.dart';
import '../domain/people_private.dart';
import 'people_widgets.dart';
import 'co_creation_meeting_screen.dart';
import 'co_creation_sources_screen.dart';

/// Public aggregate discovery; no roster/history fetch occurs here.
class CoNumberedList extends StatefulWidget {
  const CoNumberedList({required this.hub, super.key});
  final HubId hub;
  @override
  State<CoNumberedList> createState() => _NumberedListState();
}

class _NumberedListState extends State<CoNumberedList> {
  bool openOnly = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.coGroupsTitle, style: Theme.of(context).textTheme.titleLarge),
        Text(l.coGroupsDisclosure),
        SwitchListTile(
          title: Text(l.coGroupsOpenOnly),
          value: openOnly,
          onChanged: (v) => setState(() => openOnly = v),
        ),
        TextButton(
          onPressed: () =>
              context.push('${CoCreationRoutes.hub(widget.hub)}/create-group'),
          child: Text(l.coGroupsCreate),
        ),
        PeopleList<PublicCoNumbered>(
          key: ValueKey((widget.hub.value, openOnly)),
          private: false,
          load: (ref, actor, before) => ref
              .read(coCreationRoomsGatewayProvider)
              .numbered(widget.hub, openOnly: openOnly, before: before),
          row: (context, r, refresh) {
            final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
            final count = l.coCommunityMembers(r.occupied, r.capacity);
            final availability = r.available
                ? l.coGroupsAvailable
                : l.coGroupsFull;
            return ListTile(
              title: Text(l.coGroupsNumber(r.number)),
              trailing: largeText ? null : Text(count),
              // Large text gets full-width lines; the count remains right aligned.
              subtitle: largeText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(count),
                        ),
                        Text(availability),
                      ],
                    )
                  : Text(availability),
              onTap: () async {
                await context.push(coNumberedDetailRoute(r.hubId, r.roomId));
                await refresh();
              },
            );
          },
        ),
      ],
    );
  }
}

class CoNumberedCreateScreen extends ConsumerStatefulWidget {
  const CoNumberedCreateScreen({required this.hub, super.key});
  final HubId hub;
  @override
  ConsumerState<CoNumberedCreateScreen> createState() => _CreateState();
}

class _CreateState extends ConsumerState<CoNumberedCreateScreen> {
  int capacity = 5;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pending = ref.watch(
      peopleAttemptsProvider,
    )['numbered-create/${widget.hub.value}'];
    return PeoplePage(
      title: l.coGroupsCreate,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.coGroupsDisclosure),
          Text(l.coGroupsHubRequired),
          TextButton(
            onPressed: () => context.push(CoCreationRoutes.hub(widget.hub)),
            child: Text(l.coCreationHubs),
          ),
          DropdownButtonFormField<int>(
            initialValue: capacity,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.coGroupsCapacity),
            items: [
              for (var n = 2; n <= 50; n++)
                DropdownMenuItem(value: n, child: Text('$n')),
            ],
            onChanged: pending?.pending == true
                ? null
                : (n) => setState(() => capacity = n!),
          ),
          PeopleAccess(
            child: PeopleCommand(
              slot: 'numbered-create/${widget.hub.value}',
              rpc: 'mutate_cocreate_numbered_group',
              gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
              intent: {
                'p_hub_id': widget.hub.value,
                'p_operation': 'create',
                'p_capacity': capacity,
              },
              label: l.coGroupsCreate,
              onSuccess: (receipt) async {
                // A receipt identifies an anchor; the destination rereads current admission.
                await context.push(
                  coNumberedRoute(
                    widget.hub,
                    CoRoomId.parse(receipt['room_id']),
                    CoEpisodeId.parse(receipt['episode_id']),
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

class CoNumberedDetailScreen extends ConsumerWidget {
  const CoNumberedDetailScreen({
    required this.hub,
    required this.room,
    super.key,
  });
  final HubId hub;
  final CoRoomId room;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coGroupsTitle,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PeopleList<PublicCoNumbered>(
            private: false,
            load: (ref, actor, before) async {
              final r = await ref
                  .read(coCreationRoomsGatewayProvider)
                  .numberedDetail(hub, room);
              return r == null ? [] : [r];
            },
            row: (context, r, refresh) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.coGroupsNumber(r.number)),
                Text('${r.occupied}/${r.capacity}'),
                Text(l.coGroupsDisclosure),
                Text(l.coGroupsHubRequired),
                TextButton(
                  onPressed: () => context.push(
                    '/messages/cocreate/hubs/${hub.value}/review',
                  ),
                  child: Text(l.coCreationHubs),
                ),
                PeopleAccess(
                  child: PeopleList<CoHubMembership?>(
                    emptyVisible: false,
                    load: (ref, actor, before) async => [
                      await ref
                          .read(coCreationRoomsGatewayProvider)
                          .numberedMembership(actor!, hub, room),
                    ],
                    row: (context, m, reload) => Column(
                      children: [
                        if (m != null)
                          TextButton(
                            onPressed: () => context.push(
                              coNumberedRoute(hub, room, m.episodeId),
                            ),
                            child: Text(
                              m.active ? l.coGroupsOpen : l.coPeopleClosed,
                            ),
                          ),
                        if (m?.active != true ||
                            ref
                                    .watch(
                                      peopleAttemptsProvider,
                                    )['numbered/${room.value}']
                                    ?.pending ==
                                true)
                          PeopleCommand(
                            slot: 'numbered/${room.value}',
                            rpc: 'mutate_cocreate_numbered_group',
                            gateway: (ref) =>
                                ref.read(coCreationRoomsGatewayProvider),
                            intent: {
                              'p_hub_id': hub.value,
                              'p_room_id': room.value,
                              'p_operation': 'join',
                            },
                            label: l.coGroupsJoin,
                            onSuccess: (_) async {
                              await reload();
                              await refresh();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// No client-side grant: every control passes the exact episode and CAS version.
class CoNumberedManageScreen extends StatelessWidget {
  const CoNumberedManageScreen({
    required this.hub,
    required this.room,
    required this.episode,
    super.key,
  });
  final HubId hub;
  final CoRoomId room;
  final CoEpisodeId episode;
  @override
  Widget build(BuildContext context) => PeoplePage(
    title: AppLocalizations.of(context).coGroupsManage,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PeopleAccess(
          child: PeopleList<CoGeneralContext>(
            load: (ref, actor, before) async => [
              await ref
                  .read(coCreationRoomsGatewayProvider)
                  .context(actor!, hub, room, episode, numbered: true),
            ],
            row: (context, m, refresh) => Column(
              children: [
                CoNumberedControls(
                  key: ValueKey(m.version),
                  hub: hub,
                  room: room,
                  episode: episode,
                  meta: m,
                  refresh: refresh,
                ),
                CoGroupProjects(
                  hub: hub,
                  room: room,
                  episode: episode,
                  manager: m.isManager,
                  active: !m.closed,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class CoNumberedRosterScreen extends StatelessWidget {
  const CoNumberedRosterScreen({
    required this.hub,
    required this.room,
    required this.episode,
    super.key,
  });
  final HubId hub;
  final CoRoomId room;
  final CoEpisodeId episode;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coRoomsPeople,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PeopleAccess(
            child: PeopleList<CoGeneralContext>(
              load: (ref, actor, before) async => [
                await ref
                    .read(coCreationRoomsGatewayProvider)
                    .context(actor!, hub, room, episode, numbered: true),
              ],
              row: (context, m, refresh) => Column(
                children: [
                  if (m.isManager) Text(l.coGroupsRemoveWarning),
                  for (final removed in [false, if (m.isManager) true])
                    PeopleList<CoRoomPerson>(
                      key: ValueKey((m.version, removed)),
                      emptyVisible: false,
                      load: (ref, actor, before) => ref
                          .read(coCreationRoomsGatewayProvider)
                          .people(
                            actor!,
                            room,
                            episode,
                            before: before,
                            removed: removed,
                          ),
                      row: (context, p, reload) => Column(
                        children: [
                          ListTile(title: Text(p.name)),
                          if (m.isManager && p.id != m.manager)
                            PeopleCommand(
                              slot: 'numbered/${room.value}',
                              rpc: 'mutate_cocreate_numbered_group',
                              gateway: (ref) =>
                                  ref.read(coCreationRoomsGatewayProvider),
                              intent: {
                                'p_hub_id': hub.value,
                                'p_room_id': room.value,
                                'p_episode_id': episode.value,
                                'p_operation': removed
                                    ? 'restore_member'
                                    : 'remove',
                                'p_target_profile_id': p.id,
                                'p_expected_version': m.version,
                              },
                              label: removed
                                  ? l.coGroupsRestore
                                  : l.coGroupsRemove,
                              onSuccess: (_) => refresh(),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CoNumberedControls extends StatefulWidget {
  const CoNumberedControls({
    required this.hub,
    required this.room,
    required this.episode,
    required this.meta,
    required this.refresh,
    super.key,
  });
  final HubId hub;
  final CoRoomId room;
  final CoEpisodeId episode;
  final CoGeneralContext meta;
  final Future<void> Function() refresh;
  @override
  State<CoNumberedControls> createState() => _ControlsState();
}

class _ControlsState extends State<CoNumberedControls> {
  int? capacity;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), m = widget.meta;
    Widget command(
      String op,
      String label, {
      Map<String, dynamic> extra = const {},
    }) => PeopleCommand(
      slot: 'numbered/${widget.room.value}',
      rpc: 'mutate_cocreate_numbered_group',
      gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
      intent: {
        'p_hub_id': widget.hub.value,
        'p_room_id': widget.room.value,
        'p_episode_id': widget.episode.value,
        'p_operation': op,
        ...extra,
      },
      label: label,
      onSuccess: (_) => widget.refresh(),
    );
    return Column(
      children: [
        Text(l.coCommunityMembers(m.occupied!, m.capacity!)),
        if (!m.closed)
          command(
            'mute',
            m.muted ? l.coGroupsUnmute : l.coGroupsMute,
            extra: {'p_muted': !m.muted},
          ),
        if (!m.closed)
          CoMeetingPanel(
            hub: widget.hub,
            room: widget.room,
            episode: widget.episode,
            manager: m.isManager,
          ),
        if (m.isManager) ...[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              DropdownButton<int>(
                value: capacity ?? m.capacity,
                items: [
                  for (var n = 2; n <= 50; n++)
                    DropdownMenuItem(
                      value: n,
                      child: Text('${l.coGroupsCapacity}: $n'),
                    ),
                ],
                onChanged: (n) => setState(() => capacity = n),
              ),
              command(
                'capacity',
                l.coGroupsSaveCapacity,
                extra: {
                  'p_capacity': capacity ?? m.capacity,
                  'p_expected_version': m.version,
                },
              ),
            ],
          ),
          Text(l.coGroupsArchiveWarning),
          command(
            'archive',
            l.coGroupsArchive,
            extra: {'p_expected_version': m.version},
          ),
        ],
      ],
    );
  }
}

class CoNumberedLeaveScreen extends StatelessWidget {
  const CoNumberedLeaveScreen({
    required this.hub,
    required this.room,
    required this.episode,
    super.key,
  });
  final HubId hub;
  final CoRoomId room;
  final CoEpisodeId episode;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coNumberedLeave,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.coGroupsLeaveWarning),
          PeopleAccess(
            requirePolicy: false,
            child: PeopleCommand(
              slot: 'numbered/${room.value}',
              rpc: 'mutate_cocreate_numbered_group',
              gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
              intent: {
                'p_hub_id': hub.value,
                'p_room_id': room.value,
                'p_episode_id': episode.value,
                'p_operation': 'leave',
              },
              label: l.coNumberedLeave,
              onSuccess: (_) async => context.go('/messages'),
            ),
          ),
        ],
      ),
    );
  }
}

bool isCoNumberedLeavePath(String path) =>
    RegExp(
      r'^/messages/cocreate/hubs/[0-9a-f-]{36}/groups/[0-9a-f-]{36}/[0-9a-f-]{36}/leave$',
    ).hasMatch(path) &&
    path.split('/').where((s) => s.length == 36).every((s) {
      try {
        peopleUuid(s);
        return true;
      } on FormatException {
        return false;
      }
    });

class _NumberedExit {
  _NumberedExit(Object? value) {
    final r = coCreationObject(value, {
      'hub_id',
      'room_id',
      'episode_id',
      'joined_at',
    });
    hub = HubId.parse(r['hub_id']);
    room = CoRoomId.parse(r['room_id']);
    episode = CoEpisodeId.parse(r['episode_id']);
    time = coCreationDate(r['joined_at']);
  }
  late final HubId hub;
  late final CoRoomId room;
  late final CoEpisodeId episode;
  late final DateTime time;
}

class CoNumberedExits extends ConsumerWidget {
  const CoNumberedExits({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(authSessionProvider);
    if (ref
        .watch(policyAcceptanceProvider)
        .allows(s.identity?.id, ref.watch(policyVersionProvider))) {
      final a = ref.watch(coCreationInboxAvailabilityProvider);
      if (a.isLoading || a.asData?.value == true) {
        return const SizedBox.shrink();
      }
    }
    return PeopleAccess(
      requirePolicy: false,
      child: PeopleList<_NumberedExit>(
        emptyVisible: false,
        availabilityRequired: false,
        load: (ref, actor, before) async {
          final raw = await ref.read(coCreationRoomsGatewayProvider).rpc(
            'list_own_cocreate_numbered_exits',
            {
              'p_expected_profile_id': actor,
              'p_limit': 25,
              'p_before_joined_at': before?.time.toUtc().toIso8601String(),
              'p_before_id': before?.episode.value,
            },
          );
          if (raw is! List || raw.length > 25) {
            throw const FormatException('Invalid numbered exits.');
          }
          final rows = raw.map(_NumberedExit.new).toList(growable: false),
              ids = <String>{};
          var time = before?.time;
          var id = before?.episode.value;
          for (final r in rows) {
            if (!ids.add(r.room.value) ||
                time != null &&
                    (r.time.isAfter(time) ||
                        r.time.isAtSameMomentAs(time) &&
                            r.episode.value.compareTo(id!) >= 0)) {
              throw const FormatException('Invalid exit cursor.');
            }
            time = r.time;
            id = r.episode.value;
          }
          return rows;
        },
        row: (context, r, refresh) => ListTile(
          title: Text(AppLocalizations.of(context).coNumberedLeave),
          onTap: () =>
              context.push(coNumberedLeaveRoute(r.hub, r.room, r.episode)),
        ),
      ),
    );
  }
}
