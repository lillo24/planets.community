import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/item_location_gateway.dart';
import '../data/server_place_search_gateway.dart';
import '../domain/item_location.dart';
import '../domain/place_search.dart';
import 'place_search_controller.dart';

/// Owns exactly one editor and one slot transaction at a time. All state is
/// volatile. Ordinary form saves run before receipt issuance, never on retry.
class LocationEditorSession extends ChangeNotifier {
  LocationEditorSession({
    required this.actor,
    required this.kind,
    required this.itemId,
    required this.prepare,
    required this.gateway,
    required this.factory,
    required this.onCanonical,
  });
  final String? Function() actor;
  final String kind;
  final String? Function() itemId;
  final Future<String?> Function() prepare;
  final ItemLocationGateway gateway;
  final EditorPlaceGatewayFactory factory;
  final void Function(ItemLocation) onCanonical;
  ItemLocation? canonical;
  PlaceSearchController? search;
  PlaceSearchScope? scope;
  PlaceSearchProblem? problem;
  bool busy = false;
  bool _disposed = false;
  int _epoch = 0;
  String? _requestId, _action, _receipt;
  bool get canRetry => _requestId != null && !busy;
  bool _current(int epoch, String owner) =>
      !_disposed && epoch == _epoch && actor() == owner;

  void cancel({bool eraseCanonical = false, bool notify = true}) {
    ++_epoch;
    search?.dispose();
    search = null;
    scope = null;
    _requestId = null;
    _action = null;
    _receipt = null;
    busy = false;
    problem = null;
    if (eraseCanonical) canonical = null;
    if (!_disposed && notify) notifyListeners();
  }

  void invalidateContent() {
    cancel(eraseCanonical: true, notify: false);
    // Hydration can occur during the parent build. Revoke synchronously and
    // notify after that build, without retaining the preceding receipt.
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> reload() async {
    cancel(eraseCanonical: true);
    final owner = actor(), id = itemId(), epoch = _epoch;
    if (owner == null || id == null) return;
    try {
      final value = await gateway.read(owner, kind, id);
      if (!_current(epoch, owner) || itemId() != id) return;
      canonical = value;
    } on PlaceSearchFailure catch (error) {
      if (!_current(epoch, owner)) return;
      problem = error.problem;
    } catch (_) {
      if (!_current(epoch, owner)) return;
      problem = PlaceSearchProblem.unconfigured;
    }
    if (!_disposed) notifyListeners();
  }

  Future<bool> begin(String slot) async {
    if (busy) return false;
    cancel();
    final owner = actor(), epoch = _epoch;
    if (owner == null) {
      problem = PlaceSearchProblem.unauthorized;
      notifyListeners();
      return false;
    }
    busy = true;
    notifyListeners();
    try {
      final id = await prepare();
      if (!_current(epoch, owner) || id == null) return false;
      final value = await gateway.read(owner, kind, id);
      if (!_current(epoch, owner) || itemId() != id) return false;
      canonical = value;
      scope = PlaceSearchScope(
        actorId: owner,
        itemKind: kind,
        itemId: id,
        revision: value.revision,
        slot: slot,
      );
      search = PlaceSearchController(gateway: factory.create(scope!));
      search!.addListener(() {
        if (search?.problem == PlaceSearchProblem.expired) {
          ++_epoch;
          scope = null;
          canonical = null;
          busy = false;
          _requestId = null;
          _action = null;
          _receipt = null;
          problem = PlaceSearchProblem.expired;
          notifyListeners();
        }
      });
      return true;
    } on PlaceSearchFailure catch (error) {
      if (_current(epoch, owner)) {
        problem = error.problem;
        canonical = null;
      }
      return false;
    } catch (_) {
      if (_current(epoch, owner)) {
        problem = PlaceSearchProblem.provider;
        canonical = null;
      }
      return false;
    } finally {
      if (_current(epoch, owner)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> confirm() async {
    final selected = search?.selection;
    if (selected == null ||
        selected.selectionReceipt == null ||
        scope == null ||
        busy) {
      return false;
    }
    if (!selected.suggestion.expiresAt.isAfter(DateTime.now())) {
      cancel();
      problem = PlaceSearchProblem.expired;
      notifyListeners();
      return false;
    }
    final valid = scope!.slot == 'area'
        ? selected.suggestion.kind == PlaceKind.locality
        : scope!.slot == 'exact'
        ? selected.suggestion.kind != PlaceKind.locality
        : true;
    if (!valid) {
      problem = PlaceSearchProblem.unsupported;
      notifyListeners();
      return false;
    }
    _requestId = const Uuid().v4();
    _action = 'replace';
    _receipt = selected.selectionReceipt;
    return retry();
  }

  Future<bool> clear(String slot) async {
    if (!await begin(slot)) return false;
    _requestId = const Uuid().v4();
    _action = 'clear';
    _receipt = null;
    return retry();
  }

  Future<bool> retry() async {
    final bound = scope, request = _requestId, action = _action, epoch = _epoch;
    if (bound == null || request == null || action == null || busy) {
      return false;
    }
    if (!_current(epoch, bound.actorId) || itemId() != bound.itemId) {
      cancel(eraseCanonical: true);
      return false;
    }
    busy = true;
    problem = null;
    notifyListeners();
    try {
      final appliedRevision = await gateway.apply(
        bound,
        requestId: request,
        action: action,
        receipt: _receipt,
      );
      if (!_current(epoch, bound.actorId)) return false;
      final value = await gateway.read(bound.actorId, kind, bound.itemId);
      if (!_current(epoch, bound.actorId) || itemId() != bound.itemId) {
        return false;
      }
      if (value.revision != appliedRevision) {
        throw const PlaceSearchFailure(PlaceSearchProblem.stale);
      }
      // A successful write alone cannot be displayed as durable success.
      canonical = value;
      _requestId = null;
      _action = null;
      _receipt = null;
      search?.dispose();
      search = null;
      scope = null;
      onCanonical(value);
      return true;
    } on PlaceSearchFailure catch (error) {
      if (!_current(epoch, bound.actorId)) return false;
      problem = error.problem;
      canonical = null;
      if (error.problem != PlaceSearchProblem.offline &&
          error.problem != PlaceSearchProblem.timeout) {
        _requestId = null;
        _action = null;
        _receipt = null;
        search?.cancel();
      }
      return false;
    } catch (_) {
      if (_current(epoch, bound.actorId)) {
        problem = PlaceSearchProblem.provider;
        canonical = null;
        _requestId = null;
        _action = null;
        _receipt = null;
        search?.cancel();
      }
      return false;
    } finally {
      if (_current(epoch, bound.actorId)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancel(eraseCanonical: true);
    super.dispose();
  }
}
