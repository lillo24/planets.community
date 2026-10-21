import '../../../core/config/mock_environment_config.dart';

enum MockFailureKind {
  unavailable,
  denied,
  controlLoginRequired,
  pending,
  expired,
  invalidSession,
  storage,
  departureBlocked,
}

class MockFailure implements Exception {
  const MockFailure(this.kind);
  final MockFailureKind kind;
  @override
  String toString() => 'Mock operation failed (${kind.name}).';
}

class MockPersona {
  const MockPersona({
    required this.key,
    required this.userId,
    required this.name,
    required this.email,
    required this.scenario,
  });
  final String key, userId, name, email, scenario;
  factory MockPersona.fromJson(Map<String, dynamic> value) {
    final key = value['key'],
        id = value['user_id'],
        name = value['name'],
        email = value['email'],
        scenario = value['scenario'];
    if (key is! String ||
        !RegExp(r'^[a-z]{2,20}$').hasMatch(key) ||
        id is! String ||
        !mockUuid(id) ||
        name is! String ||
        name.trim().length < 2 ||
        name.length > 60 ||
        email is! String ||
        email != '$key@personas.planets.invalid' ||
        scenario is! String ||
        scenario.isEmpty ||
        scenario.length > 240) {
      throw const MockFailure(MockFailureKind.unavailable);
    }
    return MockPersona(
      key: key,
      userId: id,
      name: name,
      email: email,
      scenario: scenario,
    );
  }
}

bool mockUuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
).hasMatch(value);

/// Only public binding metadata belongs in installation preferences.
class MockSelection {
  const MockSelection({
    required this.rootId,
    required this.personaKey,
    required this.userId,
    required this.requestId,
    required this.revision,
    required this.origin,
  });
  final String rootId, personaKey, userId, requestId, origin;
  final int revision;
  Map<String, Object> toJson() => {
    'format': 1,
    'root': rootId,
    'persona': personaKey,
    'user': userId,
    'request': requestId,
    'revision': revision,
    'origin': origin,
    'generation': MockEnvironmentConfig.fixtureGeneration,
  };
  factory MockSelection.fromJson(
    Map<String, dynamic> value,
    MockEnvironmentConfig config,
  ) {
    final root = value['root'],
        persona = value['persona'],
        user = value['user'],
        request = value['request'],
        revision = value['revision'];
    if (value['format'] != 1 ||
        value['generation'] != MockEnvironmentConfig.fixtureGeneration ||
        value['origin'] != config.origin.origin ||
        root is! String ||
        !mockUuid(root) ||
        persona is! String ||
        !RegExp(r'^[a-z]{2,20}$').hasMatch(persona) ||
        user is! String ||
        !mockUuid(user) ||
        request is! String ||
        !mockUuid(request) ||
        revision is! int ||
        revision < 1) {
      throw const FormatException('Invalid stored mock binding.');
    }
    return MockSelection(
      rootId: root,
      personaKey: persona,
      userId: user,
      requestId: request,
      revision: revision,
      origin: config.origin.origin,
    );
  }
}

class MockBootstrap {
  const MockBootstrap(this.accessToken, this.refreshToken);
  final String accessToken, refreshToken;
  @override
  String toString() => 'MockBootstrap(<redacted>)';
}
