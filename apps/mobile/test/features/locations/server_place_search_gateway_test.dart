import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/locations/data/server_place_search_gateway.dart';
import 'package:planets_mobile/features/locations/domain/place_search.dart';

const actorId = '00000000-0000-4000-8000-000000000001';
const itemId = '00000000-0000-4000-8000-000000000002';
const receiptId = '00000000-0000-4000-8000-000000000003';
const sessionId = '00000000-0000-4000-8000-000000000004';
const scope = PlaceSearchScope(
  actorId: actorId,
  itemKind: 'one_time',
  itemId: itemId,
  revision: 7,
  slot: 'area',
);
Map<String, dynamic> selection({String kind = 'locality'}) => {
  'id': receiptId,
  'expires_at': '2026-10-08T12:05:00Z',
  'place': {
    'provider': 'geoapify',
    'kind': kind,
    'source': 'openstreetmap',
    'country_code': 'IT',
    'label': 'Synthetic locality',
    'locality': 'Synthetic locality',
    'administrative_area': null,
    'latitude': 45,
    'longitude': 12,
    'verified_at': '2026-10-08T12:00:00Z',
    'attribution': 'Powered by Geoapify | © OpenStreetMap contributors',
    'source_license': 'https://www.openstreetmap.org/copyright',
  },
};
PlaceSearchRequest request() => PlaceSearchRequest(
  query: 'Trento',
  sessionToken: sessionId,
  language: 'it',
);

void main() {
  test('default disabled gateway makes no endpoint call', () async {
    final gateway = ServerPlaceSearchGateway.withEndpoint(
      scope: scope,
      actor: () => actorId,
      invoke: (_) async => fail('Endpoint called'),
    );
    expect(gateway.available, isFalse);
    await expectLater(
      gateway.search(request()),
      throwsA(isA<PlaceSearchFailure>()),
    );
  });

  test('narrow search and explicit resolve preserve actor/item/revision and provenance', () async {
    final calls = <Map<String, dynamic>>[];
    final gateway = ServerPlaceSearchGateway.withEndpoint(
      scope: scope,
      actor: () => actorId,
      enabled: true,
      invoke: (body) async {
        calls.add(body);
        return body['operation'] == 'search'
            ? {
                'status': 'ok',
                'suggestions': [selection()],
              }
            : {'status': 'ok', 'selection': selection()};
      },
    );
    final suggestions = await gateway.search(request());
    final resolved = await gateway.resolve(suggestions.single, sessionId);
    expect(resolved.point!.latitude, 45);
    expect(resolved.point!.longitude, 12);
    expect(resolved.selectionReceipt, receiptId);
    expect(resolved.attribution, contains('OpenStreetMap'));
    expect(calls.first['expected_profile_id'], actorId);
    expect(calls.first['revision'], 7);
    expect(calls.last['receipt_id'], receiptId);
    expect(calls.last.containsKey('latitude'), isFalse);
    expect(calls.last.containsKey('query'), isFalse);
    expect(PublicPlaceArea.fromLocality(resolved).place, resolved);
  });

  test(
    'amenity remains exact and cannot become a public Project area',
    () async {
      final gateway = ServerPlaceSearchGateway.withEndpoint(
        scope: scope,
        actor: () => actorId,
        enabled: true,
        invoke: (body) async => body['operation'] == 'search'
            ? {
                'status': 'ok',
                'suggestions': [selection(kind: 'amenity')],
              }
            : {'status': 'ok', 'selection': selection(kind: 'amenity')},
      );
      final result = await gateway.resolve(
        (await gateway.search(request())).single,
        sessionId,
      );
      expect(result.suggestion.kind, PlaceKind.amenity);
      expect(() => PublicPlaceArea.fromLocality(result), throwsArgumentError);
    },
  );

  test(
    'switch-account rejects late search and future endpoint calls',
    () async {
      String? actor = actorId;
      final pending = Completer<dynamic>();
      var calls = 0;
      final gateway = ServerPlaceSearchGateway.withEndpoint(
        scope: scope,
        actor: () => actor,
        enabled: true,
        invoke: (_) {
          calls++;
          return pending.future;
        },
      );
      final search = gateway.search(request());
      actor = itemId;
      pending.complete({
        'status': 'ok',
        'suggestions': [selection()],
      });
      await expectLater(search, throwsA(isA<PlaceSearchFailure>()));
      await expectLater(
        gateway.search(request()),
        throwsA(isA<PlaceSearchFailure>()),
      );
      expect(gateway.available, isFalse);
      expect(calls, 1);
    },
  );

  for (final entry in {
    'disabled': PlaceSearchProblem.disabled,
    'unconfigured': PlaceSearchProblem.unconfigured,
    'budget_exhausted': PlaceSearchProblem.quota,
    'metering_unavailable': PlaceSearchProblem.metering,
    'invalid_credentials': PlaceSearchProblem.credentials,
    'expired_selection': PlaceSearchProblem.expired,
    'stale_selection': PlaceSearchProblem.stale,
    'unauthorized': PlaceSearchProblem.unauthorized,
    'unsupported_place': PlaceSearchProblem.unsupported,
  }.entries) {
    test('${entry.key} has an explicit status', () async {
      final gateway = ServerPlaceSearchGateway.withEndpoint(
        scope: scope,
        actor: () => actorId,
        enabled: true,
        invoke: (_) async => {'status': entry.key},
      );
      await expectLater(
        gateway.search(request()),
        throwsA(
          isA<PlaceSearchFailure>().having(
            (e) => e.problem,
            'problem',
            entry.value,
          ),
        ),
      );
    });
  }

  test(
    'late resolve cannot expose a selected place after actor replacement',
    () async {
      String? currentActor = actorId;
      final pending = Completer<dynamic>();
      final gateway = ServerPlaceSearchGateway.withEndpoint(
        scope: scope,
        actor: () => currentActor,
        enabled: true,
        invoke: (body) async => body['operation'] == 'search'
            ? {
                'status': 'ok',
                'suggestions': [selection()],
              }
            : pending.future,
      );
      final suggestion = (await gateway.search(request())).single;
      final resolving = gateway.resolve(suggestion, sessionId);
      currentActor = itemId;
      pending.complete({'status': 'ok', 'selection': selection()});
      await expectLater(
        resolving,
        throwsA(
          isA<PlaceSearchFailure>().having(
            (error) => error.problem,
            'problem',
            PlaceSearchProblem.unauthorized,
          ),
        ),
      );
      expect(gateway.available, isFalse);
    },
  );

  test('missing provenance and duplicate receipts fail visibly', () async {
    for (final rows in [
      [selection(), selection()],
      [
        {'id': receiptId, 'place': {}},
      ],
    ]) {
      final gateway = ServerPlaceSearchGateway.withEndpoint(
        scope: scope,
        actor: () => actorId,
        enabled: true,
        invoke: (_) async => {'status': 'ok', 'suggestions': rows},
      );
      await expectLater(
        gateway.search(request()),
        throwsA(isA<FormatException>()),
      );
    }
  });

  for (final entry in {
    401: PlaceSearchProblem.unauthorized,
    403: PlaceSearchProblem.unauthorized,
    0: PlaceSearchProblem.offline,
  }.entries) {
    test(
      'SDK failure ${entry.key} preserves its status without exposing its body',
      () async {
        final gateway = ServerPlaceSearchGateway.withEndpoint(
          scope: scope,
          actor: () => actorId,
          enabled: true,
          invoke: (_) async => throw FunctionException(
            status: entry.key,
            details: const {'private': 'SECRET'},
          ),
        );
        await expectLater(
          gateway.search(request()),
          throwsA(
            isA<PlaceSearchFailure>().having(
              (error) => error.problem,
              'problem',
              entry.value,
            ),
          ),
        );
      },
    );
  }
}
