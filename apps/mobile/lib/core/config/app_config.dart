import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.sentryDsn,
  });

  factory AppConfig.fromCompileTime() {
    return AppConfig.fromValues(
      appEnvironment: const String.fromEnvironment('APP_ENV'),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
    );
  }

  factory AppConfig.fromValues({
    required String appEnvironment,
    required String supabaseUrl,
    required String supabasePublishableKey,
    String sentryDsn = '',
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

    return AppConfig(
      environment: environment,
      supabaseUrl: parsedSupabaseUrl,
      supabasePublishableKey: publishableKey,
      sentryDsn: parsedSentryDsn,
    );
  }

  final AppEnvironment environment;
  final Uri supabaseUrl;
  final String supabasePublishableKey;
  final Uri? sentryDsn;

  bool get monitoringEnabled => sentryDsn != null;

  @override
  String toString() {
    return 'AppConfig('
        'environment: ${environment.value}, '
        'supabaseHost: ${supabaseUrl.host}, '
        'monitoringEnabled: $monitoringEnabled)';
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
