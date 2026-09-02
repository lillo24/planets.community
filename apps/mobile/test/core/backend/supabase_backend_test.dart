import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/backend/supabase_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Supabase client dependency can be overridden', () {
    final client = SupabaseClient('https://example.test', 'test-key');
    final container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    expect(identical(container.read(supabaseClientProvider), client), isTrue);
  });
}
