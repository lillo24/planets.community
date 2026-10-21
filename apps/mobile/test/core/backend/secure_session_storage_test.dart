import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/backend/secure_session_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryCredentials implements ConfidentialStore {
  final values = <String, String>{};
  bool failWrite = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw const SessionStorageFailure();
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class LegacySession extends LocalStorage {
  LegacySession(this.raw);
  String? raw;
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async => raw;
  @override
  Future<bool> hasAccessToken() async => raw != null;
  @override
  Future<void> persistSession(String value) async {
    raw = value;
  }

  @override
  Future<void> removePersistedSession() async {
    raw = null;
  }
}

void main() {
  final origin = Uri.parse('https://cllpvruvrrvxczjitlqd.supabase.co');
  test(
    'normal legacy credentials move only after acknowledged confidential write',
    () async {
      final credentials = MemoryCredentials(),
          legacy = LegacySession('synthetic-session');
      final storage = SecureNormalSessionStorage(
        store: credentials,
        origin: origin,
        legacy: legacy,
      );
      credentials.failWrite = true;
      await expectLater(
        storage.initialize(),
        throwsA(isA<SessionStorageFailure>()),
      );
      expect(legacy.raw, 'synthetic-session');
      credentials.failWrite = false;
      await storage.initialize();
      expect(legacy.raw, isNull);
      expect(await storage.accessToken(), 'synthetic-session');
    },
  );
  test(
    'conflicting secure and legacy sessions fail without overwriting either',
    () async {
      final credentials = MemoryCredentials()
        ..values[normalSessionKey(origin)] = 'secure';
      final legacy = LegacySession('legacy');
      final storage = SecureNormalSessionStorage(
        store: credentials,
        origin: origin,
        legacy: legacy,
      );
      await expectLater(
        storage.initialize(),
        throwsA(isA<SessionStorageFailure>()),
      );
      expect(legacy.raw, 'legacy');
      expect(await storage.accessToken(), 'secure');
    },
  );
  test(
    'late refresh event after signout cannot resurrect stored normal login',
    () async {
      final credentials = MemoryCredentials();
      Map<String, dynamic>? current = {
        'access_token': 'new',
        'refresh_token': 'new-refresh',
      };
      final storage = SecureNormalSessionStorage(
        store: credentials,
        origin: origin,
        legacy: LegacySession(null),
        currentSession: () => current,
      );
      await storage.persistSession(jsonEncode(current));
      current = null;
      await storage.removePersistedSession();
      await storage.persistSession(
        jsonEncode({'access_token': 'old', 'refresh_token': 'old-refresh'}),
      );
      expect(await storage.accessToken(), isNull);
    },
  );
  test('old refresh callback cannot replace rotated credentials', () async {
    final credentials = MemoryCredentials();
    final current = {'access_token': 'new', 'refresh_token': 'new-refresh'};
    final storage = SecureNormalSessionStorage(
      store: credentials,
      origin: origin,
      legacy: LegacySession(null),
      currentSession: () => current,
    );
    await storage.persistSession(jsonEncode(current));
    await storage.persistSession(
      jsonEncode({'access_token': 'old', 'refresh_token': 'old-refresh'}),
    );
    expect(
      jsonDecode((await storage.accessToken())!)['refresh_token'],
      'new-refresh',
    );
  });
  test(
    'legacy loopback key cannot silently migrate across backend ports',
    () async {
      final legacy = LegacySession('unknown-local-owner');
      final storage = SecureNormalSessionStorage(
        store: MemoryCredentials(),
        origin: Uri.parse('http://127.0.0.1:56321'),
        legacy: legacy,
      );
      await expectLater(
        storage.initialize(),
        throwsA(isA<SessionStorageFailure>()),
      );
      expect(legacy.raw, 'unknown-local-owner');
    },
  );
}
