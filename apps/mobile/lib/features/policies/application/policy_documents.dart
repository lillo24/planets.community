import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/return_destination.dart';

// Bump with apps/site/src/policies/metadata.ts for material Terms/Rules changes.
const policyBundleVersion = 'POLICY01-2026-10-08-v1';
const policyAcceptancePath = '/policies/accept';
const accountDeletionPath = '/settings/delete-account';

String policyReturnDestination(String? candidate) {
  final destination = sanitizeReturnDestination(candidate);
  return Uri.parse(destination).path == policyAcceptancePath
      ? '/'
      : destination;
}

String policyAcceptanceDestination(String returnTo) => Uri(
  path: policyAcceptancePath,
  queryParameters: {'returnTo': policyReturnDestination(returnTo)},
).toString();

class PolicyDocuments {
  PolicyDocuments(String origin) {
    final parsed = Uri.tryParse(origin);
    if (parsed == null ||
        parsed.scheme != 'https' ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        (parsed.path.isNotEmpty && parsed.path != '/')) {
      throw const FormatException('PUBLIC_SITE_URL must be an HTTPS origin.');
    }
    _origin = parsed;
  }

  late final Uri _origin;
  Uri get privacy => _origin.resolve('/privacy');
  Uri get terms => _origin.resolve('/terms');
  Uri get rules => _origin.resolve('/community-rules');
  Uri get deletion => _origin.resolve('/delete-account');
}

final policyVersionProvider = Provider<String>((ref) => policyBundleVersion);
final policyDocumentsProvider = Provider<PolicyDocuments>(
  (ref) => PolicyDocuments(
    const String.fromEnvironment(
      'PUBLIC_SITE_URL',
      defaultValue:
          'https://planets-public-site.developer-planets-community.workers.dev',
    ),
  ),
);
