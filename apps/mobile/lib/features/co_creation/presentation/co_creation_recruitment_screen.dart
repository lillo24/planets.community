import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/co_creation_rooms_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_rooms.dart';
import '../application/people_attempt.dart';
import 'people_widgets.dart';
import 'co_creation_meeting_screen.dart';
import 'co_creation_places_screen.dart';

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
        if (card.capacity != null)
          Text(l.coMeetingPlaces(card.occupied!, card.capacity!)),
        if (card.startsAt != null) Text(coMeetingTime(context, card.startsAt!)),
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
        ref.watch(peopleAttemptsProvider)['recruitment-join/$id']?.pending ==
        true;
    return PeoplePage(
      title: l.coRecruitmentTitle,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.coGroupsDisclosure),
          PeopleAccess(
            child: KeyedSubtree(
              key: ValueKey(ref.watch(coCreationRoomsGatewayProvider)),
              child: PeopleList<CoRecruitmentReview>(
                load: (ref, actor, before) async => [
                  (await ref
                      .read(coCreationRoomsGatewayProvider)
                      .recruitmentReview(actor!, hub, general, episode, id)),
                ],
                row: (context, review, refresh) {
                  final c = review.card;
                  return Column(
                    children: [
                      CoRecruitmentCard(card: c),
                      if (review.place != null)
                        CoPlaceLink(hub: hub, place: review.place!),
                      if (c.available && !review.canJoin && !pending)
                        Text(l.coCalendarNoRecruitment),
                      if (review.canJoin || pending)
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
                  );
                },
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
    return CoMeetingPanel(
      hub: hub,
      room: room,
      episode: episode,
      manager: true,
    );
  }
}
