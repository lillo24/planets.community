import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/locations/application/location_editor_session.dart';
import 'package:planets_mobile/features/locations/data/item_location_gateway.dart';
import 'package:planets_mobile/features/locations/data/server_place_search_gateway.dart';
import 'package:planets_mobile/features/locations/domain/item_location.dart';
import 'package:planets_mobile/features/locations/domain/place_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_location.dart';

void main() {
  testWidgets(
    'receipt expiry revokes a pending ambiguous write and late result',
    (tester) async {
      final db = FakeItemLocationGateway(), factory = FakeEditorPlaceFactory();
      final reply = Completer<List<PlaceSuggestion>>();
      factory.gateway.searchReply = reply.future;
      var successes = 0;
      final session = LocationEditorSession(
        actor: () => 'A',
        kind: 'resource',
        itemId: () => 'id',
        prepare: () async => 'id',
        gateway: db,
        factory: factory,
        onCanonical: (_) => successes++,
      );
      addTearDown(session.dispose);
      await session.begin('public');
      session.search!.edit('Trento', language: 'en');
      await tester.pump(const Duration(milliseconds: 350));
      reply.complete([
        PlaceSuggestion(
          id: 'locality',
          label: 'Trento',
          countryCode: 'IT',
          kind: PlaceKind.locality,
          expiresAt: DateTime.now().add(const Duration(seconds: 1)),
        ),
      ]);
      await tester.pump();
      await session.search!.select(session.search!.suggestions.single);
      final pending = Completer<void>();
      db.applyDelay = pending.future;
      final write = session.confirm();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(session.scope, isNull);
      expect(session.canRetry, isFalse);
      expect(session.problem, PlaceSearchProblem.expired);
      pending.complete();
      expect(await write, isFalse);
      expect(successes, 0);
    },
  );
  testWidgets(
    'another writer between apply and reread cannot be shown as success',
    (tester) async {
      final db = FakeItemLocationGateway();
      var successes = 0;
      final session = LocationEditorSession(
        actor: () => 'A',
        kind: 'resource',
        itemId: () => 'id',
        prepare: () async => 'id',
        gateway: db,
        factory: FakeEditorPlaceFactory(),
        onCanonical: (_) => successes++,
      );
      addTearDown(session.dispose);
      await session.begin('public');
      session.search!.edit('Trento', language: 'en');
      await tester.pump(const Duration(milliseconds: 350));
      await session.search!.select(
        session.search!.suggestions.singleWhere(
          (p) => p.kind == PlaceKind.locality,
        ),
      );
      final read = Completer<void>();
      db.readDelay = read.future;
      final write = session.confirm();
      await tester.pump();
      db.value = ItemLocation(db.value.revision + 1);
      read.complete();
      expect(await write, isFalse);
      expect(session.problem, PlaceSearchProblem.stale);
      expect(successes, 0);
      expect(session.canonical, isNull);
    },
  );
  for (final kind in ['one_time', 'recurring', 'resource']) {
    testWidgets('$kind saves before scoped search; explicit tap/apply/reread', (
      tester,
    ) async {
      final db = FakeItemLocationGateway(), factory = FakeEditorPlaceFactory();
      String? id;
      var prepared = 0, refreshed = 0;
      final session = LocationEditorSession(
        actor: () => 'A',
        kind: kind,
        itemId: () => id,
        prepare: () async {
          prepared++;
          db.calls.add('save');
          return id = 'saved';
        },
        gateway: db,
        factory: factory,
        onCanonical: (_) => refreshed++,
      );
      addTearDown(session.dispose);
      expect(prepared, 0);
      expect(
        await session.begin(kind == 'resource' ? 'public' : 'area'),
        isTrue,
      );
      expect(db.calls.take(2), ['save', 'read:A:$kind:saved']);
      expect(factory.scopes.single.revision, 3);
      session.search!.edit('Trento', language: 'it');
      await tester.pump(const Duration(milliseconds: 350));
      expect(await session.confirm(), isFalse); // No automatic first selection.
      await session.search!.select(session.search!.suggestions.first);
      expect(refreshed, 0);
      expect(await session.confirm(), isTrue);
      expect(db.value.publicPlace, syntheticArea);
      expect(db.value.exactPlace, isNull);
      expect(refreshed, 1);
      expect(session.search, isNull);
      expect(factory.gateway.requests.single.countryRestriction, 'IT');
      expect(factory.gateway.requests.single.rankingLocality, 'Trento');
    });
  }
  testWidgets(
    'lost apply response retries same UUID/revision without content save',
    (tester) async {
      final db = FakeItemLocationGateway()..loseNextResponse = true;
      var saves = 0, refreshes = 0;
      final session = LocationEditorSession(
        actor: () => 'A',
        kind: 'recurring',
        itemId: () => 'id',
        prepare: () async {
          saves++;
          return 'id';
        },
        gateway: db,
        factory: FakeEditorPlaceFactory(),
        onCanonical: (_) => refreshes++,
      );
      addTearDown(session.dispose);
      await session.begin('area');
      session.search!.edit('Trento', language: 'en');
      await tester.pump(const Duration(milliseconds: 350));
      await session.search!.select(session.search!.suggestions.first);
      expect(await session.confirm(), isFalse);
      expect(session.canonical, isNull);
      expect(session.canRetry, isTrue);
      expect(await session.retry(), isTrue);
      expect(saves, 1);
      expect(refreshes, 1);
      expect(db.mutations.first.$2, db.mutations.last.$2);
      expect(db.mutations.first.$1.revision, db.mutations.last.$1.revision);
    },
  );
  testWidgets(
    'independent exact slot reads newer revision; partial failure retains area on server',
    (tester) async {
      final db = FakeItemLocationGateway();
      final session = LocationEditorSession(
        actor: () => 'A',
        kind: 'one_time',
        itemId: () => 'id',
        prepare: () async => 'id',
        gateway: db,
        factory: FakeEditorPlaceFactory(),
        onCanonical: (_) {},
      );
      addTearDown(session.dispose);
      await session.begin('area');
      session.search!.edit('Trento', language: 'it');
      await tester.pump(const Duration(milliseconds: 350));
      await session.search!.select(session.search!.suggestions.first);
      await session.confirm();
      await session.begin('exact');
      expect(session.scope!.revision, 4);
      session.search!.edit('Trento', language: 'it');
      await tester.pump(const Duration(milliseconds: 350));
      await session.search!.select(session.search!.suggestions[1]);
      db.applyFailure = PlaceSearchProblem.unauthorized;
      expect(await session.confirm(), isFalse);
      expect(session.canonical, isNull);
      expect(db.value.publicPlace, syntheticArea);
      expect(db.value.exactPlace, isNull);
      expect(session.canRetry, isFalse);
    },
  );
  testWidgets(
    'A to B to A cancellation and content invalidation reject late protected read',
    (tester) async {
      final barrier = Completer<void>(), db = FakeItemLocationGateway();
      String? actor = 'A';
      final session = LocationEditorSession(
        actor: () => actor,
        kind: 'one_time',
        itemId: () => 'id',
        prepare: () async => 'id',
        gateway: db,
        factory: FakeEditorPlaceFactory(),
        onCanonical: (_) {},
      );
      addTearDown(session.dispose);
      db.readDelay = barrier.future;
      final pending = session.begin('exact');
      await tester.pump();
      actor = 'B';
      session.cancel(eraseCanonical: true);
      actor = 'A';
      barrier.complete();
      expect(await pending, isFalse);
      expect(session.canonical, isNull);
      expect(session.search, isNull);
      db.readDelay = null;
      await session.begin('exact');
      session.invalidateContent();
      expect(session.scope, isNull);
      expect(session.canonical, isNull);
      await tester.pump();
    },
  );
  testWidgets(
    'reread failure cannot claim success; clear is a canonical one-slot operation',
    (tester) async {
      final db = FakeItemLocationGateway();
      var success = 0;
      final session = LocationEditorSession(
        actor: () => 'A',
        kind: 'resource',
        itemId: () => 'id',
        prepare: () async => 'id',
        gateway: db,
        factory: FakeEditorPlaceFactory(),
        onCanonical: (_) => success++,
      );
      addTearDown(session.dispose);
      await session.begin('public');
      session.search!.edit('Trento', language: 'en');
      await tester.pump(const Duration(milliseconds: 350));
      await session.search!.select(session.search!.suggestions[1]);
      db.readFailure = PlaceSearchProblem.offline;
      expect(await session.confirm(), isFalse);
      expect(success, 0);
      db.readFailure = null;
      expect(await session.retry(), isTrue);
      expect(await session.clear('public'), isTrue);
      expect(db.value.publicPlace, isNull);
      expect(db.mutations.last.$3, 'clear');
      expect(db.mutations.last.$4, isNull);
    },
  );
  test(
    'RPC sends receipt/actions only; safe denial codes hide upstream details',
    () async {
      Map<String, dynamic>? sent;
      final gateway = RpcItemLocationGateway((name, params) async {
        sent = params;
        return 8;
      });
      expect(
        await gateway.apply(
          const PlaceSearchScope(
            actorId: 'A',
            itemKind: 'one_time',
            itemId: 'id',
            revision: 7,
            slot: 'exact',
          ),
          requestId: 'uuid',
          action: 'replace',
          receipt: 'receipt',
        ),
        8,
      );
      expect(sent!['p_public_action'], 'unchanged');
      expect(sent!['p_exact_receipt'], 'receipt');
      expect(
        sent!.keys.any(
          (k) =>
              k.contains('latitude') ||
              k.contains('label') ||
              k.contains('query'),
        ),
        isFalse,
      );
      final denied = RpcItemLocationGateway(
        (_, _) async => throw const PostgrestException(
          message: 'SECRET upstream URL',
          code: '42501',
        ),
      );
      await expectLater(
        denied.read('A', 'resource', 'id'),
        throwsA(
          isA<PlaceSearchFailure>().having(
            (e) => e.problem,
            'problem',
            PlaceSearchProblem.unauthorized,
          ),
        ),
      );
    },
  );
}
