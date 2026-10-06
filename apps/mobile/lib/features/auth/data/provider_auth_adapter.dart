import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_models.dart';
import '../domain/provider_auth.dart';

/// Future adapters acquire native credentials, then exchange them with Supabase.
/// Only return success after establishing the canonical session. Native tokens,
/// nonce handling, and SDK exceptions must stay behind this boundary.
abstract interface class ProviderAuthAdapter {
  /// True only when the provider is configured and supported on this platform.
  bool isAvailable(AuthProvider provider);

  Future<ProviderAuthResult> signIn(AuthProvider provider);
}

class UnavailableProviderAuthAdapter implements ProviderAuthAdapter {
  const UnavailableProviderAuthAdapter();

  @override
  bool isAvailable(AuthProvider provider) => false;

  @override
  Future<ProviderAuthResult> signIn(AuthProvider provider) async =>
      const ProviderAuthFailure(AuthFailureKind.serviceUnavailable);
}

/// AUTH01A has no provider configuration or SDK initialization at startup.
final providerAuthAdapterProvider = Provider<ProviderAuthAdapter>(
  (ref) => const UnavailableProviderAuthAdapter(),
);
