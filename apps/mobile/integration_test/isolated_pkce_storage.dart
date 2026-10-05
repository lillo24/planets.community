import 'package:supabase_flutter/supabase_flutter.dart';

// Test-only SDK protocol storage, not a fake Auth service. Each real OTP client
// owns its PKCE verifier map; nothing is shared or persisted on the device.
class IsolatedPkceStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }

  void clear() => _values.clear();
}
