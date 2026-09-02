import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('isExpectedProfileAnchorDuplicate', () {
    test('accepts only the profiles primary-key duplicate', () {
      expect(
        isExpectedProfileAnchorDuplicate(
          const PostgrestException(
            message: 'duplicate key value violates unique constraint "profiles_pkey"',
            code: '23505',
          ),
        ),
        isTrue,
      );
    });

    test('rejects unrelated unique and database failures', () {
      expect(
        isExpectedProfileAnchorDuplicate(
          const PostgrestException(
            message:
                'duplicate key value violates unique constraint "other_key"',
            code: '23505',
          ),
        ),
        isFalse,
      );
      expect(
        isExpectedProfileAnchorDuplicate(
          const PostgrestException(message: 'permission denied', code: '42501'),
        ),
        isFalse,
      );
    });
  });
}
