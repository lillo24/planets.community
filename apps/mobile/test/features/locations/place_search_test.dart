import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/locations/application/place_search_controller.dart';
import 'package:planets_mobile/features/locations/data/place_search_gateway.dart';
import 'package:planets_mobile/features/locations/domain/place_search.dart';

final _now = DateTime.utc(2026, 10, 7);
PlaceSuggestion _item(
  String id, {
  PlaceKind kind = PlaceKind.locality,
  String country = 'IT',
  DateTime? expiry,
}) => PlaceSuggestion(
  id: id,
  label: 'Synthetic $id',
  countryCode: country,
  kind: kind,
  expiresAt: expiry ?? _now.add(const Duration(minutes: 1)),
);
ResolvedPlace _resolved(PlaceSuggestion item) => ResolvedPlace(
  suggestion: item,
  locality: 'Synthetic locality',
  administrativeArea: 'Synthetic area',
  point: PlacePoint(46, 11),
);

class _Gateway implements PlaceSearchGateway {
  @override
  bool get available => true;
  final requests = <PlaceSearchRequest>[];
  final resolutions = <(PlaceSuggestion, String)>[];
  final searchReplies = <Completer<List<PlaceSuggestion>>>[];
  final resolveReplies = <Completer<ResolvedPlace>>[];
  @override
  Future<List<PlaceSuggestion>> search(PlaceSearchRequest request) {
    requests.add(request);
    final reply = Completer<List<PlaceSuggestion>>();
    searchReplies.add(reply);
    return reply.future;
  }

  @override
  Future<ResolvedPlace> resolve(PlaceSuggestion suggestion, String token) {
    resolutions.add((suggestion, token));
    final reply = Completer<ResolvedPlace>();
    resolveReplies.add(reply);
    return reply.future;
  }
}

void main() {
  testWidgets(
    'pending detail cannot retain an expired suggestion or revive its point',
    (tester) async {
      final gateway = _Gateway();
      final controller = PlaceSearchController(
        gateway: gateway,
        clock: () => _now,
      );
      addTearDown(controller.dispose);
      final item = _item(
        'expiring',
        kind: PlaceKind.address,
        expiry: _now.add(const Duration(seconds: 1)),
      );
      controller.edit('Synthetic venue', language: 'it');
      await tester.pump(const Duration(milliseconds: 350));
      gateway.searchReplies.single.complete([item]);
      await tester.pump();
      final pending = controller.select(item);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.suggestions, isEmpty);
      expect(controller.query, 'Synthetic venue');
      gateway.resolveReplies.single.complete(_resolved(item));
      await pending;
      expect(controller.selection, isNull);
    },
  );

  testWidgets(
    'foreign resolution is rejected and raw text remains uncommitted',
    (tester) async {
      final gateway = _Gateway();
      final controller = PlaceSearchController(
        gateway: gateway,
        clock: () => _now,
      );
      addTearDown(controller.dispose);
      final item = _item('chosen');
      controller.edit('User query', language: 'it');
      await tester.pump(const Duration(milliseconds: 350));
      gateway.searchReplies.single.complete([item]);
      await tester.pump();
      final pending = controller.select(item);
      gateway.resolveReplies.single.complete(
        _resolved(_item('chosen', country: 'AT')),
      );
      await pending;
      expect(controller.phase, PlaceSearchPhase.failure);
      expect(controller.selection, isNull);
      expect(controller.query, 'User query');
    },
  );

  testWidgets('production boundary stays disabled and cannot resolve a place', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gateway = container.read(placeSearchGatewayProvider);
    expect(gateway.available, isFalse);
    final controller = PlaceSearchController(gateway: gateway);
    addTearDown(controller.dispose);
    controller.edit('Synthetic address', language: 'it');
    await tester.pump(const Duration(seconds: 1));
    expect(controller.phase, PlaceSearchPhase.disabled);
    expect(controller.selection, isNull);
    expect(controller.suggestions, isEmpty);
    await expectLater(
      gateway.resolve(_item('a'), 'token'),
      throwsA(isA<PlaceSearchFailure>()),
    );
  });

  testWidgets(
    'debounce caps requests and preserves session, Italy and Trento defaults',
    (tester) async {
      final gateway = _Gateway();
      var token = 0;
      final controller = PlaceSearchController(
        gateway: gateway,
        clock: () => _now,
        tokenFactory: () => 'opaque-${++token}',
      );
      addTearDown(controller.dispose);
      controller.edit('T', language: 'it');
      controller.edit('Tr', language: 'it');
      await tester.pump(const Duration(milliseconds: 200));
      controller.edit('Trento', language: 'it');
      await tester.pump(const Duration(milliseconds: 349));
      expect(gateway.requests, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      final request = gateway.requests.single;
      expect(request.query, 'Trento');
      expect(request.countryRestriction, 'IT');
      expect(request.rankingLocality, 'Trento');
      expect(request.limit, 5);
      expect(request.language, 'it');
      gateway.searchReplies.single.complete([
        _item('foreign', country: 'AT'),
        _item('expired', expiry: _now),
        _item('one'),
        _item('one'),
        ...List.generate(9, (i) => _item('$i', kind: PlaceKind.address)),
      ]);
      await tester.pump();
      expect(controller.suggestions.length, 5);
      expect(controller.selection, isNull); // Never auto-pick even one result.
      expect(controller.suggestions.first.kind, PlaceKind.locality);
      expect(controller.suggestions.last.kind, PlaceKind.address);
      controller.edit('Other Italian city', language: 'en');
      await tester.pump(const Duration(milliseconds: 350));
      expect(gateway.requests.last.sessionToken, request.sessionToken);
      gateway.searchReplies.last.complete([]);
      await tester.pump();
      expect(controller.phase, PlaceSearchPhase.results);
      expect(controller.suggestions, isEmpty);
      controller.edit('a' * 161, language: 'it');
      await tester.pump(const Duration(seconds: 1));
      expect(gateway.requests.length, 2);
    },
  );

  testWidgets('late search cannot overwrite new text or cancellation', (
    tester,
  ) async {
    final gateway = _Gateway();
    final controller = PlaceSearchController(
      gateway: gateway,
      clock: () => _now,
    );
    addTearDown(controller.dispose);
    controller.edit('Old city', language: 'it');
    await tester.pump(const Duration(milliseconds: 350));
    controller.edit('New city', language: 'it');
    await tester.pump(const Duration(milliseconds: 350));
    gateway.searchReplies.first.complete([_item('old')]);
    gateway.searchReplies.last.complete([_item('new')]);
    await tester.pump();
    expect(controller.suggestions.single.id, 'new');
    controller.cancel();
    expect(controller.query, isEmpty);
    expect(controller.selection, isNull);
  });

  for (final kind in PlaceKind.values) {
    testWidgets(
      'explicit $kind selection invalidates on typing and rotates session',
      (tester) async {
        final gateway = _Gateway();
        var token = 0;
        final controller = PlaceSearchController(
          gateway: gateway,
          clock: () => _now,
          tokenFactory: () => 'session-${++token}',
        );
        addTearDown(controller.dispose);
        final item = _item('chosen', kind: kind);
        controller.edit('Some place', language: 'it');
        await tester.pump(const Duration(milliseconds: 350));
        gateway.searchReplies.single.complete([item]);
        await tester.pump();
        final pending = controller.select(item);
        expect(controller.phase, PlaceSearchPhase.resolving);
        gateway.resolveReplies.single.complete(_resolved(item));
        await pending;
        expect(controller.selection?.suggestion.id, 'chosen');
        controller.edit('Changed address', language: 'en');
        expect(controller.selection, isNull);
        await tester.pump(const Duration(milliseconds: 350));
        expect(gateway.requests.last.sessionToken, 'session-2');
        gateway.searchReplies.last.complete([]);
        await tester.pump();
      },
    );
  }

  testWidgets(
    'scope revocation cancels late resolve and all transient precision',
    (tester) async {
      final gateway = _Gateway();
      final controller = PlaceSearchController(
        gateway: gateway,
        clock: () => _now,
      );
      addTearDown(controller.dispose);
      final item = _item('exact', kind: PlaceKind.address);
      controller.edit('Synthetic venue', language: 'it');
      await tester.pump(const Duration(milliseconds: 350));
      gateway.searchReplies.single.complete([item]);
      await tester.pump();
      final pending = controller.select(item);
      controller
          .cancel(); // Owner lifecycle hook, no client-side role inference.
      gateway.resolveReplies.single.complete(_resolved(item));
      await pending;
      expect(controller.query, isEmpty);
      expect(controller.selection, isNull);
      expect(controller.suggestions, isEmpty);
    },
  );

  testWidgets(
    'expiry erases resolved labels and points; disposal rejects late work',
    (tester) async {
      final gateway = _Gateway();
      final controller = PlaceSearchController(
        gateway: gateway,
        clock: () => _now,
      );
      final item = _item(
        'exact',
        kind: PlaceKind.address,
        expiry: _now.add(const Duration(seconds: 2)),
      );
      controller.edit('Synthetic venue', language: 'it');
      await tester.pump(const Duration(milliseconds: 350));
      gateway.searchReplies.single.complete([item]);
      await tester.pump();
      final pending = controller.select(item);
      gateway.resolveReplies.single.complete(_resolved(item));
      await pending;
      await tester.pump(const Duration(seconds: 2));
      expect(controller.selection, isNull);
      expect(controller.query, isEmpty);
      controller.edit('Another place', language: 'en');
      await tester.pump(const Duration(milliseconds: 350));
      controller.dispose();
      gateway.searchReplies.last.complete([_item('late')]);
      await tester.pump();
      expect(controller.suggestions, isEmpty);
    },
  );

  for (final problem in [
    PlaceSearchProblem.offline,
    PlaceSearchProblem.quota,
    PlaceSearchProblem.disabled,
  ]) {
    testWidgets(
      '$problem is explicit failure with no success-shaped empty fallback',
      (tester) async {
        final gateway = _Gateway();
        final controller = PlaceSearchController(
          gateway: gateway,
          clock: () => _now,
        );
        addTearDown(controller.dispose);
        controller.edit('Synthetic place', language: 'en');
        await tester.pump(const Duration(milliseconds: 350));
        gateway.searchReplies.single.completeError(PlaceSearchFailure(problem));
        await tester.pump();
        expect(controller.phase, PlaceSearchPhase.failure);
        expect(controller.problem, problem);
        expect(controller.selection, isNull);
      },
    );
  }

  testWidgets('slow requests time out and late success stays rejected', (
    tester,
  ) async {
    final gateway = _Gateway();
    final controller = PlaceSearchController(
      gateway: gateway,
      clock: () => _now,
    );
    addTearDown(controller.dispose);
    controller.edit('Synthetic place', language: 'en');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 5));
    expect(controller.problem, PlaceSearchProblem.timeout);
    gateway.searchReplies.single.complete([_item('late')]);
    await tester.pump();
    expect(controller.selection, isNull);
    expect(controller.suggestions, isEmpty);
  });

  test(
    'public area rejects exact pin and keeps independently resolved locality',
    () {
      final exact = _resolved(_item('venue', kind: PlaceKind.address));
      expect(() => PublicPlaceArea.fromLocality(exact), throwsArgumentError);
      final broad = ResolvedPlace(
        suggestion: _item('broad'),
        locality: 'Synthetic city',
        administrativeArea: null,
        point: PlacePoint(45, 10),
      );
      final area = PublicPlaceArea.fromLocality(broad);
      expect(area.place.point?.latitude, 45);
      expect(area.place.suggestion.id, 'broad');
      expect(() => PlacePoint(double.nan, 0), throwsArgumentError);
    },
  );
}
