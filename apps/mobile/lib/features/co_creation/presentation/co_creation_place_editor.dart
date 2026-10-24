import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../../policies/application/policy_documents.dart';
import '../../locations/application/place_search_controller.dart';
import '../../locations/data/item_location_gateway.dart';
import '../../locations/data/server_place_search_gateway.dart';
import '../../locations/domain/place_search.dart';
import '../../locations/presentation/location_attribution.dart';
import '../application/people_attempt.dart';
import '../application/people_signals.dart';
import '../data/co_creation_places_gateway.dart';
import '../data/co_creation_rooms_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_place.dart';
import '../domain/co_creation_places.dart';
import '../domain/co_creation_rooms.dart';
import 'co_creation_place_reads.dart';
import 'people_widgets.dart';

class CoPlaceChoice {
  const CoPlaceChoice({this.place, this.selection, this.published = false});
  final CoPlace? place;
  final ResolvedPlace? selection;
  final bool published;
  bool get safe =>
      place?.discoverySafe == true ||
      selection?.suggestion.kind == PlaceKind.amenity;
  String? get label => place?.stored.label ?? selection?.suggestion.label;
  Map<String, dynamic> get association => {
    'p_place_id': place?.id,
    'p_selection_receipt': selection?.selectionReceipt,
    'p_discoverable': published,
  };
  Map<String, dynamic> scheduling(CoPlaceContext context) => {
    ...association,
    'p_scope_episode_id': selection == null ? null : context.episode.value,
    'p_scope_revision': selection == null ? null : context.version,
  };
}

class CoMeetingPlaceOptions extends ConsumerStatefulWidget {
  const CoMeetingPlaceOptions({
    required this.hub,
    required this.onChanged,
    this.room,
    this.episode,
    super.key,
  });
  final HubId hub;
  final CoRoomId? room;
  final CoEpisodeId? episode;
  final void Function(Map<String, dynamic>?, bool) onChanged;
  @override
  ConsumerState<CoMeetingPlaceOptions> createState() =>
      _MeetingPlaceOptionsState();
}

// Scrolling must retain unsubmitted selection and its expiry clock. Account,
// policy, hint and background invalidation still erase the form subtree.
class _MeetingPlaceOptionsState extends ConsumerState<CoMeetingPlaceOptions>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CoPlacesRead<CoPlaceContext>(
      poll: false,
      retainCovered: true,
      onInvalidate: () => widget.onChanged(null, false),
      load: (ref, actor, _) => ref
          .read(coCreationRoomsGatewayProvider)
          .placeContext(
            actor,
            widget.hub,
            room: widget.room,
            episode: widget.episode,
          ),
      builder: (context, pages, refresh) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          !pages.first.manager
              ? Text(AppLocalizations.of(context).coPeopleUnavailable)
              : CoPlaceChooser(
                  key: ValueKey((
                    pages.first.episode.value,
                    pages.first.version,
                  )),
                  hub: widget.hub,
                  scope: pages.first,
                  newGroup: widget.room == null,
                  onChanged: (choice) =>
                      widget.onChanged(choice?.scheduling(pages.first), true),
                  onExpired: () => widget.onChanged(null, false),
                ),
          TextButton(
            onPressed: refresh,
            child: Text(AppLocalizations.of(context).coPeopleRefresh),
          ),
        ],
      ),
    );
  }
}

class CoUsualPlaceScreen extends StatelessWidget {
  const CoUsualPlaceScreen({
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
    title: AppLocalizations.of(context).coPlaceManage,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CoPlacesRead<CoPlaceContext>(
          poll: false,
          retainCovered: true,
          load: (ref, actor, _) => ref
              .read(coCreationRoomsGatewayProvider)
              .placeContext(actor, hub, room: room, episode: episode),
          builder: (context, pages, refresh) => _UsualForm(
            key: ValueKey((pages.first.episode.value, pages.first.version)),
            hub: hub,
            room: room,
            scope: pages.first,
            refresh: refresh,
          ),
        ),
      ],
    ),
  );
}

class _UsualForm extends ConsumerStatefulWidget {
  const _UsualForm({
    required this.hub,
    required this.room,
    required this.scope,
    required this.refresh,
    super.key,
  });
  final HubId hub;
  final CoRoomId room;
  final CoPlaceContext scope;
  final Future<void> Function() refresh;
  @override
  ConsumerState<_UsualForm> createState() => _UsualFormState();
}

class _UsualFormState extends ConsumerState<_UsualForm> {
  CoPlaceChoice? choice;
  bool expired = false;
  @override
  void initState() {
    super.initState();
    if (widget.scope.usual != null) {
      choice = CoPlaceChoice(
        place: widget.scope.usual,
        published: widget.scope.published,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        slot = 'usual-place/${widget.room.value}';
    final pending = ref.watch(peopleAttemptsProvider)[slot]?.pending == true;
    if (!widget.scope.manager && !pending) return Text(l.coPeopleUnavailable);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.coPlaceUsualHint),
        if (!pending)
          CoPlaceChooser(
            hub: widget.hub,
            scope: widget.scope,
            newGroup: false,
            usual: true,
            initial: choice,
            onChanged: (c) => setState(() {
              choice = c;
              expired = false;
            }),
            onExpired: () => setState(() {
              choice = null;
              expired = true;
            }),
          ),
        if (expired) Text(l.coPlaceExpired),
        if (!expired || pending)
          PeopleCommand(
            slot: slot,
            rpc: 'set_cocreate_usual_place_v1',
            gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
            intent: {
              'p_hub_id': widget.hub.value,
              'p_room_id': widget.room.value,
              'p_episode_id': widget.scope.episode.value,
              'p_expected_version': widget.scope.version,
              ...(choice?.association ??
                  const {
                    'p_place_id': null,
                    'p_selection_receipt': null,
                    'p_discoverable': false,
                  }),
            },
            label: choice == null ? l.coPlaceClear : l.coPlaceSave,
            onSuccess: (_) async => widget.refresh(),
          ),
        TextButton(onPressed: widget.refresh, child: Text(l.coPeopleRefresh)),
      ],
    );
  }
}

class CoPlaceChooser extends ConsumerStatefulWidget {
  const CoPlaceChooser({
    required this.hub,
    required this.scope,
    required this.newGroup,
    required this.onChanged,
    this.usual = false,
    this.onExpired,
    this.initial,
    super.key,
  });
  final HubId hub;
  final CoPlaceContext scope;
  final bool newGroup, usual;
  final CoPlaceChoice? initial;
  final void Function(CoPlaceChoice?) onChanged;
  final VoidCallback? onExpired;
  @override
  ConsumerState<CoPlaceChooser> createState() => _ChooserState();
}

class _ChooserState extends ConsumerState<CoPlaceChooser> {
  CoPlaceChoice? choice;
  Timer? expiry;
  @override
  void initState() {
    super.initState();
    choice = widget.initial;
  }

  void choose(CoPlaceChoice? c) {
    expiry?.cancel();
    setState(() => choice = c);
    widget.onChanged(c);
    if (c?.selection case final selection?) {
      expiry = Timer(
        selection.suggestion.expiresAt.difference(DateTime.now()),
        () {
          if (mounted) {
            setState(() => choice = null);
            widget.onExpired?.call();
          }
        },
      );
    }
  }

  Future<void> search() async {
    final actor = ref.read(authSessionProvider).identity!.id;
    final selected = await showDialog<ResolvedPlace>(
      context: context,
      builder: (_) => _VenueSearch(
        scope: PlaceSearchScope(
          actorId: actor,
          itemKind: widget.newGroup ? 'cocreate_hub' : 'cocreate_room',
          itemId: widget.scope.episode.value,
          revision: widget.scope.version,
          slot: 'exact',
        ),
      ),
    );
    if (mounted &&
        selected != null &&
        selected.suggestion.expiresAt.isAfter(DateTime.now())) {
      choose(CoPlaceChoice(selection: selected));
    }
  }

  Future<void> reuse() async {
    final selected = await showDialog<CoPlace>(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: CoPlacesRead<CoPlacesPage>(
              load: (ref, actor, before) async {
                final g = ref.read(coCreationRoomsGatewayProvider),
                    m = await g.membership(actor, widget.hub);
                if (m?.active != true) throw StateError('Community required.');
                return g.places(
                  actor,
                  widget.hub,
                  m!.episodeId,
                  after: before?.cursor,
                );
              },
              more: (p) => p.cursor != null,
              builder: (context, pages, _) => Column(
                children: [
                  if (pages.first.places.isEmpty)
                    Text(AppLocalizations.of(context).coPlacesEmpty),
                  for (final s in pages.expand((p) => p.places))
                    ListTile(
                      title: Text(s.place.stored.label),
                      subtitle: Text(s.place.stored.locality),
                      onTap: () => Navigator.of(context).pop(s.place),
                    ),
                  const LocationAttribution(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted && selected != null) choose(CoPlaceChoice(place: selected));
  }

  @override
  void dispose() {
    expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.usual ? l.coPlaceUsual : l.coPlaceMeeting,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(choice?.label ?? l.coPlaceNone),
        if (choice != null) const LocationAttribution(),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => choose(null),
              child: Text(l.coPlaceNone),
            ),
            if (widget.scope.usual != null)
              TextButton(
                onPressed: () =>
                    choose(CoPlaceChoice(place: widget.scope.usual)),
                child: Text(l.coPlaceUseUsual),
              ),
            TextButton(onPressed: search, child: Text(l.coPlaceChooseVerified)),
            TextButton(onPressed: reuse, child: Text(l.coPlaceReuse)),
          ],
        ),
        if (choice?.safe == true)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.coPlaceDiscovery),
            value: choice!.published,
            onChanged: (v) => choose(
              CoPlaceChoice(
                place: choice!.place,
                selection: choice!.selection,
                published: v,
              ),
            ),
          ),
        if (choice != null && choice?.safe != true) Text(l.coPlacePrivate),
      ],
    );
  }
}

class _VenueSearch extends ConsumerStatefulWidget {
  const _VenueSearch({required this.scope});
  final PlaceSearchScope scope;
  @override
  ConsumerState<_VenueSearch> createState() => _SearchState();
}

class _SearchState extends ConsumerState<_VenueSearch>
    with WidgetsBindingObserver {
  late final PlaceSearchController search;
  final text = TextEditingController();
  bool cancelled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    search = PlaceSearchController(
      gateway: ref.read(editorPlaceGatewayFactoryProvider).create(widget.scope),
    );
  }

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    search.cancel();
    text.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    search.dispose();
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (_, next) {
      if (next.identity?.id != widget.scope.actorId ||
          next.phase != AuthSessionPhase.ready) {
        cancel();
      }
    });
    ref.listen(coCreationRoomsGatewayProvider, (_, _) => cancel());
    ref.listen(peopleSignalsProvider, (_, _) => cancel());
    ref.listen(policyAcceptanceProvider, (_, next) {
      if (!next.allows(widget.scope.actorId, ref.read(policyVersionProvider))) {
        cancel();
      }
    });
    ref.listen(policyVersionProvider, (_, _) => cancel());
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.locationSearchTitle),
      content: SingleChildScrollView(
        child: ListenableBuilder(
          listenable: search,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (search.phase == PlaceSearchPhase.disabled)
                Text(l.coPlaceSearchUnavailable)
              else ...[
                TextField(
                  controller: text,
                  decoration: InputDecoration(labelText: l.coPlacesTitle),
                  onChanged: (v) => search.edit(
                    v,
                    language: Localizations.localeOf(context).languageCode,
                  ),
                ),
                if ({
                  PlaceSearchPhase.waiting,
                  PlaceSearchPhase.searching,
                  PlaceSearchPhase.resolving,
                }.contains(search.phase))
                  const LinearProgressIndicator(),
                if (search.phase == PlaceSearchPhase.failure)
                  Text(l.coPeopleError),
                for (final suggestion in search.suggestions.where(
                  (s) => s.kind != PlaceKind.locality,
                ))
                  ListTile(
                    title: Text(suggestion.label),
                    onTap: () async {
                      await search.select(suggestion);
                      final selected = search.selection;
                      if (mounted &&
                          context.mounted &&
                          !cancelled &&
                          selected != null &&
                          ModalRoute.of(context)?.isCurrent == true) {
                        Navigator.of(context).pop(selected);
                      }
                    },
                  ),
              ],
              const LocationAttribution(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonTooltip),
        ),
      ],
    );
  }
}
