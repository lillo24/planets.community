import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/people_signals.dart';
import '../application/people_attempt.dart';
import '../data/co_creation_rooms_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_rooms.dart';
import '../domain/co_creation_calendar.dart';
import 'co_creation_community_screens.dart';
import 'people_widgets.dart';
import 'co_creation_numbered_screen.dart';
import 'co_creation_places_screen.dart';
import 'co_creation_project_actions.dart';

class CoCreationHubsScreen extends ConsumerStatefulWidget {
  const CoCreationHubsScreen({super.key});
  @override
  ConsumerState<CoCreationHubsScreen> createState() => _CoHubsState();
}

class _CoHubsState extends ConsumerState<CoCreationHubsScreen> {
  final search = TextEditingController(), locality = TextEditingController();
  String query = '', place = '';
  @override
  void dispose() {
    search.dispose();
    locality.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coCreationHubs,
      actions: [
        IconButton(
          tooltip: l.coIntroReplay,
          onPressed: () => context.push('/people/intro'),
          icon: const Icon(Icons.info_outline),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => context.push('/people/community-interests'),
                child: Text(l.coCommunityYourInterests),
              ),
            ],
          ),
          Text(l.coHomeCommunityMessage),
          TextField(
            controller: search,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.coPeopleSearch),
          ),
          TextField(
            controller: locality,
            maxLength: 100,
            decoration: InputDecoration(labelText: l.coPeopleLocality),
          ),
          FilledButton(
            onPressed: () => setState(() {
              query = search.text.trim();
              place = locality.text.trim();
            }),
            child: Text(l.coPeopleSearch),
          ),
          CoCommunityCategories(
            key: ValueKey((query, place)),
            search: query,
            locality: place,
          ),
        ],
      ),
    );
  }
}

class CoCreationHubScreen extends StatelessWidget {
  const CoCreationHubScreen({required this.hubId, super.key});
  final HubId hubId;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PeoplePage(
      title: l.coCreationHubs,
      actions: [
        CoNativeProjectAction(returnPath: '/people/hubs/${hubId.value}'),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PeopleList<PublicCoHub>(
            private: false,
            load: (ref, actor, before) async {
              final h = await ref
                  .read(coCreationRoomsGatewayProvider)
                  .hub(hubId);
              return h == null ? [] : [h];
            },
            row: (context, h, refresh) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(h.label, style: Theme.of(context).textTheme.headlineSmall),
                Text(l.coRoomsHistory),
                PeopleAccess(child: _HubMembership(hub: hubId)),
                TextButton.icon(
                  onPressed: () => context.push(coCalendarRoute(hubId)),
                  icon: const Icon(Icons.calendar_month),
                  label: Text(l.coCalendarTitle),
                ),
                CoPlacesEntry(hub: hubId),
                CoNumberedList(hub: hubId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubMembership extends ConsumerStatefulWidget {
  const _HubMembership({required this.hub});
  final HubId hub;
  @override
  ConsumerState<_HubMembership> createState() => _HubMembershipState();
}

class _HubMembershipState extends ConsumerState<_HubMembership> {
  CoHubMembership? membership;
  bool busy = true, failed = false;
  int epoch = 0;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(load);
  }

  @override
  void dispose() {
    epoch++;
    super.dispose();
  }

  Future<void> load() async {
    final actor = ref.read(authSessionProvider).identity?.id,
        generation = ++epoch;
    if (actor == null) return;
    setState(() {
      busy = true;
      failed = false;
      membership = null;
    });
    try {
      final result = await ref
          .read(coCreationRoomsGatewayProvider)
          .membership(actor, widget.hub);
      if (mounted &&
          generation == epoch &&
          ref.read(authSessionProvider).identity?.id == actor) {
        setState(() {
          membership = result;
          busy = false;
        });
      }
    } catch (_) {
      if (mounted && generation == epoch) {
        setState(() {
          failed = true;
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(peopleSignalsProvider, (_, next) {
      epoch++;
      setState(() {
        membership = null;
        busy = false;
      });
      if (next.asData?.value.connected == true) {
        Future<void>.microtask(load);
      } else {
        setState(() => failed = true);
      }
    });
    final l = AppLocalizations.of(context), m = membership;
    final prior = ref.watch(peopleAttemptsProvider)['hub/${widget.hub.value}'];
    if (busy) return const LinearProgressIndicator();
    if (failed) {
      return TextButton(onPressed: load, child: Text(l.coPeopleError));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (m?.active != true ||
            (prior?.pending == true && prior!.intent['p_operation'] == 'join'))
          PeopleCommand(
            slot: 'hub/${widget.hub.value}',
            rpc: 'mutate_cocreate_hub',
            gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
            intent: {'p_hub_id': widget.hub.value, 'p_operation': 'join'},
            label: l.coRoomsJoin,
            onSuccess: (_) => load(),
          ),
        if (m != null)
          TextButton(
            onPressed: () =>
                context.push(coGeneralRoute(m.hubId, m.roomId, m.episodeId)),
            child: Text(m.active ? l.coRoomsOpenGeneral : l.coPeopleClosed),
          ),
        if (m?.active == true) ...[
          PeopleCommand(
            slot: 'hub/${widget.hub.value}',
            rpc: 'mutate_cocreate_hub',
            gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
            intent: {
              'p_hub_id': widget.hub.value,
              'p_episode_id': m!.episodeId.value,
              'p_operation': 'mute',
              'p_muted': !m.muted,
            },
            label: m.muted ? l.coRoomsUnmute : l.coRoomsMute,
            onSuccess: (_) => load(),
          ),
          TextButton(
            onPressed: () =>
                context.push(coHubLeaveRoute(m.hubId, m.episodeId)),
            child: Text(l.coRoomsLeave),
          ),
        ],
      ],
    );
  }
}
