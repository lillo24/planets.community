import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../group_projects/domain/group_project_creation_return.dart';
import '../data/co_creation_sources_gateway.dart';
import '../data/co_creation_rooms_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_rooms.dart';
import '../application/people_attempt.dart';
import 'people_widgets.dart';

class CoPostGroupLinkScreen extends ConsumerWidget {
  const CoPostGroupLinkScreen({required this.post, super.key});
  final PostId post;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final prior = ref.watch(
      peopleAttemptsProvider,
    )['post-source/${post.value}'];
    final pending = prior?.pending == true;
    return PeoplePage(
      title: l.coSourceLink,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.coSourceNotice),
          TextButton(
            onPressed: () => context.push('/people/hubs'),
            child: Text(l.coSourceCreateGroup),
          ),
          PeopleAccess(
            child: PeopleList<CoPostLinkContext>(
              load: (ref, actor, before) async => [
                await ref
                    .read(coCreationSourcesGatewayProvider)
                    .post(actor!, post),
              ],
              row: (context, p, refresh) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(p.title),
                  if (p.link != null) CoSourceGroupView(link: p.link!),
                  if (pending)
                    PeopleCommand(
                      slot: 'post-source/${post.value}',
                      rpc: 'mutate_cocreate_post_group',
                      gateway: (ref) =>
                          ref.read(coCreationSourcesGatewayProvider),
                      intent: prior!.intent,
                      label: l.coPeopleRetry,
                      onSuccess: (_) => refresh(),
                    ),
                  if (p.link != null && !pending)
                    PeopleCommand(
                      slot: 'post-source/${post.value}',
                      rpc: 'mutate_cocreate_post_group',
                      gateway: (ref) =>
                          ref.read(coCreationSourcesGatewayProvider),
                      intent: {
                        'p_post_id': post.value,
                        'p_expected_version': p.version,
                        'p_operation': 'clear',
                      },
                      label: l.coSourceClear,
                      onSuccess: (_) => refresh(),
                    ),
                  if (!pending)
                    PeopleList<CoRoomSummary>(
                      key: ValueKey(p.version),
                      load: (ref, actor, before) => ref
                          .read(coCreationRoomsGatewayProvider)
                          .rooms(actor!, before: before, manageable: true),
                      row: (context, r, reload) => Column(
                        children: [
                          Text(
                            '${l.coGroupsNumber(r.number!)} · ${r.topic} · ${r.locality}',
                          ),
                          PeopleCommand(
                            slot: 'post-source/${post.value}',
                            rpc: 'mutate_cocreate_post_group',
                            gateway: (ref) =>
                                ref.read(coCreationSourcesGatewayProvider),
                            intent: {
                              'p_post_id': post.value,
                              'p_expected_version': p.version,
                              'p_operation': 'link',
                              'p_hub_id': r.hubId.value,
                              'p_room_id': r.roomId.value,
                              'p_episode_id': r.episodeId.value,
                            },
                            label: l.coSourceChoose,
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

class CoSourceGroupView extends StatelessWidget {
  const CoSourceGroupView({required this.link, super.key});
  final CoLinkedGroup link;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), g = link.group;
    if (!link.available) return Text(l.coPeopleUnavailable);
    return Column(
      children: [
        Text(
          '${l.coGroupsNumber(g!.number)} · ${link.topic} · ${link.locality}',
        ),
        Text('${g.occupied}/${g.capacity}'),
        Text(l.coGroupsDisclosure),
        TextButton(
          onPressed: () => context.push(
            '/messages/cocreate/hubs/${g.hubId.value}/groups/${g.roomId.value}/join',
          ),
          child: Text(l.coSourceReview),
        ),
      ],
    );
  }
}

class CoContactGroupAction extends StatelessWidget {
  const CoContactGroupAction({required this.contact, super.key});
  final String contact;
  @override
  Widget build(BuildContext context) => PeopleList<CoLinkedGroup>(
    emptyVisible: false,
    load: (ref, actor, before) async {
      final r = await ref
          .read(coCreationSourcesGatewayProvider)
          .contact(actor!, contact);
      return r == null ? [] : [r];
    },
    row: (context, link, refresh) => TextButton(
      onPressed: () =>
          context.push('/messages/cocreate/contacts/$contact/group'),
      child: Text(AppLocalizations.of(context).coSourceReview),
    ),
  );
}

class CoContactGroupScreen extends StatelessWidget {
  const CoContactGroupScreen({required this.contact, super.key});
  final String contact;
  @override
  Widget build(BuildContext context) => PeoplePage(
    title: AppLocalizations.of(context).coSourceLink,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PeopleAccess(
          child: PeopleList<CoLinkedGroup>(
            load: (ref, actor, before) async {
              final r = await ref
                  .read(coCreationSourcesGatewayProvider)
                  .contact(actor!, contact);
              return r == null ? [] : [r];
            },
            row: (context, link, refresh) => CoSourceGroupView(link: link),
          ),
        ),
      ],
    ),
  );
}

class CoGroupProjects extends ConsumerWidget {
  const CoGroupProjects({
    required this.hub,
    required this.room,
    required this.episode,
    required this.manager,
    this.active = true,
    super.key,
  });
  final HubId hub;
  final CoRoomId room;
  final CoEpisodeId episode;
  final bool manager, active;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final pending =
        ref
            .watch(peopleAttemptsProvider)['source-project/${room.value}']
            ?.pending ==
        true;
    return Column(
      children: [
        if (manager || pending) ...[
          Text(l.coSourceProjectNotice),
          PeopleCommand(
            slot: 'source-project/${room.value}',
            rpc: 'create_cocreate_project_draft',
            gateway: (ref) => ref.read(coCreationSourcesGatewayProvider),
            intent: {
              'p_hub_id': hub.value,
              'p_room_id': room.value,
              'p_episode_id': episode.value,
            },
            label: l.coSourceProject,
            onSuccess: (r) async {
              final actor = ref.read(authSessionProvider).identity?.id;
              if (actor == null) return;
              await context.push(
                '/proposals/${r['proposal_id']}/edit',
                extra: GroupProjectCreationReturn(
                  actor,
                  returnPath: coNumberedRoute(hub, room, episode),
                ),
              );
            },
          ),
        ],
        if (active)
          PeopleList<CoSourceProject>(
            emptyVisible: false,
            load: (ref, actor, before) => ref
                .read(coCreationSourcesGatewayProvider)
                .projects(actor!, room, episode, before: before),
            row: (context, p, refresh) => TextButton(
              onPressed: () => context.push('/proposals/${p.id}'),
              child: Text(l.coSourcePublishedProject),
            ),
          ),
      ],
    );
  }
}
