import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/backend/realm_transport.dart';
import 'package:planets_mobile/core/backend/secure_session_storage.dart';
import 'package:planets_mobile/features/mock_mode/data/mock_session_access.dart';
import 'package:planets_mobile/features/mock_mode/domain/mock_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RetirementStore implements ConfidentialStore {
  int deletes = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {
    deletes++;
    await gate?.future;
    if (fail) throw const SessionStorageFailure();
  }
}

void main() {
  SupabaseMockRealm realm(RetirementStore store) {
    final origin = Uri.parse('http://127.0.0.1:56321');
    final transport = RealmTransport(origin: origin, mock: true);
    return SupabaseMockRealm(
      MockSelection(
        rootId: '11000000-0000-4000-8000-000000000001',
        userId: '81000000-0000-4000-8000-000000000001',
        personaKey: 'giulia',
        requestId: '22000000-0000-4000-8000-000000000001',
        revision: 1,
        origin: origin.origin,
      ),
      SupabaseClient(
        origin.origin,
        'sb_publishable_unit_fixture_123456789',
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
      transport,
      store,
    );
  }

  test(
    'concurrent scoped retirement coalesces and fences its transport',
    () async {
      final store = RetirementStore()..gate = Completer<void>();
      final candidate = realm(store);
      final first = candidate.retire();
      final second = candidate.retire();
      await Future<void>.delayed(Duration.zero);
      expect(candidate.transport.productBlocked, isTrue);
      expect(store.deletes, 1);
      store.gate!.complete();
      await Future.wait([first, second]);
      await candidate.retire();
      expect(store.deletes, 1);
      expect(candidate.retired, isTrue);
    },
  );
  test(
    'failed secure deletion remains an explicit retryable cleanup',
    () async {
      final store = RetirementStore()..fail = true;
      final candidate = realm(store);
      await expectLater(
        candidate.retire(),
        throwsA(isA<SessionStorageFailure>()),
      );
      expect(candidate.retired, isTrue);
      expect(candidate.transport.productBlocked, isTrue);
      store.fail = false;
      await candidate.retire();
      expect(store.deletes, 2);
    },
  );
}
