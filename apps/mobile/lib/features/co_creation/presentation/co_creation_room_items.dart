import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../../policies/application/policy_documents.dart';
import '../data/co_creation_rooms_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_rooms.dart';
import '../domain/people_post.dart';
import 'people_widgets.dart';
import 'co_creation_numbered_screen.dart';

class CoCreationRoomItems extends StatelessWidget {
  const CoCreationRoomItems({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        CoCreationInboxGate(
          child: PeopleAccess(
            child: PeopleList<CoRoomSummary>(
              emptyVisible: false,
              load: (ref, actor, before) => ref
                  .read(coCreationRoomsGatewayProvider)
                  .rooms(actor!, before: before),
              row: (context, r, refresh) => Card(
                child: ListTile(
                  title: Text(
                    '${r.numbered ? l.coGroupsNumber(r.number!) : l.coRoomsGeneral} · ${r.topic} · ${r.locality}',
                  ),
                  subtitle: r.closed
                      ? Text(l.coPeopleClosed)
                      : r.muted
                      ? Text(l.coRoomsMuted)
                      : null,
                  trailing: r.unread == 0
                      ? null
                      : Semantics(
                          label: l.coPeopleUnread,
                          child: Text('${r.unread}'),
                        ),
                  onTap: () async {
                    await context.push(
                      r.numbered
                          ? coNumberedRoute(r.hubId, r.roomId, r.episodeId)
                          : coGeneralRoute(r.hubId, r.roomId, r.episodeId),
                    );
                    await refresh();
                  },
                ),
              ),
            ),
          ),
        ),
        const _HubExits(),
        const CoNumberedExits(),
      ],
    );
  }
}

const _uuidPattern =
    r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
bool isCoHubLeavePath(String path) =>
    RegExp('^/messages/cocreate/hubs/$_uuidPattern/$_uuidPattern/leave\$')
        .hasMatch(path);

class CoHubLeaveScreen extends StatelessWidget {
  const CoHubLeaveScreen({
    required this.hubId,
    required this.episodeId,
    super.key,
  });
  final HubId hubId;
  final CoEpisodeId episodeId;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coRoomsLeave,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.coRoomsLeaveWarning),
          PeopleAccess(
            requirePolicy: false,
            child: PeopleCommand(
              slot: 'hub/${hubId.value}',
              rpc: 'mutate_cocreate_hub',
              gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
              intent: {
                'p_hub_id': hubId.value,
                'p_episode_id': episodeId.value,
                'p_operation': 'leave',
              },
              label: l.coRoomsLeave,
              onSuccess: (_) async {
                context.go('/messages');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CoRoomPeopleScreen extends StatelessWidget {
  const CoRoomPeopleScreen({
    required this.hubId,
    required this.roomId,
    required this.episodeId,
    this.numbered = false,
    super.key,
  });
  final bool numbered;
  final HubId hubId;
  final CoRoomId roomId;
  final CoEpisodeId episodeId;
  @override
  Widget build(BuildContext context) => PeoplePage(
    title: AppLocalizations.of(context).coRoomsPeople,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PeopleAccess(
          child: PeopleList<CoRoomPerson>(
            load: (ref, actor, before) async {
              final g = ref.read(coCreationRoomsGatewayProvider);
              await g.context(
                actor!,
                hubId,
                roomId,
                episodeId,
                numbered: numbered,
              );
              return g.people(actor, roomId, episodeId, before: before);
            },
            row: (context, p, refresh) => ListTile(title: Text(p.name)),
          ),
        ),
      ],
    ),
  );
}

class _HubExit {
  _HubExit(Object? value) {
    final r = coCreationObject(value, {'hub_id', 'episode_id', 'joined_at'});
    hubId = HubId.parse(r['hub_id']);
    episodeId = CoEpisodeId.parse(r['episode_id']);
    joinedAt = coCreationDate(r['joined_at']);
  }
  late final HubId hubId;
  late final CoEpisodeId episodeId;
  late final DateTime joinedAt;
}

class _HubExits extends ConsumerWidget {
  const _HubExits();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider),
        l = AppLocalizations.of(context);
    final accepted = ref
        .watch(policyAcceptanceProvider)
        .allows(session.identity?.id, ref.watch(policyVersionProvider));
    if (accepted) {
      final available = ref.watch(coCreationInboxAvailabilityProvider);
      if (available.isLoading || available.asData?.value == true) {
        return const SizedBox.shrink();
      }
    }
    return PeopleAccess(
      requirePolicy: false,
      child: PeopleList<_HubExit>(
        emptyVisible: false,
        availabilityRequired: false,
        load: (ref, actor, before) async {
          final raw = await ref.read(coCreationRoomsGatewayProvider).rpc(
            'list_own_cocreate_hub_exits',
            {
              'p_expected_profile_id': actor,
              'p_limit': 25,
              'p_before_joined_at': before?.joinedAt.toUtc().toIso8601String(),
              'p_before_id': before?.episodeId.value,
            },
          );
          if (raw is! List || raw.length > 25) {
            throw const FormatException('Invalid own hub exits.');
          }
          final rows = raw.map(_HubExit.new).toList(growable: false),
              ids = <String>{};
          DateTime? time = before?.joinedAt;
          String? id = before?.episodeId.value;
          for (final r in rows) {
            if (!ids.add(r.episodeId.value) ||
                (time != null &&
                    (r.joinedAt.isAfter(time) ||
                        (r.joinedAt.isAtSameMomentAs(time) &&
                            r.episodeId.value.compareTo(id!) >= 0)))) {
              throw const FormatException('Invalid hub exit order.');
            }
            time = r.joinedAt;
            id = r.episodeId.value;
          }
          return rows;
        },
        row: (context, r, refresh) => ListTile(
          title: Text(l.coRoomsLeave),
          onTap: () => context.push(coHubLeaveRoute(r.hubId, r.episodeId)),
        ),
      ),
    );
  }
}
