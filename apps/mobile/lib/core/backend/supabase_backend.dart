import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'realm_transport.dart';
import 'secure_session_storage.dart';

class NormalBackendRuntime {
  const NormalBackendRuntime(this.client, this.transport, this.credentials);
  final SupabaseClient client;
  final RealmTransport transport;
  final ConfidentialStore credentials;
}

NormalBackendRuntime? _normalBackend;
NormalBackendRuntime get normalBackendRuntime =>
    _normalBackend ??
    (throw StateError('Normal backend has not been initialized.'));

Future<void> initializeSupabase(AppConfig config) async {
  final transport = RealmTransport(origin: config.supabaseUrl);
  final credentials = PlatformConfidentialStore();
  await Supabase.initialize(
    url: config.supabaseUrl.toString(),
    publishableKey: config.supabasePublishableKey,
    httpClient: transport,
    authOptions: kIsWeb
        ? const FlutterAuthClientOptions()
        : FlutterAuthClientOptions(
            localStorage: SecureNormalSessionStorage(
              store: credentials,
              origin: config.supabaseUrl,
              currentSession: () =>
                  Supabase.instance.client.auth.currentSession?.toJson(),
            ),
            pkceAsyncStorage: SecurePkceStorage(
              credentials,
              config.supabaseUrl,
            ),
          ),
  );
  _normalBackend = NormalBackendRuntime(
    Supabase.instance.client,
    transport,
    credentials,
  );
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
