import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/map_provider_gateway.dart';
import '../domain/basemap_tile.dart';
export '../domain/basemap_tile.dart';

typedef BasemapTileLoader = Future<Uint8List> Function(
  BasemapTileId id,
  Future<void> cancellation,
);

DateTime Function() _elapsedClock() {
  final elapsed = Stopwatch()..start();
  final origin = DateTime.now().toUtc();
  return () => origin.add(elapsed.elapsed);
}

class _Entry {
  _Entry(this.bytes, this.expires);
  final Uint8List bytes;
  final DateTime expires;
}

class _Job {
  _Job(this.id, this.owner);
  final BasemapTileId id;
  final BasemapTileScope? owner;
  final listeners = <BasemapTileScope, Completer<Uint8List>>{};
  final abort = Completer<void>();
  bool cancelled = false;
}

/// App-owned compressed PUBLIC bytes; decoded images always belong to a view.
/// TTL zero disables retention (not coalescing). One expiry timer, no disk/prefetch.
class SharedBasemapTiles with WidgetsBindingObserver {
  SharedBasemapTiles({
    required this.load,
    required this.allowed,
    this.ttl = Duration.zero,
    this.maxCount = 64,
    this.maxBytes = 4 * 1024 * 1024,
    DateTime Function()? now,
  }) : now = now ?? _elapsedClock() {
    if (ttl.isNegative ||
        ttl > const Duration(minutes: 1) ||
        maxCount < 1 ||
        maxBytes < 1) {
      throw ArgumentError('Invalid basemap memory bounds');
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground =
        lifecycle == null ||
        lifecycle == AppLifecycleState.resumed ||
        lifecycle == AppLifecycleState.inactive;
    WidgetsBinding.instance.addObserver(this);
  }
  final BasemapTileLoader load;
  final bool Function() allowed;
  final Duration ttl;
  final int maxCount, maxBytes;
  final DateTime Function() now;
  final _entries = <BasemapTileId, _Entry>{};
  final _publicPending = <BasemapTileId, _Job>{};
  final _jobs = <_Job>{};
  final _queue = Queue<_Job>();
  final _scopes = <BasemapTileScope>{};
  int _running = 0;
  Timer? _expiryTimer;
  bool _alive = true, _foreground = true, _shutOff = false;
  bool get enabled => _alive && _foreground && !_shutOff && allowed();
  int get count {
    _expire();
    return _entries.length;
  }

  int get byteCount {
    _expire();
    return _entries.values.fold(0, (sum, e) => sum + e.bytes.length);
  }

  BasemapTileScope openScope({bool protected = false}) {
    final scope = BasemapTileScope._(this, protected);
    _scopes.add(scope);
    return scope;
  }

  void _expire() =>
      _entries.removeWhere((_, entry) => !now().isBefore(entry.expires));
  Uint8List? _peek(BasemapTileId id) {
    _expire();
    final value = _entries.remove(id);
    if (value != null) _entries[id] = value;
    return value?.bytes;
  }

  void _remember(BasemapTileId id, Uint8List bytes) {
    if (ttl == Duration.zero || bytes.length > maxBytes) return;
    _entries.remove(id);
    _entries[id] = _Entry(bytes, now().add(ttl));
    while (_entries.length > maxCount || byteCount > maxBytes) {
      _entries.remove(_entries.keys.first);
    }
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    if (!_alive || _entries.isEmpty) return;
    final first = _entries.values
        .map((entry) => entry.expires)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = first.difference(now());
    _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      _expire();
      _scheduleExpiry();
    });
  }

  Future<Uint8List> _request(BasemapTileScope scope, BasemapTileId id) async {
    if (!scope._alive) throw const MapProviderFailure('stale');
    if (!enabled) {
      clear();
      throw const MapProviderFailure('disabled');
    }
    final cached = scope._private[id] ?? _peek(id);
    if (cached != null) return scope._accept(id, cached);
    var job = scope.protected ? scope._pending[id] : _publicPending[id];
    if (job == null) {
      if (_queue.length >= 64) throw const MapProviderFailure('unavailable');
      job = _Job(id, scope.protected ? scope : null);
      if (scope.protected) {
        scope._pending[id] = job;
      } else {
        _publicPending[id] = job;
      }
      _jobs.add(job);
      _queue.add(job);
    }
    final waiter = job.listeners.putIfAbsent(scope, Completer<Uint8List>.new);
    scope._jobs.add(job);
    // No long-lived cancellation-future listeners retain completed tile bytes.
    final result = waiter.future;
    _drain();
    return result;
  }

  void _drain() {
    while (_alive && _running < 6 && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      if (job.cancelled) continue;
      _running++;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_Job job) async {
    Uint8List? bytes;
    try {
      bytes = await load(job.id, job.abort.future);
      if (job.cancelled || !enabled) throw const MapProviderFailure('stale');
      if (!validBasemapTilePng(bytes)) {
        throw const MapProviderFailure('malformed');
      }
      // Take ownership; injected gateways can reuse their fixture buffers.
      final owned = Uint8List.fromList(bytes);
      if (job.owner == null) _remember(job.id, owned);
      for (final listener in job.listeners.entries) {
        try {
          listener.value.complete(
            listener.key._accept(
              job.id,
              owned,
              takeOwnership: job.owner != null,
            ),
          );
        } catch (error, stack) {
          if (job.owner != null) owned.fillRange(0, owned.length, 0);
          listener.value.completeError(error, stack);
        }
      }
    } catch (error, stack) {
      if (error is MapProviderFailure &&
          {
            'disabled',
            'unconfigured',
            'guest_disabled',
          }.contains(error.status)) {
        _shutOff = true;
        clear();
      }
      for (final waiter in job.listeners.values) {
        waiter.completeError(error, stack);
      }
    } finally {
      // Private transport buffers are never retained after completion/revocation.
      if (job.owner != null) bytes?.fillRange(0, bytes.length, 0);
      _forget(job);
      _running--;
      _drain();
    }
  }

  void _forget(_Job job) {
    _jobs.remove(job);
    if (identical(_publicPending[job.id], job)) _publicPending.remove(job.id);
    if (identical(job.owner?._pending[job.id], job)) {
      job.owner?._pending.remove(job.id);
    }
    for (final scope in job.listeners.keys) {
      scope._jobs.remove(job);
    }
    job.listeners.clear();
  }

  void _cancel(_Job job) {
    if (job.cancelled) return;
    job.cancelled = true;
    job.abort.complete();
    _queue.remove(job);
    for (final waiter in job.listeners.values) {
      waiter.completeError(const MapProviderFailure('stale'));
    }
    _forget(job);
  }

  /// Drops bytes and invalidates scopes synchronously, including account ABA.
  void clear() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    for (final scope in _scopes.toList()) {
      scope.dispose();
    }
    for (final job in _jobs.toList()) {
      _cancel(job);
    }
    _entries.clear();
  }

  @override
  void didHaveMemoryPressure() => clear();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // An OS overlay (inactive) is not backgrounding. Public bytes/jobs survive;
    // private scopes still revoke immediately, before another frame can paint.
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (!_foreground) {
      clear();
    } else if (state == AppLifecycleState.inactive) {
      for (final scope in _scopes.where((s) => s.protected).toList()) {
        scope.dispose();
      }
    }
  }

  void dispose() {
    _alive = false;
    clear();
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// Protected-only selection/bytes live here, never in the shared public LRU.
/// Already-public bytes may be copied, but private misses are not promoted.
class BasemapTileScope {
  BasemapTileScope._(this.store, this.protected);
  final SharedBasemapTiles store;
  final bool protected;
  final _private = <BasemapTileId, Uint8List>{};
  final _pending = <BasemapTileId, _Job>{};
  final _jobs = <_Job>{};
  bool _alive = true;
  VoidCallback? onRevoke;
  int get privateByteCount => _private.values.fold(0, (n, b) => n + b.length);
  Future<Uint8List> tile(BasemapTileId id) => store._request(this, id);
  Uint8List _accept(
    BasemapTileId id,
    Uint8List bytes, {
    bool takeOwnership = false,
  }) {
    if (!protected) return bytes;
    if (_private.containsKey(id)) return _private[id]!;
    while (_private.length >= 16 ||
        privateByteCount + bytes.length > store.maxBytes) {
      if (_private.isEmpty) throw const MapProviderFailure('unavailable');
      final old = _private.remove(_private.keys.first)!;
      old.fillRange(0, old.length, 0);
    }
    return _private[id] = takeOwnership ? bytes : Uint8List.fromList(bytes);
  }

  void evict(BasemapTileId id) {
    final bytes = _private.remove(id);
    bytes?.fillRange(0, bytes.length, 0);
    if (!protected) store._entries.remove(id);
  }

  void dispose() {
    if (!_alive) return;
    _alive = false;
    for (final job in _jobs.toList()) {
      job.listeners
          .remove(this)
          ?.completeError(const MapProviderFailure('stale'));
      if (job.listeners.isEmpty) store._cancel(job);
    }
    _jobs.clear();
    for (final bytes in _private.values) {
      bytes.fillRange(0, bytes.length, 0);
    }
    _private.clear();
    _pending.clear();
    store._scopes.remove(this);
    // A cancelled transport may still settle later; it must not retain the view.
    final notify = onRevoke;
    onRevoke = null;
    notify?.call();
  }
}

bool validBasemapTilePng(Uint8List bytes) {
  if (bytes.length < 45 || bytes.length > 262144) return false;
  const header = [137, 80, 78, 71, 13, 10, 26, 10];
  const size = [73, 72, 68, 82, 0, 0, 1, 0, 0, 0, 1, 0];
  const end = [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130];
  for (var i = 0; i < header.length; i++) {
    if (bytes[i] != header[i]) return false;
  }
  for (var i = 0; i < size.length; i++) {
    if (bytes[12 + i] != size[i]) return false;
  }
  for (var i = 0; i < end.length; i++) {
    if (bytes[bytes.length - end.length + i] != end[i]) return false;
  }
  return true;
}

final basemapCacheTtlProvider = Provider<Duration>(
  (ref) => const Duration(
    seconds: int.fromEnvironment('LOCATION_MAP_CACHE_SECONDS'),
  ),
);

final sharedBasemapTilesProvider = Provider<SharedBasemapTiles>((ref) {
  final gateway = ref.watch(mapProviderGatewayProvider);
  // Live retention requires explicit reviewed duration, <= server/license TTL.
  final store = SharedBasemapTiles(
    ttl: ref.watch(basemapCacheTtlProvider),
    allowed: () {
      final session = ref.read(authSessionProvider);
      return gateway.tilesEnabled &&
          (!gateway.requiresAuthentication ||
              (session.phase == AuthSessionPhase.ready &&
                  session.identity != null));
    },
    load: (id, abort) {
      if (id.provider != 'geoapify' ||
          id.style != 'osm-carto' ||
          id.version != 1 ||
          id.dimension != 256 ||
          id.density != 1) {
        throw const MapProviderFailure('invalid_request');
      }
      return gateway.tile(id.z, id.x, id.y, cancellation: abort);
    },
  );
  ref.listen(
    authSessionProvider.select((s) => (s.phase, s.identity?.id)),
    (_, _) => store.clear(),
  );
  ref.onDispose(store.dispose);
  return store;
});
