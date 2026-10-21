// Distribution preflight owns stricter closed-test rules than runtime config.
// Never include configuration values in errors: input may contain a secret.
import 'package:planets_mobile/core/config/google_auth_config.dart';
import 'package:planets_mobile/core/config/mock_environment_config.dart';

const _allowedKeys = {
  'APP_ENV',
  'SUPABASE_URL',
  'SUPABASE_PUBLISHABLE_KEY',
  'SENTRY_DSN',
  'ENABLE_DEMO_TOOLS',
  'GOOGLE_WEB_CLIENT_ID',
  'ENABLE_CLOSED_TEST_MOCK',
  'MOCK_SUPABASE_URL',
  'MOCK_SUPABASE_PUBLISHABLE_KEY',
  'MOCK_PERSONA_BROKER_URL',
  'MOCK_FIXTURE_GENERATION',
};

void validateStagingDistribution(Object? value) {
  if (value is! Map<String, dynamic> ||
      value.keys.any((key) => !_allowedKeys.contains(key)) ||
      value.values.any((item) => item is! String)) {
    throw const FormatException(
      'Staging config must contain only documented string keys.',
    );
  }
  parseGoogleWebClientId(value['GOOGLE_WEB_CLIENT_ID'] as String? ?? '');
  if (value['APP_ENV'] != 'staging' || value['ENABLE_DEMO_TOOLS'] != 'false') {
    throw const FormatException(
      'Closed testing requires APP_ENV=staging and ENABLE_DEMO_TOOLS="false".',
    );
  }
  final urlText = value['SUPABASE_URL'] as String? ?? '';
  final url = Uri.tryParse(urlText);
  if (url == null ||
      url.scheme != 'https' ||
      !RegExp(r'^[a-z0-9]{20}\.supabase\.co$').hasMatch(url.host) ||
      url.userInfo.isNotEmpty ||
      url.hasPort ||
      url.hasQuery ||
      url.hasFragment ||
      (url.path.isNotEmpty && url.path != '/') ||
      (urlText != url.origin && urlText != '${url.origin}/')) {
    throw const FormatException(
      'SUPABASE_URL must be the real managed test project HTTPS origin.',
    );
  }
  if (!RegExp(r'^sb_publishable_[A-Za-z0-9_-]{20,}$')
      .hasMatch(value['SUPABASE_PUBLISHABLE_KEY'] as String? ?? '')) {
    throw const FormatException(
      'Use a client-safe sb_publishable_ key from the test project.',
    );
  }
  final dsn = value['SENTRY_DSN'];
  final capability = value['ENABLE_CLOSED_TEST_MOCK'] ?? 'false';
  if (capability != 'true' && capability != 'false') {
    throw const FormatException(
      'ENABLE_CLOSED_TEST_MOCK must be true or false.',
    );
  }
  final mockConfig = MockEnvironmentConfig.parse(
    local: false,
    normalOrigin: url,
    normalKey: value['SUPABASE_PUBLISHABLE_KEY'] as String,
    mockUrl: value['MOCK_SUPABASE_URL'] as String? ?? '',
    mockKey: value['MOCK_SUPABASE_PUBLISHABLE_KEY'] as String? ?? '',
    brokerUrl: value['MOCK_PERSONA_BROKER_URL'] as String? ?? '',
    generation: value['MOCK_FIXTURE_GENERATION'] as String? ?? '',
  );
  if (capability == 'false' && mockConfig != null) {
    throw const FormatException(
      'Remove inactive mock endpoints from an ordinary staging build.',
    );
  }
  if (dsn == null ||
      (dsn != '' &&
          (dsn != dsn.trim() ||
              Uri.tryParse(dsn)?.scheme != 'https' ||
              Uri.tryParse(dsn)?.host.isEmpty != false))) {
    throw const FormatException(
      'SENTRY_DSN must be empty or a real HTTPS staging DSN.',
    );
  }
}
