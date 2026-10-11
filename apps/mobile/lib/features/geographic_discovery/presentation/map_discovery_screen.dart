import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../app/router/browse_activity_switcher.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../cover_media/presentation/cover_image.dart';
import '../../drafts/domain/draft_entry.dart';
import '../../locations/presentation/location_attribution.dart';
import '../../proposals/application/proposal_controllers.dart';
import '../../proposals/domain/proposal_time.dart';
import '../../recurring_activities/application/recurring_activity_controllers.dart';
import '../../resource_listings/application/resource_listing_controllers.dart';
import '../application/geographic_discovery_controller.dart';
import '../application/map_discovery_sessions.dart';
import '../application/shared_basemap_tiles.dart';
import '../data/map_provider_gateway.dart';
import '../domain/geographic_discovery.dart';
import '../domain/map_discovery.dart';
import 'map_view_button.dart';
import 'public_point_map.dart';

class MapDiscoveryScreen extends ConsumerStatefulWidget {
  const MapDiscoveryScreen({required this.origin, super.key});
  final MapDiscoveryOrigin origin;
  @override
  ConsumerState<MapDiscoveryScreen> createState() => _MapDiscoveryScreenState();
}

class _MapDiscoveryScreenState extends ConsumerState<MapDiscoveryScreen>
    with WidgetsBindingObserver {
  late MapDiscoveryPreferences _preferences;
  late GeoQuery _filters;
  final _camera = MapController();
  final _placeInput = TextEditingController();
  final _cardKey = GlobalKey();
  GoRouter? _router;
  GatewayTileProvider? _tiles;
  GeoBounds? _viewport;
  bool _active = false, _foreground = true, _dirty = false, _tileFailed = false;
  String? _selectedIdentity, _centerError;
  List<MapCenterSuggestion> _suggestions = const [];
  Timer? _debounce;
  int _centerEpoch = 0;
  int _viewEpoch = 0;
  bool _disposed = false;
  late GeographicDiscoveryController _discovery;
  bool _centerBusy = false;
  String get _contextId => 'map05:${widget.origin.name}';
  String get _path => '/discover/map/${widget.origin.name}';

  @override
  void initState() {
    super.initState();
    _discovery = ref.read(geographicDiscoveryProvider(_contextId).notifier);
    WidgetsBinding.instance.addObserver(this);
    _restorePreferences();
  }

  void _restorePreferences() {
    _preferences = ref
        .read(mapDiscoverySessionsProvider)
        .forOrigin(widget.origin);
    _placeInput.text = _preferences.centerLabel;
    final projects = ref.read(publicProposalsProvider);
    final tavoli = ref.read(publicRecurringActivitiesProvider);
    final resources = ref.read(publicResourceListingsProvider);
    _filters = GeoQuery(
      area: _area,
      proposalKeyword: projects.query,
      proposalLocality: projects.locality,
      proposalSkillIds: projects.selectedSkillIds.toList()..sort(),
      tavoloLocality: tavoli.locality,
      resourceKeyword: resources.query,
      resourceLocality: resources.locality,
      resourceMode: resources.modeFilter == null
          ? null
          : GeoResourceMode.values.byName(resources.modeFilter!.name),
    );
  }

  GeoArea get _area =>
      _preferences.searchedBounds ??
      GeoRadius(
        _preferences.latitude,
        _preferences.longitude,
        _preferences.radiusKm * 1000,
      );
  bool get _projects =>
      _preferences.family == MapDiscoveryFamily.all ||
      _preferences.family == MapDiscoveryFamily.projects;
  bool get _tavoli =>
      _preferences.family == MapDiscoveryFamily.all ||
      _preferences.family == MapDiscoveryFamily.tavoli;
  bool get _resources =>
      _preferences.family == MapDiscoveryFamily.all ||
      _preferences.family == MapDiscoveryFamily.resources;

  GeoQuery get _query => GeoQuery(
    area: _area,
    kinds: switch (_preferences.family) {
      MapDiscoveryFamily.all => GeoKind.values.toSet(),
      MapDiscoveryFamily.projects => {GeoKind.oneTime},
      MapDiscoveryFamily.tavoli => {GeoKind.recurring},
      MapDiscoveryFamily.resources => {GeoKind.resource},
    },
    proposalKeyword: _projects ? _filters.proposalKeyword : null,
    proposalLocality: _projects ? _filters.proposalLocality : null,
    proposalSkillIds: _projects ? _filters.proposalSkillIds : const [],
    tavoloLocality: _tavoli ? _filters.tavoloLocality : null,
    resourceKeyword: _resources ? _filters.resourceKeyword : null,
    resourceLocality: _resources ? _filters.resourceLocality : null,
    resourceMode: _resources ? _filters.resourceMode : null,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_queueActivity);
      _router = router;
      router.routerDelegate.addListener(_queueActivity);
    }
    _queueActivity();
  }

  void _queueActivity() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      final phase = ref.read(authSessionProvider).phase;
      final ready = {
        AuthSessionPhase.signedOut,
        AuthSessionPhase.ready,
        AuthSessionPhase.profileSetupRequired,
      }.contains(phase);
      _setActive(
        _foreground && ready && _router?.routerDelegate.state.uri.path == _path,
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _setActive(bool value) {
    if (_active == value) return;
    _active = value;
    _viewEpoch++;
    _centerEpoch++;
    _debounce?.cancel();
    _suggestions = const [];
    _centerBusy = false;
    _tiles?.dispose();
    _tiles = null;
    _discovery.cancel();
    _discovery.setActive(value);
    if (value) {
      _tileFailed = false;
      _syncTiles();
      unawaited(_discovery.search(_query));
    }
    setState(() {});
  }

  bool _allowed(MapProviderGateway gateway) =>
      _active &&
      (!gateway.requiresAuthentication ||
          ref.read(authSessionProvider).identity != null);
  void _syncTiles() {
    final gateway = ref.read(mapProviderGatewayProvider);
    if (_allowed(gateway) && gateway.tilesEnabled && !_tileFailed) {
      _tiles ??= GatewayTileProvider(ref.read(sharedBasemapTilesProvider));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Cancel immediately; do not wait for an animation frame in the background.
    if (!_foreground) _setActive(false);
    _queueActivity();
  }

  @override
  void dispose() {
    _disposed = true;
    _centerEpoch++;
    _debounce?.cancel();
    _tiles?.dispose();
    _router?.routerDelegate.removeListener(_queueActivity);
    WidgetsBinding.instance.removeObserver(this);
    final controller = _discovery;
    Future.microtask(() {
      controller.cancel();
      controller.setActive(false);
    });
    _camera.dispose();
    _placeInput.dispose();
    super.dispose();
  }

  void _family(MapDiscoveryFamily family) {
    if (_preferences.family == family) return;
    final origin = switch (family) {
      MapDiscoveryFamily.all => widget.origin,
      MapDiscoveryFamily.projects => MapDiscoveryOrigin.projects,
      MapDiscoveryFamily.tavoli => MapDiscoveryOrigin.tavoli,
      MapDiscoveryFamily.resources => MapDiscoveryOrigin.resources,
    };
    ref.read(mapDiscoverySessionsProvider).forOrigin(origin).family = family;
    if (origin == widget.origin) {
      _search();
    } else {
      // Replace the Browse location rather than stacking successive Maps. The
      // canonical origin also owns List, Create, Drafts and session preferences.
      context.go('/discover/map/${origin.name}');
    }
  }

  void _returnToList() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(switch (widget.origin) {
        MapDiscoveryOrigin.projects => '/proposals',
        MapDiscoveryOrigin.tavoli => '/tavoli',
        MapDiscoveryOrigin.resources => '/resources',
      });
    }
  }

  void _search() {
    _viewEpoch++;
    _selectedIdentity = null;
    _dirty = false;
    if (_active) unawaited(_discovery.search(_query));
    setState(() {});
  }

  void _cameraChanged(
    GeoBounds bounds,
    double lat,
    double lon,
    double zoom,
    bool gesture,
  ) {
    _preferences.cameraLatitude = lat;
    _preferences.cameraLongitude = lon;
    _preferences.zoom = zoom;
    _viewport = bounds;
    if (gesture) _dirty = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _active) setState(() {});
    });
  }

  void _radius(double km, {bool move = true}) {
    _preferences.radiusKm = km;
    _preferences.searchedBounds = null;
    if (move) {
      _camera.move(
        LatLng(_preferences.latitude, _preferences.longitude),
        (14 - math.log(km) / math.ln2).clamp(7, 18).toDouble(),
      );
    }
    _search();
  }

  void _placeChanged(String text) {
    _debounce?.cancel();
    final epoch = ++_centerEpoch;
    setState(() {
      _suggestions = const [];
      _centerError = null;
      _centerBusy = false;
    });
    if (text.trim().runes.length < 2) return;
    final gateway = ref.read(mapProviderGatewayProvider);
    if (!gateway.centerEnabled || !_allowed(gateway)) return;
    final language = Localizations.localeOf(context).languageCode == 'it'
        ? 'it'
        : 'en';
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!_active || epoch != _centerEpoch) return;
      setState(() => _centerBusy = true);
      try {
        final rows = await gateway.search(text, language);
        if (!mounted || !_active || epoch != _centerEpoch) return;
        setState(() {
          _suggestions = rows;
          _centerBusy = false;
        });
      } catch (error) {
        if (!mounted || !_active || epoch != _centerEpoch) return;
        setState(() {
          _centerBusy = false;
          _centerError = error is MapProviderFailure
              ? error.status
              : 'unavailable';
        });
      }
    });
  }

  Future<void> _chooseCenter(MapCenterSuggestion suggestion) async {
    _debounce?.cancel();
    final epoch = ++_centerEpoch;
    setState(() {
      _centerBusy = true;
      _suggestions = const [];
      _centerError = null;
    });
    try {
      final center = await ref
          .read(mapProviderGatewayProvider)
          .resolve(suggestion.id);
      if (!mounted || !_active || epoch != _centerEpoch) return;
      setState(() {
        _preferences.latitude = center.latitude;
        _preferences.longitude = center.longitude;
        _preferences.centerLabel = center.label;
        _placeInput.text = center.label;
        _centerBusy = false;
      });
      FocusManager.instance.primaryFocus?.unfocus();
      _radius(_preferences.radiusKm);
    } catch (error) {
      if (!mounted || !_active || epoch != _centerEpoch) return;
      setState(() {
        _centerBusy = false;
        _centerError = error is MapProviderFailure
            ? error.status
            : 'unavailable';
      });
    }
  }

  void _select(GeoItem item) {
    setState(() => _selectedIdentity = item.identity);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cardKey.currentContext case final card?) {
        unawaited(
          Scrollable.ensureVisible(
            card,
            duration: const Duration(milliseconds: 250),
          ),
        );
      }
    });
  }

  Future<void> _cluster(PublicPointCluster cluster) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (cluster.items.length == 1) {
      _select(cluster.anchor);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final viewEpoch = _viewEpoch;
    final selected = await showModalBottomSheet<GeoItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height:
              (MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom) *
              0.65,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  key: const Key('map-cluster-choices'),
                  itemCount: cluster.items.length + 1,
                  itemBuilder: (context, index) {
                    // The heading scrolls too: large text plus a keyboard must
                    // leave space for choices while attribution stays visible.
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.mapClusterLoaded(cluster.items.length),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      );
                    }
                    final item = cluster.items[index - 1];
                    return ListTile(
                      key: Key('map-cluster-item-${item.identity}'),
                      title: Text(item.title),
                      subtitle: Text(
                        '${_kind(item, l10n)} · ${item.locationLabel}',
                      ),
                      leading: Icon(
                        item.isApproximate
                            ? Icons.radio_button_unchecked
                            : Icons.place,
                      ),
                      onTap: () => Navigator.of(context).pop(item),
                    );
                  },
                ),
              ),
              const LocationAttribution(),
            ],
          ),
        ),
      ),
    );
    if (mounted &&
        _active &&
        viewEpoch == _viewEpoch &&
        selected != null &&
        ref
            .read(geographicDiscoveryProvider(_contextId))
            .items
            .any((i) => i.identity == selected.identity)) {
      _select(selected);
    }
  }

  String _kind(GeoItem item, AppLocalizations l10n) => switch (item.kind) {
    GeoKind.oneTime => l10n.proposalsTitle,
    GeoKind.recurring => l10n.tavoliTitle,
    GeoKind.resource =>
      item.resourceMode == GeoResourceMode.donate
          ? l10n.resourceModeDonate
          : l10n.resourceModeExchange,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(geographicDiscoveryProvider(_contextId));
    final gateway = ref.watch(mapProviderGatewayProvider);
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      _,
      _,
    ) {
      _centerEpoch++;
      _tiles?.dispose();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _disposed) return;
        _setActive(false);
        _restorePreferences();
        _selectedIdentity = null;
        _centerError = null;
        _viewport = null;
        _dirty = false;
        _queueActivity();
      });
    });
    final canSearchCenter = gateway.centerEnabled && _allowed(gateway);
    final selected = state.items
        .where((i) => i.identity == _selectedIdentity)
        .firstOrNull;
    final viewport = _viewport;
    final usable = viewport != null && isUsableMapViewport(viewport);
    final filterLabels = [
      if (_query.proposalKeyword?.isNotEmpty == true)
        '${l10n.proposalsTitle}: ${_query.proposalKeyword}',
      if (_query.proposalLocality?.isNotEmpty == true)
        '${l10n.proposalsTitle}: ${_query.proposalLocality}',
      if (_query.proposalSkillIds.isNotEmpty)
        l10n.mapSkills(_query.proposalSkillIds.length),
      if (_query.tavoloLocality?.isNotEmpty == true)
        '${l10n.tavoliTitle}: ${_query.tavoloLocality}',
      if (_query.resourceKeyword?.isNotEmpty == true)
        '${l10n.resourceTitle}: ${_query.resourceKeyword}',
      if (_query.resourceLocality?.isNotEmpty == true)
        '${l10n.resourceTitle}: ${_query.resourceLocality}',
      if (_query.resourceMode != null)
        _query.resourceMode == GeoResourceMode.donate
            ? l10n.resourceModeDonate
            : l10n.resourceModeExchange,
    ];
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _returnToList();
      },
      child: Scaffold(
        appBar: pageAppBar(
          context,
          // List is the visible exit; keep the two icon actions in one toolbar.
          automaticallyImplyClose: false,
          title: Text(l10n.mapView),
          actions: [
            IconButton(
              key: const Key('map-drafts'),
              tooltip: l10n.draftsTitle,
              icon: const Icon(Icons.folder_outlined),
              onPressed: () => context.push(
                DraftRoutes.contextual(switch (widget.origin) {
                  MapDiscoveryOrigin.projects => {DraftKind.project},
                  MapDiscoveryOrigin.tavoli => {DraftKind.table},
                  MapDiscoveryOrigin.resources => {
                    DraftKind.donate,
                    DraftKind.exchange,
                  },
                }),
              ),
            ),
            IconButton(
              key: const Key('map-create'),
              tooltip: l10n.mapCreate,
              icon: const Icon(Icons.add),
              onPressed: () => context.push(
                '${switch (widget.origin) {
                  MapDiscoveryOrigin.projects => '/proposals',
                  MapDiscoveryOrigin.tavoli => '/tavoli',
                  MapDiscoveryOrigin.resources => '/resources',
                }}/create',
              ),
            ),
          ],
        ),
        bottomNavigationBar: const SafeArea(
          child: IntrinsicHeight(child: LocationAttribution(centered: true)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            // Keep one map/controller mounted while its controls and card scroll.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.origin != MapDiscoveryOrigin.resources) ...[
                  BrowseActivitySwitcher(
                    showGroupsEntry: false,
                    selected: switch (_preferences.family) {
                      MapDiscoveryFamily.projects =>
                        BrowseActivityType.proposals,
                      MapDiscoveryFamily.tavoli => BrowseActivityType.tavoli,
                      _ => null,
                    },
                    onChanged: (type) => _family(
                      type == BrowseActivityType.proposals
                          ? MapDiscoveryFamily.projects
                          : MapDiscoveryFamily.tavoli,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                MapViewButton(origin: widget.origin, mapSelected: true),
                const SizedBox(height: 8),
                SizedBox(
                  key: const Key('map-viewport'),
                  height: 340,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _active
                            ? PublicPointMap(
                                controller: _camera,
                                preferences: _preferences,
                                clusters: clusterPublicPoints(
                                  state.items,
                                  _preferences.zoom,
                                ),
                                tileProvider: _tiles,
                                onCamera: _cameraChanged,
                                onCluster: _cluster,
                                markerLabel: (item) =>
                                    '${_kind(item, l10n)}: ${item.title}. ${item.isApproximate ? l10n.mapApproximate : l10n.mapPrecise}',
                                clusterLabel: l10n.mapClusterLoaded,
                                onTileError: () {
                                  if (_tileFailed || !_active) return;
                                  _tileFailed = true;
                                  _tiles?.dispose();
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) setState(() => _tiles = null);
                                  });
                                },
                              )
                            : const Center(child: CircularProgressIndicator()),
                      ),
                      if (_tiles == null)
                        Positioned(
                          top: 8,
                          left: 8,
                          right: 8,
                          child: IgnorePointer(
                            child: Material(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _tileFailed
                                        ? l10n.mapBasemapFailed
                                        : l10n.mapBasemapDisabled,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      key: const Key('map-zoom-in'),
                      tooltip: l10n.mapZoomIn,
                      onPressed: !_active
                          ? null
                          : () {
                              _dirty = true;
                              _camera.move(
                                _camera.camera.center,
                                (_camera.camera.zoom + 1)
                                    .clamp(7, 18)
                                    .toDouble(),
                              );
                            },
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      key: const Key('map-zoom-out'),
                      tooltip: l10n.mapZoomOut,
                      onPressed: !_active
                          ? null
                          : () {
                              _dirty = true;
                              _camera.move(
                                _camera.camera.center,
                                (_camera.camera.zoom - 1)
                                    .clamp(7, 18)
                                    .toDouble(),
                              );
                            },
                      icon: const Icon(Icons.remove),
                    ),
                    if (_dirty && usable)
                      FilledButton(
                        key: const Key('map-search-area'),
                        child: Text(l10n.mapSearchArea),
                        onPressed: () {
                          _preferences.searchedBounds = viewport;
                          _search();
                        },
                      ),
                    if (_preferences.searchedBounds != null)
                      OutlinedButton(
                        key: const Key('map-back-radius'),
                        onPressed: () => _radius(_preferences.radiusKm),
                        child: Text(l10n.mapBackRadius),
                      ),
                    OutlinedButton(
                      key: const Key('map-use-center'),
                      onPressed: !_active
                          ? null
                          : () {
                              _centerEpoch++;
                              _suggestions = const [];
                              _centerError = null;
                              _centerBusy = false;
                              _preferences.latitude =
                                  _preferences.cameraLatitude;
                              _preferences.longitude =
                                  _preferences.cameraLongitude;
                              _preferences.centerLabel =
                                  l10n.mapSelectedReference;
                              _placeInput.text = _preferences.centerLabel;
                              _radius(_preferences.radiusKm, move: false);
                            },
                      child: Text(l10n.mapUseCenter),
                    ),
                  ],
                ),
                Text(
                  l10n.mapSearchReference(_preferences.centerLabel),
                  key: const Key('map-search-reference'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                ExpansionTile(
                  key: const Key('map-options'),
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    l10n.mapOptions,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  children: [
                    DropdownButtonFormField<MapDiscoveryFamily>(
                      key: const Key('map-family'),
                      initialValue: _preferences.family,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.mapFamily),
                      items: [
                        for (final family in MapDiscoveryFamily.values)
                          DropdownMenuItem(
                            value: family,
                            child: Text(switch (family) {
                              MapDiscoveryFamily.all => l10n.mapAll,
                              MapDiscoveryFamily.projects =>
                                l10n.proposalsTitle,
                              MapDiscoveryFamily.tavoli => l10n.tavoliTitle,
                              MapDiscoveryFamily.resources =>
                                l10n.resourceTitle,
                            }, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (family) {
                        if (family != null) {
                          _family(family);
                        }
                      },
                    ),
                    if (filterLabels.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ExpansionTile(
                        title: Text(
                          l10n.mapAppliedFilters(filterLabels.length),
                        ),
                        children: [
                          for (final label in filterLabels) Text(label),
                          TextButton(
                            onPressed: _returnToList,
                            child: Text(l10n.mapEditListFilters),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (canSearchCenter)
                      TextField(
                        key: const Key('map-center-input'),
                        controller: _placeInput,
                        enabled: canSearchCenter,
                        maxLength: 160,
                        maxLines: 1,
                        decoration: InputDecoration(
                          labelText: l10n.mapSearchPlace,
                          counterText: '',
                          suffixIcon: _centerBusy
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        onChanged: _placeChanged,
                      ),
                    if (_centerError != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _centerError == 'expired'
                              ? l10n.mapCenterExpired
                              : l10n.mapCenterFailed,
                        ),
                      ),
                    for (final suggestion in _suggestions)
                      ListTile(
                        key: Key('map-suggestion-${suggestion.id}'),
                        title: Text(suggestion.label),
                        trailing: const Icon(Icons.north_west),
                        onTap: () => _chooseCenter(suggestion),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<double>(
                      key: const Key('map-radius'),
                      initialValue: _preferences.radiusKm,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.mapRadius),
                      items: [
                        for (final km in [
                          1.0,
                          3.0,
                          5.0,
                          10.0,
                          20.0,
                          50.0,
                          100.0,
                        ])
                          DropdownMenuItem(
                            value: km,
                            child: Text('${km.toInt()} km'),
                          ),
                      ],
                      onChanged: (km) {
                        if (km != null) _radius(km);
                      },
                    ),
                  ],
                ),
                if (_dirty && !usable) Text(l10n.mapZoomInRequired),
                if (state.phase == GeoPhase.loading)
                  LinearProgressIndicator(semanticsLabel: l10n.mapLoading),
                if (state.phase == GeoPhase.ready && state.items.isEmpty)
                  Text(l10n.mapEmpty),
                if (state.phase == GeoPhase.failure)
                  Semantics(
                    liveRegion: true,
                    child: Text(switch (state.failure) {
                      GeoFailureKind.tooBroad => l10n.mapTooBroad,
                      GeoFailureKind.malformed => l10n.mapMalformed,
                      GeoFailureKind.expiredCursor => l10n.mapCursorExpired,
                      GeoFailureKind.invalidInput => l10n.mapInvalidArea,
                      _ =>
                        state.items.isNotEmpty
                            ? l10n.mapAdditionalPageFailed
                            : l10n.mapSearchFailed,
                    }),
                  ),
                if (selected != null)
                  Card(
                    key: _cardKey,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selected.coverObjectPath != null)
                            SizedBox(
                              height: 100,
                              child: Center(
                                child: CoverImage(
                                  title: selected.title,
                                  objectPath: selected.coverObjectPath,
                                ),
                              ),
                            ),
                          Text(_kind(selected, l10n)),
                          Text(
                            selected.title,
                            key: const Key('map-selected-title'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(selected.locationLabel),
                          Text(
                            selected.isApproximate
                                ? l10n.mapApproximate
                                : l10n.mapPrecise,
                          ),
                          if (selected.startsAt != null &&
                              selected.eventTimezone != null)
                            Text(
                              formatProposalDateTime(
                                selected.startsAt!,
                                selected.eventTimezone!,
                                l10n.localeName,
                              ),
                            ),
                          FilledButton(
                            key: const Key('map-open-detail'),
                            child: Text(l10n.mapOpenDetail),
                            onPressed: () =>
                                context.push(mapItemDetailPath(selected)),
                          ),
                        ],
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (state.page?.hasMore == true &&
                        state.failure != GeoFailureKind.expiredCursor)
                      FilledButton(
                        key: const Key('map-load-more'),
                        onPressed: state.loadingMore
                            ? null
                            : () => _discovery.loadMore(),
                        child: Text(
                          state.loadingMore
                              ? l10n.mapLoading
                              : state.phase == GeoPhase.failure
                              ? l10n.retryAction
                              : l10n.mapLoadMore,
                        ),
                      ),
                    OutlinedButton(
                      key: const Key('map-refresh'),
                      onPressed: !_active ? null : _search,
                      child: Text(l10n.mapRefresh),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
