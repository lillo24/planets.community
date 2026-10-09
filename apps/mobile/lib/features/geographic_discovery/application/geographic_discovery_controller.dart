import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/geographic_discovery_gateway.dart';
import '../domain/geographic_discovery.dart';

enum GeoPhase { idle, loading, ready, failure }

class GeographicDiscoveryState {
  const GeographicDiscoveryState({
    this.phase = GeoPhase.idle,
    this.items = const [],
    this.page,
    this.loadingMore = false,
    this.failure,
  });
  final GeoPhase phase;
  final List<GeoItem> items;
  final GeoPage? page;
  final bool loadingMore;
  final GeoFailureKind? failure;
}

/// MAP05 owns an explicit route/session key and must signal route/lifecycle activity.
class GeographicDiscoveryController extends Notifier<GeographicDiscoveryState> {
  GeographicDiscoveryController(this.contextId);
  final String contextId;
  int _epoch = 0;
  bool _active = false;
  GeoQuery? _query;
  @override
  GeographicDiscoveryState build() {
    _epoch++;
    _active = false;
    _query = null;
    ref.listen(
      authSessionProvider.select((s) => (s.phase, s.identity?.id)),
      (_, _) => cancel(),
    );
    ref.onDispose(() => _epoch++);
    return const GeographicDiscoveryState();
  }

  void setActive(bool active) {
    if (!ref.mounted) return;
    if (_active == active) return;
    _active = active;
    _epoch++;
    state = const GeographicDiscoveryState();
    if (active && _query != null) unawaited(search(_query!));
  }

  void cancel() {
    if (!ref.mounted) return;
    _epoch++;
    _query = null;
    state = const GeographicDiscoveryState();
  }

  Future<void> search(GeoQuery query) async {
    _epoch++;
    _query = query;
    state = const GeographicDiscoveryState();
    if (!_active) return;
    final epoch = _epoch;
    state = const GeographicDiscoveryState(phase: GeoPhase.loading);
    await _read(query, epoch);
  }

  Future<void> loadMore() async {
    if (!_active ||
        _query == null ||
        (state.phase != GeoPhase.ready && state.phase != GeoPhase.failure) ||
        state.failure == GeoFailureKind.expiredCursor ||
        state.loadingMore ||
        state.page?.hasMore != true) {
      return;
    }
    final previous = state;
    state = GeographicDiscoveryState(
      phase: GeoPhase.ready,
      items: previous.items,
      page: previous.page,
      loadingMore: true,
    );
    await _read(_query!, _epoch, previous: previous);
  }

  Future<void> _read(
    GeoQuery query,
    int epoch, {
    GeographicDiscoveryState? previous,
  }) async {
    try {
      final page = await ref
          .read(geographicDiscoveryGatewayProvider)
          .search(query, cursor: previous?.page?.nextCursor);
      if (!_current(epoch)) return;
      final items = [...?(previous?.items), ...page.items];
      if (items.map((e) => e.identity).toSet().length != items.length) {
        throw const GeoFailure(GeoFailureKind.malformed);
      }
      state = GeographicDiscoveryState(
        phase: GeoPhase.ready,
        items: List.unmodifiable(items),
        page: page,
      );
    } catch (error) {
      if (!_current(epoch)) return;
      state = GeographicDiscoveryState(
        phase: GeoPhase.failure,
        // A failed additional page keeps the already confirmed public rows, visibly failed.
        items: previous?.items ?? const [],
        page: previous?.page,
        failure: error is GeoFailure ? error.kind : GeoFailureKind.unavailable,
      );
    }
  }

  bool _current(int epoch) => ref.mounted && _active && epoch == _epoch;
}

final geographicDiscoveryProvider = NotifierProvider.autoDispose
    .family<GeographicDiscoveryController, GeographicDiscoveryState, String>(
      GeographicDiscoveryController.new,
    );
