import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/mock_environment_config.dart';
import '../data/mock_mode_store.dart';
import '../domain/mock_models.dart';
import '../domain/mock_session_access.dart';

enum MockModePhase { restoring, normal, mock, switching, recovery }

/// Root owner; product providers live in replaceable scopes beneath this object.
class MockModeCoordinator extends ChangeNotifier {
  MockModeCoordinator({
    required this.config,
    required this.access,
    required this.store,
    String Function()? requestId,
  }) : _requestId = requestId ?? const Uuid().v4 {
    _controlSubscription = access.controlChanges.listen(_controlChanged);
    _dataSubscription = access.dataInvalidations.listen((_) {
      if (_disposed || !isMock || _leaving || _logout) return;
      _revision++;
      scopeRevision++;
      unawaited(access.suspend().catchError((Object _) {}));
      _failed(const MockFailure(MockFailureKind.invalidSession));
    });
  }
  final MockEnvironmentConfig config;
  final MockSessionAccess access;
  final MockModeStore store;
  final String Function() _requestId;
  late final StreamSubscription<String?> _controlSubscription;
  late final StreamSubscription<void> _dataSubscription;
  MockModeRecord _record = const MockModeRecord();
  MockModePhase phase = MockModePhase.restoring;
  MockFailureKind? failure;
  MockSelection? active;
  MockSelection? get pending => _record.pending;
  int scopeRevision = 0;
  int _revision = 0;
  bool _disposed = false;
  bool _logout = false;
  bool _leaving = false;
  String? _transitionRoot;
  bool selectionRequested = false;
  bool fencing = false;
  bool get isMock => active != null;
  bool get busy =>
      phase == MockModePhase.switching || phase == MockModePhase.restoring;
  bool get showProduct =>
      phase == MockModePhase.normal || phase == MockModePhase.mock;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int revision, String root) =>
      !_disposed && revision == _revision && access.controlId == root;
  Future<void> _save(MockModeRecord next) async {
    try {
      await store.write(next);
      if (next.revision >= _record.revision) _record = next;
    } catch (_) {
      throw const MockFailure(MockFailureKind.storage);
    }
  }

  void _failed(Object error) {
    failure = error is MockFailure ? error.kind : MockFailureKind.unavailable;
    phase = MockModePhase.recovery;
    selectionRequested = false;
    _emit();
  }

  void _controlChanged(String? id) {
    if (_disposed || ((_logout || _leaving) && id == null)) return;
    final expected =
        _transitionRoot ?? _record.pending?.rootId ?? active?.rootId;
    if (expected != null && id != expected) {
      _revision++;
      scopeRevision++;
      selectionRequested = false;
      unawaited(access.suspend().catchError((Object _) {}));
      _failed(const MockFailure(MockFailureKind.controlLoginRequired));
    }
  }

  Future<void> start() async {
    try {
      _record = await store.read(config);
      _revision = _record.revision;
      active = _record.active;
      if (_record.pending != null) {
        await access.suspend();
        _failed(const MockFailure(MockFailureKind.pending));
        return;
      }
      if (active case final selection?) {
        await access.suspend();
        final revision = ++_revision;
        final candidate = await access.prepare(selection, storedOnly: true);
        if (!_current(revision, selection.rootId)) {
          await access.retire(selection);
          return;
        }
        await access.activate(candidate);
        scopeRevision = revision;
        phase = MockModePhase.mock;
      } else {
        phase = MockModePhase.normal;
      }
      _emit();
    } catch (error) {
      _failed(error);
    }
  }

  void requestSelection() {
    if (busy || phase == MockModePhase.recovery) return;
    selectionRequested = true;
    _emit();
  }

  void cancelSelection() {
    if (!busy) {
      selectionRequested = false;
      _emit();
    }
  }

  Future<List<MockPersona>> catalog() async {
    if (!selectionRequested && !isMock) {
      throw const MockFailure(MockFailureKind.denied);
    }
    try {
      return await access.catalog(expectedRoot: active?.rootId);
    } on MockFailure catch (error) {
      if (isMock &&
          (error.kind == MockFailureKind.denied ||
              error.kind == MockFailureKind.controlLoginRequired)) {
        await access.suspend();
        scopeRevision++;
        _failed(error);
      }
      rethrow;
    }
  }

  Future<bool> select(
    MockPersona persona, {
    required Future<bool> Function() prepareDeparture,
  }) async {
    if (busy ||
        phase == MockModePhase.recovery ||
        (!selectionRequested && !isMock)) {
      return false;
    }
    final root = access.controlId;
    if (root == null) {
      failure = MockFailureKind.controlLoginRequired;
      _emit();
      return false;
    }
    final revision = ++_revision;
    _transitionRoot = root;
    phase = MockModePhase.switching;
    fencing = false;
    failure = null;
    _emit();
    try {
      final departed = await prepareDeparture();
      if (!_current(revision, root)) return false;
      if (!departed) {
        await access.resume();
        _transitionRoot = null;
        phase = isMock ? MockModePhase.mock : MockModePhase.normal;
        _emit();
        return false;
      }
      fencing = true;
      _emit();
      await access.suspend();
      final selection = MockSelection(
        rootId: root,
        personaKey: persona.key,
        userId: persona.userId,
        requestId: _requestId(),
        revision: revision,
        origin: config.origin.origin,
      );
      await _save(
        MockModeRecord(active: active, pending: selection, revision: revision),
      );
      return await _complete(selection, revision);
    } catch (error) {
      if (revision == _revision && !_disposed) _failed(error);
      return false;
    }
  }

  Future<bool> _complete(MockSelection selection, int revision) async {
    final candidate = await access.prepare(selection);
    if (!_current(revision, selection.rootId)) {
      await access.retire(selection);
      return false;
    }
    await _save(MockModeRecord(active: selection, revision: revision));
    if (!_current(revision, selection.rootId)) {
      await access.retire(selection);
      return false;
    }
    await access.activate(candidate);
    if (!_current(revision, selection.rootId)) {
      await access.suspend();
      await access.retire(selection);
      return false;
    }
    active = selection;
    _transitionRoot = null;
    scopeRevision = revision;
    phase = MockModePhase.mock;
    selectionRequested = false;
    failure = null;
    _emit();
    return true;
  }

  /// Recovery always retains the original persona AND server request identity.
  Future<bool> retry() async {
    if (busy || phase != MockModePhase.recovery) return false;
    final selection = _record.pending ?? _record.active;
    if (selection == null) {
      phase = MockModePhase.restoring;
      _emit();
      await start();
      return showProduct;
    }
    final revision = ++_revision;
    phase = MockModePhase.switching;
    fencing = true;
    failure = null;
    _emit();
    try {
      if (_record.pending != null) return await _complete(selection, revision);
      final candidate = await access.prepare(selection, storedOnly: true);
      if (!_current(revision, selection.rootId)) {
        await access.retire(selection);
        return false;
      }
      await access.activate(candidate);
      active = selection;
      scopeRevision = revision;
      phase = MockModePhase.mock;
      _emit();
      return true;
    } catch (error) {
      if (revision == _revision && !_disposed) _failed(error);
      return false;
    }
  }

  Future<bool> leave({
    required Future<bool> Function() prepareDeparture,
  }) async {
    if (busy) return false;
    final revision = ++_revision;
    phase = MockModePhase.switching;
    fencing = false;
    _leaving = true;
    failure = null;
    _emit();
    try {
      if (!await prepareDeparture()) {
        await access.resume();
        phase = isMock ? MockModePhase.mock : MockModePhase.normal;
        _emit();
        return false;
      }
      fencing = true;
      _emit();
      await access.suspend();
      if (_record.pending case final pending?) await access.retire(pending);
      await access.returnToNormal();
      if (_disposed || revision != _revision) return false;
      await _save(MockModeRecord(revision: revision));
      active = null;
      _transitionRoot = null;
      scopeRevision = revision;
      phase = MockModePhase.normal;
      selectionRequested = false;
      _emit();
      return true;
    } catch (error) {
      if (revision == _revision && !_disposed) _failed(error);
      return false;
    } finally {
      _leaving = false;
    }
  }

  Future<void> validateOnResume() async {
    if (!isMock || busy || phase != MockModePhase.mock) return;
    final revision = _revision;
    final root = active!.rootId;
    try {
      await access.catalog(expectedRoot: root);
      if (!_current(revision, root) || phase != MockModePhase.mock) return;
      await access.resume();
    } catch (error) {
      if (!_current(revision, root) || phase != MockModePhase.mock) return;
      await access.suspend();
      scopeRevision++;
      _failed(error);
    }
  }

  /// Explicit PLANETS logout may cancel issuance. A late candidate is retired,
  /// and never becomes a hidden login after the normal session was cleared.
  Future<void> fullLogout() async {
    final revision = ++_revision;
    _logout = true;
    phase = MockModePhase.switching;
    fencing = true;
    selectionRequested = false;
    _emit();
    try {
      await access.suspend();
      if (_record.pending case final pending?) await access.retire(pending);
      await access.fullLogout();
      if (_disposed || revision != _revision) return;
      await _save(MockModeRecord(revision: revision));
      active = null;
      _transitionRoot = null;
      scopeRevision = revision;
      phase = MockModePhase.normal;
      failure = null;
      _emit();
    } catch (error) {
      if (revision == _revision && !_disposed) _failed(error);
    } finally {
      _logout = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    unawaited(_controlSubscription.cancel());
    unawaited(_dataSubscription.cancel());
    super.dispose();
  }
}

final mockModeCoordinatorProvider = Provider<MockModeCoordinator?>(
  (ref) => null,
);
final activeMockRealmProvider = Provider<bool>((ref) => false);
final closedTestMockCapabilityProvider = Provider<bool>((ref) => false);
final realmPreferenceNamespaceProvider = Provider<String>((ref) => '');
