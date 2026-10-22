import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public content links use the app's HTTPS-only external-application policy.
/// Credentials, IP/local hosts, ports and unsafe schemes never reach a launcher.
class PublicExternalLink {
  const PublicExternalLink._(this.uri);
  final Uri uri;

  static PublicExternalLink parse(String value) {
    final uri = Uri.tryParse(value);
    if (value.length > 2048 ||
        value.runes.any((rune) => rune <= 0x20 || rune == 0x7f) ||
        RegExp(r'[\s<>\\]').hasMatch(value) ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$')
            .hasMatch(uri.host) ||
        RegExp(
          r'\.(localhost|local|internal)$',
          caseSensitive: false,
        ).hasMatch(uri.host)) {
      throw const FormatException('Invalid public external link.');
    }
    return PublicExternalLink._(uri);
  }
}

abstract interface class PublicExternalLinkLauncher {
  Future<bool> open(PublicExternalLink link);
}

class ExternalApplicationLinkLauncher implements PublicExternalLinkLauncher {
  const ExternalApplicationLinkLauncher();

  @override
  Future<bool> open(PublicExternalLink link) async {
    try {
      return await launchUrl(link.uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}

final publicExternalLinkLauncherProvider = Provider<PublicExternalLinkLauncher>(
  (ref) => const ExternalApplicationLinkLauncher(),
);
