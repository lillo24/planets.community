import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'google_auth_config.dart';
import 'mock_environment_config.dart';

enum AppEnvironment {
  local('local'),
  staging('staging'),
  production('production');

  const AppEnvironment(this.value);

  final String value;

  static AppEnvironment parse(String value) {
    for (final environment in values) {
      if (environment.value == value) {
        return environment;
      }
    }
    throw const AppConfigException(
      'APP_ENV must be local, staging, or production.',
    );
  }
}

final class AppConfig {
  AppConfig._({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.sentryDsn,
    required this.demoToolsEnabled,
    required this.googleWebClientId,
    required this.closedTestMockEnabled,
    required this.mockEnvironment,
  });

  factory AppConfig.fromCompileTime() {
    return AppConfig.fromValues(
      appEnvironment: const String.fromEnvironment('APP_ENV'),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
      enableDemoTools: const String.fromEnvironment('ENABLE_DEMO_TOOLS'),
      googleWebClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      enableClosedTestMock: const String.fromEnvironment(
        'ENABLE_CLOSED_TEST_MOCK',
      ),
      mockSupabaseUrl: const String.fromEnvironment('MOCK_SUPABASE_URL'),
      mockSupabasePublishableKey: const String.fromEnvironment(
        'MOCK_SUPABASE_PUBLISHABLE_KEY',
      ),
      mockPersonaBrokerUrl: const String.fromEnvironment(
        'MOCK_PERSONA_BROKER_URL',
      ),
      mockFixtureGeneration: const String.fromEnvironment(
        'MOCK_FIXTURE_GENERATION',
      ),
    );
  }

  factory AppConfig.fromValues({
    required String appEnvironment,
    required String supabaseUrl,
    required String supabasePublishableKey,
    String sentryDsn = '',
    String enableDemoTools = '',
    String googleWebClientId = '',
    String enableClosedTestMock = '',
    String mockSupabaseUrl = '',
    String mockSupabasePublishableKey = '',
    String mockPersonaBrokerUrl = '',
    String mockFixtureGeneration = '',
  }) {
    final environment = AppEnvironment.parse(
      _requireUnpaddedValue('APP_ENV', appEnvironment),
    );
    final parsedSupabaseUrl = _parseHttpUrl(
      'SUPABASE_URL',
      _requireUnpaddedValue('SUPABASE_URL', supabaseUrl),
      allowUserInfo: false,
    );

    if (environment != AppEnvironment.local &&
        parsedSupabaseUrl.scheme != 'https') {
      throw const AppConfigException(
        'SUPABASE_URL must use HTTPS outside the local environment.',
      );
    }

    final publishableKey = _requireUnpaddedValue(
      'SUPABASE_PUBLISHABLE_KEY',
      supabasePublishableKey,
    );
    final sentryValue = _optionalUnpaddedValue('SENTRY_DSN', sentryDsn);
    final parsedSentryDsn = sentryValue == null
        ? null
        : _parseHttpUrl('SENTRY_DSN', sentryValue, allowUserInfo: true);
    final demoToolsEnabled = _parseDemoToolsEnabled(
      environment,
      enableDemoTools,
    );
    final String? parsedGoogleWebClientId;
    final mockRequested = switch (enableClosedTestMock) {
      '' || 'false' => false,
      'true' => true,
      _ => throw const AppConfigException(
        'ENABLE_CLOSED_TEST_MOCK must be true or false.',
      ),
    };
    final closedTestMockEnabled =
        environment != AppEnvironment.production && !kIsWeb && mockRequested;
    if (closedTestMockEnabled && demoToolsEnabled) {
      throw const AppConfigException(
        'Mock capability requires ENABLE_DEMO_TOOLS=false.',
      );
    }
    if (closedTestMockEnabled &&
        !MockEnvironmentConfig.publicKey(publishableKey)) {
      throw const AppConfigException(
        'Mock capability requires a client-safe normal publishable key.',
      );
    }
    final MockEnvironmentConfig? mockEnvironment;
    try {
      mockEnvironment = MockEnvironmentConfig.parse(
        local: environment == AppEnvironment.local,
        normalOrigin: parsedSupabaseUrl,
        normalKey: publishableKey,
        mockUrl: mockSupabaseUrl,
        mockKey: mockSupabasePublishableKey,
        brokerUrl: mockPersonaBrokerUrl,
        generation: mockFixtureGeneration,
      );
    } on FormatException catch (error) {
      throw AppConfigException(error.message);
    }
    try {
      parsedGoogleWebClientId = parseGoogleWebClientId(googleWebClientId);
    } on FormatException catch (error) {
      throw AppConfigException(error.message);
    }

    return AppConfig._(
      environment: environment,
      supabaseUrl: parsedSupabaseUrl,
      supabasePublishableKey: publishableKey,
      sentryDsn: parsedSentryDsn,
      demoToolsEnabled: demoToolsEnabled,
      googleWebClientId: parsedGoogleWebClientId,
      closedTestMockEnabled: closedTestMockEnabled,
      mockEnvironment: mockEnvironment,
    );
  }

  final AppEnvironment environment;
  final Uri supabaseUrl;
  final String supabasePublishableKey;
  final Uri? sentryDsn;
  final bool demoToolsEnabled;
  final String? googleWebClientId;
  final bool closedTestMockEnabled;
  final MockEnvironmentConfig? mockEnvironment;

  // Closed-test realm switching never starts external monitoring, including in
  // its normal scope. Ordinary builds preserve their existing Sentry behavior.
  bool get monitoringEnabled => sentryDsn != null && !closedTestMockEnabled;

  AppConfig forMockDataRealm() {
    final mock = mockEnvironment;
    if (!closedTestMockEnabled || mock == null) {
      throw StateError('Mock environment unavailable.');
    }
    return AppConfig._(
      environment: environment,
      supabaseUrl: mock.origin,
      supabasePublishableKey: mock.publishableKey,
      sentryDsn: null,
      demoToolsEnabled: false,
      googleWebClientId: null,
      closedTestMockEnabled: true,
      mockEnvironment: mock,
    );
  }

  @override
  String toString() {
    return 'AppConfig('
        'environment: ${environment.value}, '
        'supabaseHost: ${supabaseUrl.host}, '
        'monitoringEnabled: $monitoringEnabled, '
        'demoToolsEnabled: $demoToolsEnabled)';
  }
}

final appConfigProvider = Provider<AppConfig>((ref) {
  throw StateError('appConfigProvider must be overridden during bootstrap.');
});

final class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}

String _requireUnpaddedValue(String name, String value) {
  if (value.isEmpty) {
    throw AppConfigException('$name is required.');
  }
  if (value.trim() != value) {
    throw AppConfigException('$name must not have surrounding whitespace.');
  }
  return value;
}

String? _optionalUnpaddedValue(String name, String value) {
  if (value.isEmpty) {
    return null;
  }
  return _requireUnpaddedValue(name, value);
}

bool _parseDemoToolsEnabled(
  AppEnvironment environment,
  String configuredValue,
) {
  final requested = switch (configuredValue) {
    '' => environment != AppEnvironment.production,
    'true' => true,
    'false' => false,
    _ => throw const AppConfigException(
      'ENABLE_DEMO_TOOLS must be true or false when provided.',
    ),
  };
  return environment != AppEnvironment.production && requested;
}

Uri _parseHttpUrl(String name, String value, {required bool allowUserInfo}) {
  final uri = Uri.tryParse(value);
  final isHttp = uri?.scheme == 'http' || uri?.scheme == 'https';
  final hasUnexpectedParts =
      uri == null ||
      uri.host.isEmpty ||
      uri.hasFragment ||
      uri.hasQuery ||
      (!allowUserInfo && uri.userInfo.isNotEmpty);
  if (!isHttp || hasUnexpectedParts) {
    throw AppConfigException('$name must be a valid absolute HTTP(S) URL.');
  }
  return uri;
}
