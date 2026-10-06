import 'auth_models.dart';

enum AuthProvider { google, apple }

/// Results after native credential acquisition and canonical session exchange.
/// Vendor SDK objects and credentials stay inside the data-layer adapter.
sealed class ProviderAuthResult {
  const ProviderAuthResult();
}

/// The identity must belong to the established Supabase session, not the vendor.
final class ProviderAuthSuccess extends ProviderAuthResult {
  const ProviderAuthSuccess(this.identity);

  final AuthIdentity identity;
}

final class ProviderAuthCancelled extends ProviderAuthResult {
  const ProviderAuthCancelled();
}

final class ProviderAuthFailure extends ProviderAuthResult {
  const ProviderAuthFailure(this.failure);

  final AuthFailureKind failure;
}
