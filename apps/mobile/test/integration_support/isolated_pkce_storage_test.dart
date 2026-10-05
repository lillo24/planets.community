import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../integration_test/isolated_pkce_storage.dart';

void main() {
  test(
    'direct smoke clients retain PKCE with usable protocol storage',
    () async {
      final storage = IsolatedPkceStorage();
      final options = AuthClientOptions(pkceAsyncStorage: storage);
      expect(options.authFlowType, AuthFlowType.pkce);
      expect(options.pkceAsyncStorage, same(storage));
      expect(await storage.getItem(key: 'verifier'), isNull);
      await storage.setItem(key: 'verifier', value: 'synthetic verifier');
      expect(await storage.getItem(key: 'verifier'), 'synthetic verifier');
      await storage.removeItem(key: 'verifier');
      expect(await storage.getItem(key: 'verifier'), isNull);
    },
  );

  test('app and staff verifier stores are isolated', () async {
    final app = IsolatedPkceStorage();
    final staff = IsolatedPkceStorage();
    await app.setItem(key: 'verifier', value: 'synthetic app verifier');
    await staff.setItem(key: 'verifier', value: 'synthetic staff verifier');
    expect(await app.getItem(key: 'verifier'), 'synthetic app verifier');
    expect(await staff.getItem(key: 'verifier'), 'synthetic staff verifier');
    await app.removeItem(key: 'verifier');
    expect(await staff.getItem(key: 'verifier'), 'synthetic staff verifier');
  });

  test('cleanup clears every stored verifier', () async {
    final storage = IsolatedPkceStorage();
    await storage.setItem(key: 'first', value: 'synthetic first');
    await storage.setItem(key: 'second', value: 'synthetic second');
    storage.clear();
    expect(await storage.getItem(key: 'first'), isNull);
    expect(await storage.getItem(key: 'second'), isNull);
    await storage.removeItem(key: 'missing');
  });
}
