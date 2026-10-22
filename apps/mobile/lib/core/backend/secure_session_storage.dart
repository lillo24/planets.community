import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ConfidentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SessionStorageFailure implements Exception {
  const SessionStorageFailure();
  @override
  String toString() =>
      'Confidential session storage failed. Unlock the device and retry.';
}

/// Device storage fails loudly; Android must never silently reset a broken key.
/// Apple credentials are available after first unlock on this device only.
class PlatformConfidentialStore implements ConfidentialStore {
  PlatformConfidentialStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  final FlutterSecureStorage _storage;
  final _tails = <String, Future<void>>{};
  Future<T> _run<T>(String key, Future<T> Function() action) {
    final result = (_tails[key] ?? Future<void>.value()).then((_) async {
      try {
        return await action();
      } on Exception {
        throw const SessionStorageFailure();
      }
    });
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[key] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tails[key], tail)) _tails.remove(key);
      }),
    );
    return result;
  }

  @override
  Future<String?> read(String key) => _run(key, () => _storage.read(key: key));
  @override
  Future<void> write(String key, String value) =>
      _run(key, () => _storage.write(key: key, value: value));
  @override
  Future<void> delete(String key) => _run(key, () => _storage.delete(key: key));
}

String sessionNamespace(Uri origin) =>
    base64Url.encode(utf8.encode(origin.origin)).replaceAll('=', '');
String normalSessionKey(Uri origin) =>
    'planets.session.v1.normal.${sessionNamespace(origin)}';
String mockSessionKey(Uri origin, String root, String request) =>
    'planets.session.v1.mock.${sessionNamespace(origin)}.$root.$request';

/// Supabase Flutter remains the single refresh/persistence owner of normal Auth.
/// Existing SDK preferences migrate once, only after a verified secure write.
class SecureNormalSessionStorage extends LocalStorage {
  SecureNormalSessionStorage({
    required this.store,
    required this.origin,
    LocalStorage? legacy,
    this.currentSession,
  }) : _legacy =
           legacy ??
           SharedPreferencesLocalStorage(
             persistSessionKey: 'sb-${origin.host.split('.').first}-auth-token',
           );
  final ConfidentialStore store;
  final Uri origin;
  final LocalStorage _legacy;
  final Map<String, dynamic>? Function()? currentSession;
  String get _key => normalSessionKey(origin);
  @override
  Future<void> initialize() async {
    await _legacy.initialize();
    final old = await _legacy.accessToken();
    if (old == null) return;
    if (origin.scheme != 'https' || origin.hasPort) {
      // Legacy SDK keys do not encode a port. Their ownership cannot be proved
      // across disposable loopback backends, so require explicit recovery.
      throw const SessionStorageFailure();
    }
    final secured = await store.read(_key);
    if (secured != null && secured != old) throw const SessionStorageFailure();
    await store.write(_key, old);
    if (await store.read(_key) != old) throw const SessionStorageFailure();
    await _legacy.removePersistedSession();
    if (await _legacy.accessToken() != null) {
      throw const SessionStorageFailure();
    }
  }

  @override
  Future<bool> hasAccessToken() async => await store.read(_key) != null;
  @override
  Future<String?> accessToken() => store.read(_key);
  @override
  Future<void> persistSession(String persistSessionString) async {
    if (currentSession case final current?) {
      final snapshot = current();
      if (snapshot == null) return;
      final Map<String, dynamic> incoming;
      try {
        incoming = jsonDecode(persistSessionString) as Map<String, dynamic>;
      } on FormatException {
        throw const SessionStorageFailure();
      } on TypeError {
        throw const SessionStorageFailure();
      }
      if (incoming['access_token'] != snapshot['access_token'] ||
          incoming['refresh_token'] != snapshot['refresh_token']) {
        return;
      }
    }
    await store.write(_key, persistSessionString);
  }

  @override
  Future<void> removePersistedSession() => store.delete(_key);
}

class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage(this.store, this.origin);
  final ConfidentialStore store;
  final Uri origin;
  String _key(String key) => 'planets.pkce.v1.${sessionNamespace(origin)}.$key';
  @override
  Future<String?> getItem({required String key}) => store.read(_key(key));
  @override
  Future<void> setItem({required String key, required String value}) =>
      store.write(_key(key), value);
  @override
  Future<void> removeItem({required String key}) => store.delete(_key(key));
}
