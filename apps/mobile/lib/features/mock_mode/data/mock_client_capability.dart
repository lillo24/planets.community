import 'dart:convert';

import '../../../core/backend/secure_session_storage.dart';
import '../../../core/config/mock_environment_config.dart';
import '../domain/mock_models.dart';

/// Random server-issued installation capability. It represents no human account
/// and grants no normal-realm authority. Only its public ID enters preferences.
class MockClientCapability {
  const MockClientCapability(this.id, this.secret);
  final String id, secret;
  @override
  String toString() => 'MockClientCapability(<redacted>)';
}

class MockClientCapabilityStore {
  MockClientCapabilityStore({
    required this.config,
    required this.credentials,
    required this.bootstrap,
  });
  final MockEnvironmentConfig config;
  final ConfidentialStore credentials;
  final Future<Map<String, dynamic>> Function() bootstrap;
  MockClientCapability? _value;
  Future<MockClientCapability>? _loading;
  String? get id => _value?.id;
  String get key => 'planets.mock.client.v2.${sessionNamespace(config.origin)}';

  Future<MockClientCapability> obtain({String? expectedId}) async {
    final value =
        _value ??
        await (_loading ??= _load(existingOnly: expectedId != null)
            .whenComplete(() => _loading = null));
    if (expectedId != null && value.id != expectedId) {
      throw const MockFailure(MockFailureKind.invalidSession);
    }
    return value;
  }

  Future<MockClientCapability> _load({required bool existingOnly}) async {
    try {
      final saved = await credentials.read(key);
      if (saved == null && existingOnly) {
        throw const MockFailure(MockFailureKind.invalidSession);
      }
      final Object? decoded = saved == null
          ? await bootstrap()
          : jsonDecode(saved);
      if (decoded is! Map<String, dynamic> ||
          decoded['project_ref'] != MockEnvironmentConfig.projectRef ||
          decoded['generation'] != MockEnvironmentConfig.fixtureGeneration ||
          decoded['client_id'] is! String ||
          !mockUuid(decoded['client_id'] as String) ||
          decoded['capability'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$')
              .hasMatch(decoded['capability'] as String)) {
        throw const MockFailure(MockFailureKind.invalidSession);
      }
      if (saved == null) {
        final raw = jsonEncode(decoded);
        await credentials.write(key, raw);
        if (await credentials.read(key) != raw) {
          throw const MockFailure(MockFailureKind.storage);
        }
      }
      return _value = MockClientCapability(
        decoded['client_id'] as String,
        decoded['capability'] as String,
      );
    } on FormatException {
      throw const MockFailure(MockFailureKind.invalidSession);
    } on SessionStorageFailure {
      throw const MockFailure(MockFailureKind.storage);
    }
  }
}
