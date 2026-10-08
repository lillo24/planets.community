import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Founder-approved public mailbox, also published in apps/site/src/site-content.ts.
/// Null disables email handoff while retaining local drafting and copying.
final publicSupportEmailProvider = Provider<String?>(
  (ref) => 'developer.planets.community@gmail.com',
);

/// Only user-reviewed content belongs here; no account or diagnostic enrichment.
Uri supportMailUri(String email, {required String subject, String body = ''}) {
  if (!RegExp(r'^[^\s@?&#/]+@[^\s@?&#/]+\.[^\s@?&#/]+$').hasMatch(email)) {
    throw const FormatException('Invalid public support email');
  }
  // queryParameters would encode mailto spaces as + instead of %20.
  return Uri(
    scheme: 'mailto',
    path: email,
    query:
        'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );
}

abstract interface class SupportMailLauncher {
  /// True means the external composer opened, never that email was sent.
  Future<bool> open(Uri uri);
}

class ExternalSupportMailLauncher implements SupportMailLauncher {
  const ExternalSupportMailLauncher();

  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

final supportMailLauncherProvider = Provider<SupportMailLauncher>(
  (ref) => const ExternalSupportMailLauncher(),
);
