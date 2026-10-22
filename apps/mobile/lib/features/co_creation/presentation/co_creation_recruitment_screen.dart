import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/co_creation_rooms_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_rooms.dart';
import '../application/people_attempt.dart';
import 'people_widgets.dart';

class CoRecruitmentCard extends StatelessWidget {
  const CoRecruitmentCard({required this.card, this.onOpen, super.key});
  final CoRecruitment card;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          card.available
              ? l.coRecruitmentSeeking(
                  card.number,
                  card.capacity! - card.occupied!,
                )
              : l.coGroupsNumber(card.number),
        ),
        Text(coRecruitmentState(l, card.state)),
        if (card.available && onOpen != null)
          TextButton(onPressed: onOpen, child: Text(l.coRecruitmentReview)),
      ],
    );
  }
}

String coRecruitmentState(AppLocalizations l, String state) => switch (state) {
  'open' => l.coGroupsAvailable,
  'full' => l.coGroupsFull,
  'expired' => l.coRecruitmentExpired,
  'retracted' => l.coRecruitmentRetracted,
  'unavailable' => l.coPeopleUnavailable,
  _ => throw const FormatException('Invalid recruitment state.'),
};

class CoRecruitmentJoinScreen extends ConsumerWidget {
  const CoRecruitmentJoinScreen({
    required this.hub,
    required this.general,
    required this.episode,
    required this.id,
    super.key,
  });
  final HubId hub;
  final CoRoomId general;
  final CoEpisodeId episode;
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final pending =
        ref.watch(peopleAttemptsProvider)['recruitment-join/$id']?.uncertain ==
        true;
    return PeoplePage(
      title: l.coRecruitmentTitle,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.coGroupsDisclosure),
          PeopleAccess(
            child: PeopleList<CoRecruitment>(
              load: (ref, actor, before) async => [
                (await ref
                    .read(coCreationRoomsGatewayProvider)
                    .recruitment(actor!, hub, general, episode, id: id))!,
              ],
              row: (context, c, refresh) => Column(
                children: [
                  CoRecruitmentCard(card: c),
                  if (c.available || pending)
                    PeopleCommand(
                      slot: 'recruitment-join/${c.id}',
                      rpc: 'join_cocreate_recruitment',
                      gateway: (ref) =>
                          ref.read(coCreationRoomsGatewayProvider),
                      intent: {
                        'p_hub_id': c.hub.value,
                        'p_room_id': c.room.value,
                        'p_recruitment_id': c.id,
                      },
                      label: l.coGroupsJoin,
                      onSuccess: (r) async {
                        await context.push(
                          coNumberedRoute(
                            c.hub,
                            c.room,
                            CoEpisodeId.parse(r['episode_id']),
                          ),
                        );
                        await refresh();
                      },
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

class CoRecruitmentManager extends StatelessWidget {
  const CoRecruitmentManager({
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
    return PeopleList<CoRecruitment?>(
      load: (ref, actor, before) async => [
        await ref
            .read(coCreationRoomsGatewayProvider)
            .recruitment(actor!, hub, room, episode),
      ],
      row: (context, c, refresh) => Column(
        children: [
          Text(l.coRecruitmentNotice),
          if (c != null) CoRecruitmentCard(card: c),
          // Keep the exact post retry available even if its canonical card appeared
          // after a lost response. The server rejects any second active posting.
          PeopleCommand(
            slot: 'recruitment/${room.value}',
            rpc: 'mutate_cocreate_recruitment',
            gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
            intent: {
              'p_hub_id': hub.value,
              'p_room_id': room.value,
              'p_operation': 'post',
              'p_episode_id': episode.value,
            },
            label: l.coRecruitmentPost,
            onSuccess: (_) => refresh(),
          ),
          if (c != null)
            PeopleCommand(
              slot: 'recruitment/${room.value}',
              rpc: 'mutate_cocreate_recruitment',
              gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
              intent: {
                'p_hub_id': hub.value,
                'p_room_id': room.value,
                'p_operation': 'retract',
                'p_recruitment_id': c.id,
              },
              label: l.coRecruitmentRetract,
              onSuccess: (_) => refresh(),
            ),
        ],
      ),
    );
  }
}
