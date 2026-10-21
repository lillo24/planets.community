import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/mock_environment_config.dart';
import '../../../core/backend/secure_session_storage.dart';
import '../domain/mock_models.dart';

class MockModeRecord {
  const MockModeRecord({
    this.active,
    this.pending,
    this.revision = 0,
    this.normalWasSignedIn = false,
  });
  final MockSelection? active, pending;
  final int revision;
  final bool normalWasSignedIn;
}

abstract interface class MockModeStore {
  Future<MockModeRecord> read(MockEnvironmentConfig config);
  Future<void> write(MockModeRecord record);
}

class PreferencesMockModeStore implements MockModeStore {
  PreferencesMockModeStore({
    SharedPreferencesAsync? preferences,
    this.legacyCredentials,
  }) : _preferences = preferences ?? SharedPreferencesAsync();
  static const key = 'planets.mock.mode.v1';
  final SharedPreferencesAsync _preferences;
  final ConfidentialStore? legacyCredentials;
  Future<void> _tail = Future<void>.value();
  int _lastRevision = -1;
  @override
  Future<MockModeRecord> read(MockEnvironmentConfig config) async {
    final raw = await _preferences.getString(key);
    if (raw == null) return const MockModeRecord();
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic> && value['format'] == 1) {
        // Retire only exact legacy mock-session keys, never the normal account.
        // Server upgrade separately revokes the retired control's mock sessions.
        for (final binding in [value['active'], value['pending']]) {
          if (binding is Map<String, dynamic> &&
              binding['origin'] == config.origin.origin &&
              binding['root'] is String &&
              mockUuid(binding['root'] as String) &&
              binding['request'] is String &&
              mockUuid(binding['request'] as String)) {
            if (legacyCredentials == null) {
              throw const MockFailure(MockFailureKind.storage);
            }
            await legacyCredentials!.delete(
              mockSessionKey(
                config.origin,
                binding['root'] as String,
                binding['request'] as String,
              ),
            );
          }
        }
        await _preferences.remove(key);
        return const MockModeRecord();
      }
      if (value is! Map<String, dynamic> ||
          value['format'] != 2 ||
          value['revision'] is! int ||
          (value['revision'] as int) < 0) {
        return const MockModeRecord();
      }
      for (final binding in [value['active'], value['pending']]) {
        if (binding is Map<String, dynamic> &&
            binding['format'] == 2 &&
            (binding['generation'] != MockEnvironmentConfig.fixtureGeneration ||
                binding['origin'] != config.origin.origin)) {
          throw const MockFailure(MockFailureKind.invalidSession);
        }
      }
      return MockModeRecord(
        active: value['active'] == null
            ? null
            : MockSelection.fromJson(
                value['active'] as Map<String, dynamic>,
                config,
              ),
        pending: value['pending'] == null
            ? null
            : MockSelection.fromJson(
                value['pending'] as Map<String, dynamic>,
                config,
              ),
        revision: value['revision'] as int,
        normalWasSignedIn: value['normalWasSignedIn'] == true,
      );
    } on FormatException {
      return const MockModeRecord();
    } on TypeError {
      return const MockModeRecord();
    }
  }

  @override
  Future<void> write(MockModeRecord record) {
    final operation = _tail.then((_) async {
      if (record.revision < _lastRevision) return;
      await _preferences.setString(
        key,
        jsonEncode({
          'format': 2,
          'normalWasSignedIn': record.normalWasSignedIn,
          'revision': record.revision,
          'active': record.active?.toJson(),
          'pending': record.pending?.toJson(),
        }),
      );
      _lastRevision = record.revision;
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }
}
