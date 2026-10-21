import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/client_compatibility.dart';

enum ImmediateUpdateOutcome { completed, cancelled, unavailable, failed }

abstract interface class ClientCompatibilityGateway {
  Future<InstalledClient> installedClient(ClientPlatform platform);
  Future<ClientCompatibilityPolicy> policy(InstalledClient installed);
  Future<ImmediateUpdateOutcome> immediateAndroidUpdate();
  Future<bool> openStore(Uri url);
}

class PlatformClientCompatibilityGateway implements ClientCompatibilityGateway {
  const PlatformClientCompatibilityGateway(this.client);
  final SupabaseClient client;

  @override
  Future<InstalledClient> installedClient(ClientPlatform platform) async {
    final info = await PackageInfo.fromPlatform();
    return InstalledClient(
      platform: platform,
      applicationId: info.packageName,
      version: info.version,
      build: info.buildNumber,
    );
  }

  @override
  Future<ClientCompatibilityPolicy> policy(InstalledClient installed) async {
    final result = await client.functions.invoke(
      'client-compatibility',
      body: {
        'platform': installed.platform.name,
        'application_id': installed.applicationId,
      },
    );
    if (result.status != 200) {
      throw StateError('Client compatibility policy read failed.');
    }
    return ClientCompatibilityPolicy.parse(result.data, installed);
  }

  @override
  Future<ImmediateUpdateOutcome> immediateAndroidUpdate() async {
    // Google owns consent/download/install UI. Re-check before every attempt;
    // Play AppUpdateInfo is single-use. In-progress immediate flows resume here
    // after process recreation, and through the plugin's native resume handler.
    final info = await InAppUpdate.checkForUpdate().timeout(
      const Duration(seconds: 8),
    );
    final resuming =
        info.updateAvailability ==
        UpdateAvailability.developerTriggeredUpdateInProgress;
    if (!resuming &&
        (info.updateAvailability != UpdateAvailability.updateAvailable ||
            !info.immediateUpdateAllowed)) {
      return ImmediateUpdateOutcome.unavailable;
    }
    return switch (await InAppUpdate.performImmediateUpdate()) {
      AppUpdateResult.success => ImmediateUpdateOutcome.completed,
      AppUpdateResult.userDeniedUpdate => ImmediateUpdateOutcome.cancelled,
      AppUpdateResult.inAppUpdateFailed => ImmediateUpdateOutcome.failed,
    };
  }

  @override
  Future<bool> openStore(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}

final clientPlatformProvider = Provider<ClientPlatform?>((ref) {
  if (kIsWeb) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => ClientPlatform.android,
    TargetPlatform.iOS => ClientPlatform.ios,
    _ => null,
  };
});

final clientCompatibilityGatewayProvider = Provider<ClientCompatibilityGateway>(
  (ref) =>
      PlatformClientCompatibilityGateway(ref.watch(supabaseClientProvider)),
);
