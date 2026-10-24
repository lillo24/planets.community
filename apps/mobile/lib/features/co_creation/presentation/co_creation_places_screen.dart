import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../locations/presentation/location_attribution.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../../policies/application/policy_documents.dart';
import '../data/co_creation_places_gateway.dart';
import '../data/co_creation_rooms_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_place.dart';
import '../domain/co_creation_places.dart';
import '../domain/co_creation_rooms.dart';
import 'co_creation_meeting_screen.dart';
import 'co_creation_place_reads.dart';
import 'people_widgets.dart';

class CoPlaceLink extends StatelessWidget {
  const CoPlaceLink({required this.hub, required this.place, super.key});
  final HubId hub;
  final CoPlace place;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: () => context.push(coPlaceRoute(hub, place.id)),
        icon: const Icon(Icons.place_outlined),
        label: Text(place.stored.label),
      ),
      const LocationAttribution(),
    ],
  );
}

class CoPlacesEntry extends ConsumerWidget {
  const CoPlacesEntry({required this.hub, super.key});
  final HubId hub;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(authSessionProvider).phase != AuthSessionPhase.ready ||
          !ref
              .watch(policyAcceptanceProvider)
              .allows(
                ref.watch(authSessionProvider).identity?.id,
                ref.watch(policyVersionProvider),
              )
      ? const SizedBox.shrink()
      : CoPlacesRead<CoPlacesPage?>(
          load: (ref, actor, _) async {
            final g = ref.read(coCreationRoomsGatewayProvider),
                m = await g.membership(actor, hub);
            if (m?.active != true) return null;
            return g.places(actor, hub, m!.episodeId);
          },
          builder: (context, pages, _) => pages.first?.places.isNotEmpty == true
              ? TextButton.icon(
                  onPressed: () => context.push(coPlacesRoute(hub)),
                  icon: const Icon(Icons.place_outlined),
                  label: Text(AppLocalizations.of(context).coPlacesTitle),
                )
              : const SizedBox.shrink(),
        );
}

class CoGroupPlaceSection extends StatelessWidget {
  const CoGroupPlaceSection({
    required this.hub,
    required this.room,
    required this.episode,
    super.key,
  });
  final HubId hub;
  final CoRoomId room;
  final CoEpisodeId episode;
  @override
  Widget build(BuildContext context) => CoPlacesRead<CoPlaceContext>(
    load: (ref, actor, _) => ref
        .read(coCreationRoomsGatewayProvider)
        .placeContext(actor, hub, room: room, episode: episode),
    builder: (context, pages, _) {
      final c = pages.first, l = AppLocalizations.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.coPlaceUsual, style: Theme.of(context).textTheme.titleSmall),
          if (c.usual != null)
            CoPlaceLink(hub: hub, place: c.usual!)
          else
            Text(l.coPlaceNone),
          if (c.manager)
            TextButton(
              onPressed: () =>
                  context.push(coUsualPlaceRoute(hub, room, episode)),
              child: Text(l.coPlaceManage),
            ),
        ],
      );
    },
  );
}

class CoPlacesScreen extends StatelessWidget {
  const CoPlacesScreen({required this.hub, super.key});
  final HubId hub;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coPlacesTitle,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CoPlacesRead<CoPlacesPage>(
            load: (ref, actor, before) async {
              final g = ref.read(coCreationRoomsGatewayProvider),
                  m = await g.membership(actor, hub);
              if (m?.active != true) {
                throw StateError('Current community admission required.');
              }
              if (before != null && before.episode != m!.episodeId) {
                throw StateError('Community episode changed; refresh Places.');
              }
              return g.places(actor, hub, m!.episodeId, after: before?.cursor);
            },
            more: (p) => p.cursor != null,
            builder: (context, pages, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pages.first.places.isEmpty) Text(l.coPlacesEmpty),
                for (final s in pages.expand((p) => p.places))
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(s.place.stored.label),
                      subtitle: Text(
                        '${s.place.stored.locality}\n${l.coPlaceCounts(s.groups, s.meetings)}${s.available ? '\n${l.coCalendarAvailable}' : ''}',
                      ),
                      onTap: () => context.push(coPlaceRoute(hub, s.place.id)),
                    ),
                  ),
                if (pages.any((p) => p.places.isNotEmpty))
                  const LocationAttribution(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CoPlaceDetailScreen extends StatelessWidget {
  const CoPlaceDetailScreen({
    required this.hub,
    required this.placeId,
    super.key,
  });
  final HubId hub;
  final String placeId;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coPlacesTitle,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CoPlacesRead<(CoPlaceDetail, CoHubMembership)>(
            load: (ref, actor, before) async {
              final g = ref.read(coCreationRoomsGatewayProvider),
                  m = await g.membership(actor, hub);
              if (m?.active != true ||
                  (before != null && before.$2.episodeId != m!.episodeId)) {
                throw StateError('Current community episode required.');
              }
              return (
                await g.placeDetail(
                  actor,
                  hub,
                  m!.episodeId,
                  placeId,
                  after: before?.$1.next,
                ),
                m,
              );
            },
            more: (p) => p.$1.next != null,
            builder: (context, pages, _) {
              final p = pages.first.$1.place;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    p.stored.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(p.stored.locality),
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.https('www.google.com', '/maps/search/', {
                        'api': '1',
                        'query': '${p.point.latitude},${p.point.longitude}',
                      }),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.directions_outlined),
                    label: Text(l.locationOpenGoogleMaps),
                  ),
                  const LocationAttribution(),
                  for (final page in pages)
                    for (final g in page.$1.groups)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l.coGroupsNumber(g.number),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (g.usual) Text(l.coPlaceUsual),
                              if (g.meeting case final m?) ...[
                                Text(coMeetingTime(context, m.startsAt)),
                                Text(l.coMeetingPlaces(m.occupied, m.capacity)),
                                Text(
                                  m.attending
                                      ? l.coMeetingAttending
                                      : m.full
                                      ? l.coGroupsFull
                                      : m.available
                                      ? l.coCalendarAvailable
                                      : l.coCalendarNoRecruitment,
                                ),
                                TextButton(
                                  onPressed: () =>
                                      context.push(m.reviewRoute(hub, page.$2)),
                                  child: Text(l.coPlaceReviewMeeting),
                                ),
                              ] else
                                TextButton(
                                  onPressed: () => context.push(
                                    '/people/hubs/${hub.value}/groups/${g.room.value}',
                                  ),
                                  child: Text(l.coGroupsOpen),
                                ),
                            ],
                          ),
                        ),
                      ),
                  if (pages.first.$1.groups.isEmpty) Text(l.coPlacesEmpty),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
