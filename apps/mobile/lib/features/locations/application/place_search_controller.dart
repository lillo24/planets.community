import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/place_search_gateway.dart';
import '../domain/place_search.dart';

enum PlaceSearchPhase {
  idle,
  disabled,
  waiting,
  searching,
  results,
  resolving,
  selected,
  failure,
}

/// One transient editor session. The owner cancels on actor/scope replacement,
/// entitlement loss and departure. Never share this controller as a public cache.
/// Production editors retain manual fields until an approved adapter is wired.
class PlaceSearchController extends ChangeNotifier {
  PlaceSearchController({
    required PlaceSearchGateway gateway,
    DateTime Function()? clock,
    String Function()? tokenFactory,
  }) : _gateway = gateway,
       _clock = clock ?? DateTime.now,
       _tokenFactory = tokenFactory ?? const Uuid().v4 {
    _phase = gateway.available
        ? PlaceSearchPhase.idle
        : PlaceSearchPhase.disabled;
  }
  final PlaceSearchGateway _gateway;
  final DateTime Function() _clock;
  final String Function() _tokenFactory;
  String get query => _query;
  PlaceSearchPhase get phase => _phase;
  PlaceSearchProblem? get problem => _problem;
  List<PlaceSuggestion> get suggestions => _suggestions;
  ResolvedPlace? get selection => _selection;
  Timer? _debounce, _expiry;
  int _generation = 0;
  bool _disposed = false;
  String? _token;
  String _query = '';
  late PlaceSearchPhase _phase;
  PlaceSearchProblem? _problem;
  List<PlaceSuggestion> _suggestions = const [];
  ResolvedPlace? _selection;

  void edit(String raw, {required String language}) {
    if (_disposed) return;
    final generation = ++_generation;
    _debounce?.cancel();
    _expiry?.cancel();
    _selection = null;
    _suggestions = const [];
    _problem = null;
    _query = raw; // Raw typing is separate from a resolved selection.
    if (!_gateway.available) {
      _phase = PlaceSearchPhase.disabled;
    } else if (raw.trim().length < 2 || raw.trim().length > 160) {
      _phase = PlaceSearchPhase.idle;
    } else {
      _phase = PlaceSearchPhase.waiting;
      _token ??= _tokenFactory();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        unawaited(_search(generation, language));
      });
    }
    notifyListeners();
  }

  Future<void> _search(int generation, String language) async {
    if (!_current(generation)) return;
    _phase = PlaceSearchPhase.searching;
    notifyListeners();
    try {
      final result = await _gateway
          .search(
            PlaceSearchRequest(
              query: _query,
              sessionToken: _token!,
              language: language,
            ),
          )
          .timeout(const Duration(seconds: 5));
      if (!_current(generation)) return;
      final ids = <String>{};
      _suggestions = List.unmodifiable(
        result
            .where(
              (item) =>
                  item.countryCode == 'IT' &&
                  item.expiresAt.isAfter(_clock()) &&
                  ids.add(item.id),
            )
            .take(5),
      );
      _phase =
          PlaceSearchPhase.results; // Empty matches remain a genuine result.
      _scheduleExpiry();
      notifyListeners();
    } on PlaceSearchFailure catch (error) {
      _fail(generation, error.problem);
    } on TimeoutException {
      _fail(generation, PlaceSearchProblem.timeout);
    } catch (_) {
      // Application boundary: explicit safe failure, never log provider content.
      _fail(generation, PlaceSearchProblem.provider);
    }
  }

  Future<void> select(PlaceSuggestion item) async {
    if (_disposed ||
        !_suggestions.contains(item) ||
        !item.expiresAt.isAfter(_clock()) ||
        _token == null ||
        _phase != PlaceSearchPhase.results) {
      return;
    }
    final generation = ++_generation;
    // Suggestions still expire while details are in flight; late details cannot
    // extend a revoked session or leave cached content beyond its deadline.
    _phase = PlaceSearchPhase.resolving;
    notifyListeners();
    try {
      final result = await _gateway
          .resolve(item, _token!)
          .timeout(const Duration(seconds: 5));
      if (!_current(generation)) return;
      if (result.suggestion.id != item.id ||
          result.suggestion.countryCode != 'IT' ||
          result.suggestion.kind != item.kind ||
          !result.suggestion.expiresAt.isAfter(_clock())) {
        throw const PlaceSearchFailure(PlaceSearchProblem.provider);
      }
      _query = result.suggestion.label;
      _selection = result;
      _suggestions = const [];
      _token = null; // A resolve ends this billing session.
      _phase = PlaceSearchPhase.selected;
      _scheduleExpiry();
      notifyListeners();
    } on PlaceSearchFailure catch (error) {
      _fail(generation, error.problem);
    } on TimeoutException {
      _fail(generation, PlaceSearchProblem.timeout);
    } catch (_) {
      _fail(generation, PlaceSearchProblem.provider);
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  void _fail(int generation, PlaceSearchProblem value) {
    if (!_current(generation)) return;
    _expiry?.cancel();
    _selection = null;
    _suggestions = const [];
    _problem = value;
    _phase = PlaceSearchPhase.failure;
    notifyListeners();
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    final deadlines = [
      if (_selection != null) _selection!.suggestion.expiresAt,
      ..._suggestions.map((item) => item.expiresAt),
    ]..sort();
    if (deadlines.isEmpty) return;
    _expiry = Timer(deadlines.first.difference(_clock()), () {
      if (_disposed) return;
      // Erase labels/points too: expiry cannot preserve forbidden cached content.
      _clear(discardQuery: _selection != null);
      _problem = PlaceSearchProblem.expired;
      _phase = PlaceSearchPhase.failure;
      notifyListeners();
    });
  }

  /// Also used for sign-out/account/entitlement changes; late work cannot return.
  void cancel() => _clear(discardQuery: true);

  void _clear({required bool discardQuery}) {
    if (_disposed) return;
    ++_generation;
    _debounce?.cancel();
    _expiry?.cancel();
    _token = null;
    // Uncommitted user-authored text survives derived suggestion expiry.
    // A resolved provider label is temporary content and must be erased.
    if (discardQuery) _query = '';
    _selection = null;
    _suggestions = const [];
    _problem = null;
    _phase = _gateway.available
        ? PlaceSearchPhase.idle
        : PlaceSearchPhase.disabled;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _debounce?.cancel();
    _expiry?.cancel();
    _token = null;
    _query = '';
    _selection = null;
    _suggestions = const [];
    super.dispose();
  }
}
