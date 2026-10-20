import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/budget_basemap_gateway.dart';
import '../data/map_provider_gateway.dart';
import '../domain/basemap_fallback.dart';
import '../domain/basemap_tile.dart';

class _FrameEntry {
  _FrameEntry(this.frame, this.deadline);
  final BudgetBasemapFrame frame;
  final Duration deadline;
}

class _FrameJob {
  _FrameJob(this.id);
  final BasemapTileId id;
  final listeners = <BudgetBasemapScope, Completer<BudgetBasemapFrame>>{};
  final abort = Completer<void>();
  bool cancelled = false;
}

/// Public-only v2 memory. Never used by protected-detail selection or buffers.
/// 64 sources / 4 MiB compressed, six active / 64 queued, no disk or background IO.
class BudgetBasemapTiles with WidgetsBindingObserver {
  BudgetBasemapTiles({
    required this.gateway,
    required this.allowed,
    Duration Function()? elapsed,
  }) : elapsed = elapsed ?? (Stopwatch()..start()).elapsedGetter {
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground =
        state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }
  final BudgetBasemapGateway gateway;
  final bool Function() allowed;
  final Duration Function() elapsed;
  final _entries = <BasemapTileId, _FrameEntry>{};
  final _coverage = <BasemapTileId, BasemapTileId>{};
  final _failures = <BasemapTileId, (MapProviderFailure, Duration)>{};
  final _jobs = <BasemapTileId, _FrameJob>{};
  final _queue = Queue<_FrameJob>();
  final _scopes = <BudgetBasemapScope>{};
  Duration? _budgetUntil, _blockedUntil;
  MapProviderFailure? _blockedFailure;
  Timer? _expiryTimer;
  bool _alive = true, _foreground = true, _shutOff = false;
  int _running = 0;
  bool get enabled => _alive && _foreground && !_shutOff && allowed();
  bool get cacheOnly {
    if (_budgetUntil != null && elapsed() >= _budgetUntil!) {
      _budgetUntil = null;
      _failures.removeWhere(
        (_, e) => {'budget_exhausted', 'cache_miss'}.contains(e.$1.status),
      );
    }
    return _budgetUntil != null;
  }

  int get count {
    _expire();
    return _entries.length;
  }

  int get byteCount {
    _expire();
    return _entries.values.fold(0, (n, e) => n + e.frame.bytes.length);
  }

  BudgetBasemapScope openScope() {
    final scope = BudgetBasemapScope._(this);
    _scopes.add(scope);
    return scope;
  }

  void _expire() {
    _entries.removeWhere((_, e) => elapsed() >= e.deadline);
    _coverage.removeWhere((_, source) => !_entries.containsKey(source));
  }

  BudgetBasemapFrame? _cached(BasemapTileId id) {
    _expire();
    final source = _entries.containsKey(id) ? id : _coverage[id];
    final entry = _entries.remove(source);
    if (entry != null) _entries[source!] = entry;
    return entry?.frame;
  }

  void _remember(BudgetBasemapFrame frame, BasemapTileId requested) {
    final retention = frame.validFor < const Duration(seconds: 60)
        ? frame.validFor
        : const Duration(seconds: 60);
    if (retention <= Duration.zero) return;
    // Never reinsert on a read: server acquisition/expiry and the original local
    // receipt deadline are retained. Different children share one source buffer.
    final previous = _entries[frame.source];
    if (previous == null || previous.frame.expiresAt != frame.expiresAt) {
      _entries[frame.source] = _FrameEntry(frame, elapsed() + retention);
    }
    _coverage.remove(requested);
    _coverage[requested] = frame.source;
    while (_coverage.length > 64) {
      _coverage.remove(_coverage.keys.first);
    }
    while (_entries.length > 64 || byteCount > 4 * 1024 * 1024) {
      final ordinary = _entries.keys
          .where((id) => !trentoBaselineTiles.contains(id))
          .firstOrNull;
      _entries.remove(ordinary ?? _entries.keys.first);
    }
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    if (!_alive || _entries.isEmpty) return;
    final first = _entries.values
        .map((e) => e.deadline)
        .reduce((a, b) => a < b ? a : b);
    final delay = first - elapsed();
    _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      _expire();
      _scheduleExpiry();
    });
  }

  Future<BudgetBasemapFrame> _request(
    BudgetBasemapScope scope,
    BasemapTileId id,
  ) async {
    if (!scope._alive) throw const BudgetBasemapFailure('stale');
    if (!enabled) {
      clear();
      throw const BudgetBasemapFailure('disabled');
    }
    final only = cacheOnly;
    if (_blockedUntil != null && elapsed() < _blockedUntil!) {
      throw _blockedFailure!;
    }
    final cached = _cached(id);
    // A covering source is usable only after this exact request was resolved by
    // the server. Unknown children still get the server's exact-cache-first check.
    if (cached != null && (cached.source == id || only)) return cached;
    final failure = _failures[id];
    if (failure != null && elapsed() < failure.$2) throw failure.$1;
    var job = _jobs[id];
    if (job == null) {
      if (_queue.length >= 64) throw const BudgetBasemapFailure('unavailable');
      job = _FrameJob(id);
      _jobs[id] = job;
      _queue.add(job);
    }
    final waiter = job.listeners.putIfAbsent(
      scope,
      Completer<BudgetBasemapFrame>.new,
    );
    _drain();
    return waiter.future;
  }

  void _drain() {
    while (_alive && _running < 6 && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      if (job.cancelled) continue;
      _running++;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_FrameJob job) async {
    try {
      if (!enabled) throw const BudgetBasemapFailure('disabled');
      if (_blockedUntil != null && elapsed() < _blockedUntil!) {
        throw _blockedFailure!;
      }
      final frame = await gateway.tile(
        job.id,
        cacheOnly: cacheOnly,
        cancellation: job.abort.future,
      );
      if (job.cancelled || !enabled) throw const BudgetBasemapFailure('stale');
      if (!tileCovers(frame.source, job.id) ||
          (frame.source != job.id &&
              frame.source != trentoBaselineAncestor(job.id)) ||
          !validBasemapTilePng(frame.bytes) ||
          frame.validFor <= Duration.zero ||
          frame.validFor > const Duration(days: 7)) {
        throw const BudgetBasemapFailure('malformed');
      }
      if (frame.budgetExhausted) _setBudget(frame.retryAfter);
      _remember(frame, job.id);
      for (final waiter in job.listeners.values) {
        waiter.complete(frame);
      }
    } catch (error, stack) {
      if (job.cancelled) return;
      final reported =
          error is BudgetBasemapFailure &&
              error.status == 'budget_exhausted' &&
              (error.retryAfter <= Duration.zero ||
                  error.retryAfter > const Duration(days: 1))
          ? const BudgetBasemapFailure('malformed')
          : error;
      if (reported is MapProviderFailure) {
        final retry = reported is BudgetBasemapFailure
            ? reported.retryAfter
            : Duration.zero;
        if (reported.status == 'budget_exhausted') _setBudget(retry);
        if ({
          'disabled',
          'unconfigured',
          'guest_disabled',
          'unauthorized',
        }.contains(reported.status)) {
          _shutOff = true;
          clear();
        } else {
          final delay = retry > Duration.zero
              ? retry
              : const Duration(seconds: 15);
          _failures.remove(job.id);
          _failures[job.id] = (reported, elapsed() + delay);
          while (_failures.length > 64) {
            _failures.remove(_failures.keys.first);
          }
          if ({
            'rate_limited',
            'unavailable',
            'provider_failure',
            'timeout',
            'invalid_image',
            'malformed',
          }.contains(reported.status)) {
            _blockedUntil = elapsed() + delay;
            _blockedFailure = reported;
          }
        }
      }
      for (final waiter in job.listeners.values) {
        waiter.completeError(reported, stack);
      }
    } finally {
      if (identical(_jobs[job.id], job)) _jobs.remove(job.id);
      job.listeners.clear();
      _running--;
      _drain();
    }
  }

  void _setBudget(Duration retry) {
    // A malformed reset contract is an error, never a device-clock fallback.
    if (retry <= Duration.zero || retry > const Duration(days: 1)) {
      throw const BudgetBasemapFailure('malformed');
    }
    _budgetUntil = elapsed() + retry;
  }

  void _cancel(_FrameJob job) {
    if (job.cancelled) return;
    job.cancelled = true;
    job.abort.complete();
    _queue.remove(job);
    if (identical(_jobs[job.id], job)) _jobs.remove(job.id);
    for (final waiter in job.listeners.values) {
      waiter.completeError(const BudgetBasemapFailure('stale'));
    }
    job.listeners.clear();
  }

  void clear() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    for (final scope in _scopes.toList()) {
      scope.dispose();
    }
    for (final job in _jobs.values.toList()) {
      _cancel(job);
    }
    _entries.clear();
    _coverage.clear();
    _failures.clear();
    _budgetUntil = null;
    _blockedUntil = null;
    _blockedFailure = null;
  }

  @override
  void didHaveMemoryPressure() => clear();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (!_foreground) clear();
  }

  void dispose() {
    _alive = false;
    clear();
    WidgetsBinding.instance.removeObserver(this);
  }
}

extension on Stopwatch {
  Duration elapsedGetter() => elapsed;
}

class BudgetBasemapScope {
  BudgetBasemapScope._(this.store);
  final BudgetBasemapTiles store;
  bool _alive = true;
  VoidCallback? onRevoke;
  Future<BudgetBasemapFrame> tile(BasemapTileId id) => store._request(this, id);
  void evict(BasemapTileId id) {
    final source = store._coverage.remove(id) ?? id;
    store._entries.remove(source);
    store._coverage.removeWhere((_, value) => value == source);
  }

  Future<void> primeTrento() async {
    // Exactly twelve foreground requests; every cold miss uses the same ledger.
    // Missing neighbors do not conceal failure of a visible requested tile.
    await Future.wait(
      trentoBaselineTiles.map((id) async {
        try {
          await tile(id);
        } on MapProviderFailure {
          /* Individual demand reports its explicit failure. */
        }
      }),
    );
  }

  void dispose() {
    if (!_alive) return;
    _alive = false;
    for (final job in store._jobs.values.toList()) {
      job.listeners
          .remove(this)
          ?.completeError(const BudgetBasemapFailure('stale'));
      if (job.listeners.isEmpty) store._cancel(job);
    }
    store._scopes.remove(this);
    final notify = onRevoke;
    onRevoke = null;
    notify?.call();
  }
}

final budgetBasemapTilesProvider = Provider<BudgetBasemapTiles>((ref) {
  final gateway = ref.watch(budgetBasemapGatewayProvider);
  final tiles = ref.watch(mapProviderGatewayProvider);
  final store = BudgetBasemapTiles(
    gateway: gateway,
    allowed: () {
      final session = ref.read(authSessionProvider);
      return tiles.tilesEnabled &&
          (!tiles.requiresAuthentication ||
              session.phase == AuthSessionPhase.ready &&
                  session.identity != null);
    },
  );
  ref.listen(
    authSessionProvider.select((s) => (s.phase, s.identity?.id)),
    (_, _) => store.clear(),
  );
  ref.onDispose(store.dispose);
  return store;
});
