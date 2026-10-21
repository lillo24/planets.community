import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/backend/secure_session_storage.dart';
import 'package:planets_mobile/core/config/mock_environment_config.dart';
import 'package:planets_mobile/features/mock_mode/data/mock_client_capability.dart';
import 'package:planets_mobile/features/mock_mode/domain/mock_models.dart';

import 'mock_mode_coordinator_test.dart' as fixtures;

class ClientCredentials implements ConfidentialStore {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw const SessionStorageFailure();
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  Map<String, dynamic> delivery() => {
    'project_ref': MockEnvironmentConfig.projectRef,
    'generation': MockEnvironmentConfig.fixtureGeneration,
    'client_id': fixtures.root,
    'capability': 'a' * 64,
  };
  test('fresh guest coalesces bootstrap and persists the opaque capability only confidentially', () async {
    final store = ClientCredentials();
    final gate = Completer<Map<String, dynamic>>();
    var calls = 0;
    final client = MockClientCapabilityStore(
      config: fixtures.mockConfig(),
      credentials: store,
      bootstrap: () {
        calls++;
        return gate.future;
      },
    );
    final first = client.obtain(), second = client.obtain();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    expect(client.id, isNull);
    gate.complete(delivery());
    expect((await first).id, fixtures.root);
    expect(await second, same(await first));
    expect(jsonDecode(store.values.values.single)['capability'], 'a' * 64);
    expect((await first).toString(), isNot(contains('a' * 64)));
  });
  test(
    'restart uses the original confidential capability without a new bootstrap',
    () async {
      final store = ClientCredentials();
      var calls = 0;
      MockClientCapabilityStore client() => MockClientCapabilityStore(
        config: fixtures.mockConfig(),
        credentials: store,
        bootstrap: () async {
          calls++;
          return delivery();
        },
      );
      final first = await client().obtain();
      final restored = await client().obtain(expectedId: first.id);
      expect(restored.secret, first.secret);
      expect(calls, 1);
    },
  );
  test(
    'missing or mismatched capability cannot adopt a remembered operation',
    () async {
      final store = ClientCredentials();
      var calls = 0;
      final client = MockClientCapabilityStore(
        config: fixtures.mockConfig(),
        credentials: store,
        bootstrap: () async {
          calls++;
          return delivery();
        },
      );
      await expectLater(
        client.obtain(expectedId: fixtures.root),
        throwsA(isA<MockFailure>()),
      );
      expect(calls, 0);
      await client.obtain();
      await expectLater(
        client.obtain(expectedId: fixtures.otherRoot),
        throwsA(isA<MockFailure>()),
      );
      expect(calls, 1);
    },
  );
  test(
    'failed confidential write never establishes an in-memory client identity',
    () async {
      final store = ClientCredentials()..fail = true;
      final client = MockClientCapabilityStore(
        config: fixtures.mockConfig(),
        credentials: store,
        bootstrap: () async => delivery(),
      );
      await expectLater(
        client.obtain(),
        throwsA(
          isA<MockFailure>().having(
            (e) => e.kind,
            'storage',
            MockFailureKind.storage,
          ),
        ),
      );
      expect(client.id, isNull);
      expect(store.values, isEmpty);
    },
  );
  test('corrupt confidential data fails closed without creating another capability', () async {
    final store = ClientCredentials();
    var calls = 0;
    final client = MockClientCapabilityStore(
      config: fixtures.mockConfig(),
      credentials: store,
      bootstrap: () async {
        calls++;
        return delivery();
      },
    );
    store.values[client.key] = 'invalid-json';
    await expectLater(client.obtain(), throwsA(isA<MockFailure>()));
    expect(calls, 0);
    expect(client.id, isNull);
  });
}
