import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../geographic_discovery/application/budget_basemap_tiles.dart';
import '../../geographic_discovery/application/shared_basemap_tiles.dart';
import '../../geographic_discovery/data/budget_basemap_gateway.dart';
import '../../geographic_discovery/data/map_provider_gateway.dart';
import '../../geographic_discovery/domain/geographic_discovery.dart';
import '../../geographic_discovery/domain/map_discovery.dart';
import '../../geographic_discovery/domain/public_map_clustering.dart';
import '../../geographic_discovery/presentation/budget_tile_provider.dart';
import '../../geographic_discovery/presentation/map_view_button.dart';
import '../../geographic_discovery/presentation/public_map_entry_chooser.dart';
import '../../geographic_discovery/presentation/public_point_map.dart';
import '../../locations/presentation/location_attribution.dart';
import '../../mock_mode/application/mock_mode_coordinator.dart';
import '../../settings/application/activities_split_preference_controller.dart';
import '../application/external_activities_controller.dart';
import '../application/external_map_session.dart';
import '../domain/external_activity.dart';
import 'external_activity_filters.dart';
import 'external_activity_widgets.dart';

/// Composes the shared public renderer/cache/chooser with external typed data.
/// There is one filter authority; the map has only its own paginated result set.
class ExternalActivitiesMapScreen extends ConsumerStatefulWidget {
  const ExternalActivitiesMapScreen({super.key});
  @override
  ConsumerState<ExternalActivitiesMapScreen> createState() =>
      _ExternalMapState();
}

class _ExternalMapState extends ConsumerState<ExternalActivitiesMapScreen>
    with WidgetsBindingObserver {
  final _camera = MapController();
  final _cardKey = GlobalKey();
  GoRouter? _router;
  TileProvider? _tiles;
  GeoBounds? _viewport;
  bool _active = false, _foreground = true, _dirty = false;
  bool _tileFailed = false, _reduced = false, _partialTiles = false;
  int _viewEpoch = 0;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

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
      if (!mounted) return;
      final phase = ref.read(authSessionProvider).phase;
      _setActive(
        _foreground &&
            ref.read(activitiesSplitPreferenceProvider).enabled &&
            TickerMode.valuesOf(context).enabled &&
            {
              AuthSessionPhase.signedOut,
              AuthSessionPhase.ready,
              AuthSessionPhase.profileSetupRequired,
            }.contains(phase) &&
            _router?.routerDelegate.state.uri.path == '/activities/map',
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _setActive(bool value) {
    if (_active == value) return;
    _active = value;
    _viewEpoch++;
    _tiles?.dispose();
    _tiles = null;
    final previous = ref.read(externalActivitiesMapControllerProvider);
    final controller = ref.read(
      externalActivitiesMapControllerProvider.notifier,
    );
    controller.setActive(value);
    if (value) {
      if (previous.page != null || previous.failed) {
        unawaited(controller.refresh());
      }
      _tileFailed = false;
      _reduced = false;
      _partialTiles = false;
      _syncTiles();
    }
    setState(() {});
  }

  void _syncTiles() {
    final gateway = ref.read(mapProviderGatewayProvider);
    if (!_active ||
        !gateway.tilesEnabled ||
        _tileFailed ||
        (gateway.requiresAuthentication &&
            ref.read(authSessionProvider).identity == null)) {
      return;
    }
    final camera = ref.read(externalMapSessionProvider).camera;
    if (_tiles == null && ref.read(budgetBasemapEnabledProvider)) {
      _tiles = BudgetTileProvider(
        ref.read(budgetBasemapTilesProvider),
        warmTrento:
            !ref.read(activeMockRealmProvider) &&
            camera.cameraLatitude == 46.0748 &&
            camera.cameraLongitude == 11.1217,
        onReduced: () => _basemapStatus(reduced: true),
        onRevoked: () => _basemapStatus(revoked: true),
      );
    }
    _tiles ??= GatewayTileProvider(ref.read(sharedBasemapTilesProvider));
  }

  void _basemapStatus({bool reduced = false, bool revoked = false}) {
    final epoch = _viewEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_active || epoch != _viewEpoch) return;
      setState(() {
        _reduced = _reduced || reduced;
        if (revoked) {
          _tiles?.dispose();
          _tiles = null;
          _tileFailed = true;
        } else if (!reduced) {
          _partialTiles = true;
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _setActive(false);
    } else {
      _queueActivity();
    }
  }

  void _area(GeoArea? area) {
    if (!_active) return;
    if (area != null) {
      try {
        area.toJson();
      } on FormatException {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).activitiesMapInvalidArea,
            ),
          ),
        );
        return;
      }
    }
    setState(() => _dirty = false);
    final filter = ref.read(externalActivitiesControllerProvider).filter;
    unawaited(
      ref
          .read(externalActivitiesControllerProvider.notifier)
          .filter(filter.withArea(area)),
    );
  }

  void _select(ExternalActivity item) {
    setState(
      () => ref.read(externalMapSessionProvider).selectedIdentity =
          item.mapIdentity,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _cardKey.currentContext;
      if (context != null) {
        unawaited(
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 250),
          ),
        );
      }
    });
  }

  Future<void> _cluster(List<ExternalActivity> items) async {
    if (!_active) return;
    if (items.length == 1) {
      _select(items.single);
      return;
    }
    final l = AppLocalizations.of(context);
    final epoch = _viewEpoch;
    final selected = await showModalBottomSheet<ExternalActivity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PublicMapEntryChooser(
        count: items.length,
        heading: l.mapClusterLoaded(items.length),
        footer: _tiles == null ? null : const LocationAttribution(),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            key: Key('map-cluster-item-${item.mapIdentity}'),
            title: Text(item.title),
            subtitle: Text(
              '${externalKindLabel(item.kind, l)}${item.geometry!.precision == 'locality' ? ' · ${l.activitiesMapApproximate}' : ''}',
            ),
            leading: Icon(_icon(item)),
            onTap: () => Navigator.of(context).pop(item),
          );
        },
      ),
    );
    if (!mounted || !_active || epoch != _viewEpoch || selected == null) return;
    if (ref
            .read(externalActivitiesMapControllerProvider)
            .page
            ?.items
            .any((i) => i.id == selected.id) ==
        true) {
      _select(selected);
    }
  }

  IconData _icon(ExternalActivity item) => switch (item.kind) {
    ExternalActivityKind.event => Icons.event_outlined,
    ExternalActivityKind.course => Icons.fitness_center,
    ExternalActivityKind.place => Icons.sports,
  };

  @override
  void dispose() {
    _viewEpoch++;
    _router?.routerDelegate.removeListener(_queueActivity);
    WidgetsBinding.instance.removeObserver(this);
    _tiles?.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(activitiesSplitPreferenceProvider).enabled;
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      _,
      _,
    ) {
      _viewEpoch++;
      _tiles?.dispose();
      _tiles = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _setActive(false);
        _viewport = null;
        _dirty = false;
        _queueActivity();
      });
    });
    ref.listen(activitiesSplitPreferenceProvider.select((s) => s.enabled), (
      _,
      enabled,
    ) {
      if (!enabled) {
        _viewEpoch++;
        _tiles?.dispose();
        _tiles = null;
      }
      _queueActivity();
    });
    if (!enabled) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final state = ref.watch(externalActivitiesMapControllerProvider);
    final filter = ref.watch(externalActivitiesControllerProvider).filter;
    final session = ref.watch(externalMapSessionProvider);
    final view = session.camera;
    final area = filter.area;
    view.searchedBounds = area is GeoBounds ? area : null;
    if (area is GeoRadius) {
      view.latitude = area.latitude;
      view.longitude = area.longitude;
      view.radiusKm = area.radiusMeters / 1000;
    }
    final items = state.page?.items ?? <ExternalActivity>[];
    final clusters = clusterPublicCoordinates(
      items.where((i) => i.geometry != null).toList(),
      view.zoom,
      identity: (i) => i.mapIdentity,
      latitude: (i) => i.geometry!.latitude,
      longitude: (i) => i.geometry!.longitude,
    );
    final selected = items
        .where((i) => i.mapIdentity == session.selectedIdentity)
        .firstOrNull;
    final health = externalHealthMessage(state.page?.health, l);
    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(l.activitiesMapTitle),
        actions: [
          IconButton(
            key: const Key('external-map-refresh'),
            tooltip: l.activitiesMapRefresh,
            onPressed: !_active || state.loading
                ? null
                : () => ref
                      .read(externalActivitiesMapControllerProvider.notifier)
                      .refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const PageStorageKey('external-map-scroll'),
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MapViewButton.external(mapSelected: true),
              TextButton.icon(
                key: const Key('external-map-edit-filters'),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/activities'),
                icon: const Icon(Icons.tune),
                label: Text(l.activitiesMapEditFilters),
              ),
              Text(
                [
                  if (filter.category != null)
                    filter.category == 'sports'
                        ? l.activitiesSports
                        : l.activitiesCulture,
                  externalKindLabel(filter.kind, l),
                  if (filter.discipline != null)
                    externalDisciplineLabel(filter.discipline!, l),
                  if (filter.query.isNotEmpty) filter.query,
                  if (filter.from != null) '${filter.from} – ${filter.to}',
                ].join(' · '),
              ),
              const SizedBox(height: AppSpacing.small),
              SizedBox(
                height: 340,
                key: const Key('external-map-viewport'),
                child: _active
                    ? PublicMapCanvas(
                        controller: _camera,
                        preferences: view,
                        tileProvider: _tiles,
                        showRadius: area is GeoRadius,
                        onTileError: () => _basemapStatus(revoked: true),
                        onCamera: (bounds, latitude, longitude, zoom, gesture) {
                          if (!_active) return;
                          _viewport = bounds;
                          view.cameraLatitude = latitude;
                          view.cameraLongitude = longitude;
                          view.zoom = zoom;
                          _dirty = _dirty || gesture;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _active) setState(() {});
                          });
                        },
                        markers: [
                          for (final cluster in clusters)
                            PublicMapMarker(
                              identity: cluster.first.mapIdentity,
                              latitude: cluster.first.geometry!.latitude,
                              longitude: cluster.first.geometry!.longitude,
                              count: cluster.length,
                              label: cluster.length > 1
                                  ? l.mapClusterLoaded(cluster.length)
                                  : '${externalKindLabel(cluster.first.kind, l)} · ${cluster.first.title}',
                              icon: _icon(cluster.first),
                              approximate:
                                  cluster.first.geometry!.precision ==
                                  'locality',
                              onTap: () => _cluster(cluster),
                            ),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
              if (_tiles == null || _reduced || _partialTiles)
                Text(
                  _tileFailed || _partialTiles
                      ? l.mapBasemapFailed
                      : _reduced
                      ? l.mapReducedDetail
                      : l.mapBasemapDisabled,
                ),
              if (_tiles != null) const LocationAttribution(),
              Text(l.activitiesMapLoaded(items.length)),
              Text(l.activitiesMapMissingPoints),
              Text(
                area == null
                    ? l.activitiesMapAllLocations
                    : area is GeoBounds
                    ? l.activitiesMapSelectedArea
                    : l.activitiesMapReference(
                        '${view.latitude.toStringAsFixed(4)}, ${view.longitude.toStringAsFixed(4)}',
                        '${view.radiusKm}',
                      ),
              ),
              Wrap(
                spacing: AppSpacing.small,
                children: [
                  FilledButton.icon(
                    key: const Key('external-map-search-area'),
                    onPressed:
                        _active &&
                            _dirty &&
                            _viewport != null &&
                            isUsableMapViewport(_viewport!)
                        ? () => _area(_viewport)
                        : null,
                    icon: const Icon(Icons.search),
                    label: Text(l.activitiesMapSearchArea),
                  ),
                  OutlinedButton(
                    key: const Key('external-map-radius'),
                    onPressed: !_active
                        ? null
                        : () => _area(
                            GeoRadius(
                              view.cameraLatitude,
                              view.cameraLongitude,
                              view.radiusKm * 1000,
                            ),
                          ),
                    child: Text(l.activitiesMapUseCentre),
                  ),
                  DropdownButton<double>(
                    key: const Key('external-map-radius-size'),
                    value: view.radiusKm,
                    items: [
                      for (final km in ({
                        1.0,
                        5.0,
                        10.0,
                        25.0,
                        50.0,
                        view.radiusKm,
                      }.toList()..sort()))
                        DropdownMenuItem(value: km, child: Text('$km km')),
                    ],
                    onChanged: !_active
                        ? null
                        : (km) {
                            if (km == null) return;
                            setState(() => view.radiusKm = km);
                            if (area is GeoRadius) {
                              _area(
                                GeoRadius(
                                  area.latitude,
                                  area.longitude,
                                  km * 1000,
                                ),
                              );
                            }
                          },
                  ),
                  if (area != null)
                    TextButton(
                      key: const Key('external-map-clear-area'),
                      onPressed: () => _area(null),
                      child: Text(l.activitiesMapClearArea),
                    ),
                ],
              ),
              if (_dirty &&
                  _viewport != null &&
                  !isUsableMapViewport(_viewport!))
                Text(l.activitiesMapInvalidArea),
              if (state.loading)
                const LinearProgressIndicator(key: Key('external-map-loading')),
              if (state.failed) ...[
                Text(
                  state.areaTooBroad
                      ? l.activitiesMapInvalidArea
                      : l.activitiesExternalReadFailed,
                ),
                TextButton(
                  onPressed: () => ref
                      .read(externalActivitiesMapControllerProvider.notifier)
                      .refresh(),
                  child: Text(l.retryAction),
                ),
              ],
              if (health != null) Text(health),
              if (!state.loading &&
                  !state.failed &&
                  state.page != null &&
                  items.isEmpty &&
                  {
                    ExternalCatalogueHealth.healthy,
                    ExternalCatalogueHealth.empty,
                  }.contains(state.page!.health))
                Text(l.activitiesMapEmpty),
              if (selected != null)
                Container(
                  key: _cardKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        selected.geometry!.precision == 'locality'
                            ? l.activitiesMapApproximate
                            : l.activitiesMapVenue,
                      ),
                      if (selected.distanceMeters != null)
                        Text(
                          l.activitiesMapDistance(
                            (selected.distanceMeters! / 1000).toStringAsFixed(
                              1,
                            ),
                          ),
                        ),
                      ExternalActivityCard(
                        item: selected,
                        key: const Key('external-map-selected'),
                        // ACTMET01 deliberately excludes map surfaces.
                        onTap: () =>
                            context.push('/activities/external/${selected.id}'),
                      ),
                    ],
                  ),
                ),
              if (state.page?.nextCursor != null)
                TextButton(
                  key: const Key('external-map-load-more'),
                  onPressed: state.loading
                      ? null
                      : () => ref
                            .read(
                              externalActivitiesMapControllerProvider.notifier,
                            )
                            .loadMore(),
                  child: Text(
                    state.moreFailed
                        ? l.retryAction
                        : l.activitiesExternalLoadMore,
                  ),
                ),
              if (state.moreFailed) Text(l.activitiesExternalReadFailed),
            ],
          ),
        ),
      ),
    );
  }
}
