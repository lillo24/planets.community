enum ClientPlatform { android, ios }

/// Numeric components, never lexical strings (1.10 follows 1.9). iOS build
/// numbers may have up to three components; Android versionCode is an integer.
class ClientVersion implements Comparable<ClientVersion> {
  ClientVersion._(this.parts);
  final List<int> parts;

  factory ClientVersion.parse(String value, {bool build = false}) {
    final pattern = build
        ? RegExp(r'^(0|[1-9]\d{0,9})(\.(0|[1-9]\d{0,9})){0,2}$')
        : RegExp(r'^(0|[1-9]\d{0,8})\.(0|[1-9]\d{0,8})\.(0|[1-9]\d{0,8})$');
    if (!pattern.hasMatch(value)) {
      throw const FormatException('Invalid app version.');
    }
    return ClientVersion._(
      value.split('.').map(int.parse).toList(growable: false),
    );
  }

  @override
  int compareTo(ClientVersion other) {
    for (var i = 0; i < 3; i++) {
      final result = (i < parts.length ? parts[i] : 0).compareTo(
        i < other.parts.length ? other.parts[i] : 0,
      );
      if (result != 0) return result;
    }
    return 0;
  }
}

class InstalledClient {
  InstalledClient({
    required this.platform,
    required this.applicationId,
    required String version,
    required String build,
  }) : version = ClientVersion.parse(version),
       build = ClientVersion.parse(build, build: true) {
    if (platform == ClientPlatform.android &&
        (build.contains('.') || int.parse(build) > 2100000000)) {
      throw const FormatException('Invalid Android versionCode.');
    }
  }
  final ClientPlatform platform;
  final String applicationId;
  final ClientVersion version;
  final ClientVersion build;
}

class ClientCompatibilityPolicy {
  ClientCompatibilityPolicy._(
    this.minimumVersion,
    this.minimumBuild,
    this.updateUrl,
  );
  final ClientVersion minimumVersion;
  final ClientVersion minimumBuild;
  final Uri? updateUrl;

  factory ClientCompatibilityPolicy.parse(
    Object? value,
    InstalledClient installed,
  ) {
    const keys = {
      'schema_version',
      'platform',
      'application_id',
      'minimum_version',
      'minimum_build',
      'update_url',
    };
    if (value is! Map ||
        value.length != keys.length ||
        !value.keys.every(keys.contains) ||
        value['schema_version'] != 1 ||
        value['platform'] != installed.platform.name ||
        value['application_id'] != installed.applicationId ||
        value['minimum_version'] is! String ||
        value['minimum_build'] is! String) {
      throw const FormatException('Invalid client compatibility policy.');
    }
    final minimumVersion = ClientVersion.parse(
      value['minimum_version'] as String,
    );
    final minimumBuildText = value['minimum_build'] as String;
    final minimumBuild = ClientVersion.parse(minimumBuildText, build: true);
    if (installed.platform == ClientPlatform.android &&
        (minimumBuildText.contains('.') ||
            int.parse(minimumBuildText) > 2100000000)) {
      throw const FormatException('Invalid Android minimum versionCode.');
    }
    final url = value['update_url'];
    Uri? parsed;
    if (url != null) {
      if (url is! String) throw const FormatException('Invalid update URL.');
      parsed = Uri.tryParse(url);
      final safe =
          parsed != null &&
          parsed.scheme == 'https' &&
          parsed.userInfo.isEmpty &&
          !parsed.hasFragment &&
          !parsed.hasPort &&
          (installed.platform == ClientPlatform.android
              ? parsed.host == 'play.google.com' &&
                    parsed.path == '/store/apps/details' &&
                    parsed.queryParameters.length == 1 &&
                    parsed.queryParametersAll['id']?.length == 1 &&
                    parsed.queryParameters['id'] == installed.applicationId
              : parsed.host == 'apps.apple.com' &&
                    !parsed.hasQuery &&
                    RegExp(r'^/app/id[1-9]\d{0,19}$').hasMatch(parsed.path));
      if (!safe) {
        throw const FormatException(
          'Update URL is not an exact platform store listing.',
        );
      }
    }
    if (parsed == null &&
        (minimumVersion.compareTo(ClientVersion.parse('0.0.0')) != 0 ||
            minimumBuild.compareTo(ClientVersion.parse('0', build: true)) !=
                0)) {
      throw const FormatException(
        'An active version floor requires a store listing.',
      );
    }
    return ClientCompatibilityPolicy._(minimumVersion, minimumBuild, parsed);
  }

  bool supports(InstalledClient installed) {
    final version = installed.version.compareTo(minimumVersion);
    return version > 0 ||
        (version == 0 && installed.build.compareTo(minimumBuild) >= 0);
  }
}
