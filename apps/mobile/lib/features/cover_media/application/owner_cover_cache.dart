import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';

// Session memory only. Visible consumers fetch on demand; no history preload.
// The decoded Flutter image keys are evicted with their private source bytes.
class OwnerCoverCache with WidgetsBindingObserver {
  OwnerCoverCache(this.actor, this._invalidate) {
    WidgetsBinding.instance.addObserver(this);
  }

  static const maxEntries = 32;
  static const maxBytes = 8 * 1024 * 1024;
  final String? actor;
  final VoidCallback _invalidate;
  final _entries = <String, Uint8List>{};
  int byteCount = 0;
  int generation = 0;
  bool disposed = false;
  bool backgrounded = false;
  bool authorizationLost = false;

  void deny() {
    if (authorizationLost) return;
    authorizationLost = true;
    clear();
    _invalidate();
  }

  int get entryCount => _entries.length;

  Uint8List? get(String path) {
    final bytes = _entries.remove(path);
    if (bytes != null) _entries[path] = bytes;
    return bytes;
  }

  void put(String path, Uint8List bytes) {
    if (disposed ||
        backgrounded ||
        authorizationLost ||
        bytes.length > maxBytes) {
      return;
    }
    final old = _entries.remove(path);
    if (old != null) byteCount -= old.length;
    _entries[path] = bytes;
    byteCount += bytes.length;
    while (_entries.length > maxEntries || byteCount > maxBytes) {
      final evicted = _entries.remove(_entries.keys.first)!;
      byteCount -= evicted.length;
      MemoryImage(evicted).evict();
    }
  }

  void clear() {
    generation++;
    for (final bytes in _entries.values) {
      MemoryImage(bytes).evict();
    }
    _entries.clear();
    byteCount = 0;
  }

  @override
  void didHaveMemoryPressure() {
    clear();
    _invalidate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!backgrounded) return;
      backgrounded = false;
      _invalidate();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      backgrounded = true;
      clear();
      _invalidate();
    }
  }

  void dispose() {
    disposed = true;
    clear();
    WidgetsBinding.instance.removeObserver(this);
  }
}

final ownerCoverCacheProvider = Provider<OwnerCoverCache>((ref) {
  final session = ref.watch(
    authSessionProvider.select((value) => (value.phase, value.identity?.id)),
  );
  final cache = OwnerCoverCache(
    session.$1 == AuthSessionPhase.ready ? session.$2 : null,
    () {
      if (ref.mounted) ref.invalidate(ownerCoverCacheEpochProvider);
    },
  );
  ref.onDispose(cache.dispose);
  return cache;
});

// A lifecycle event also discards the bytes held by visible FutureProviders.
final ownerCoverCacheEpochProvider = Provider<Object>((ref) => Object());
