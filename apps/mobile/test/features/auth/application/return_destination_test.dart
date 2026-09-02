import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/return_destination.dart';

void main() {
  group('sanitizeReturnDestination', () {
    test('keeps an internal application path and query', () {
      expect(
        sanitizeReturnDestination('/proposals?nearby=true'),
        '/proposals?nearby=true',
      );
    });

    test('falls back for external, protocol-relative, and auth paths', () {
      for (final candidate in [
        'https://example.com/private',
        '//example.com/private',
        r'\example.com\private',
        '/auth',
        '/auth/verify',
      ]) {
        expect(sanitizeReturnDestination(candidate), '/');
      }
    });

    test('falls back for empty and relative paths', () {
      expect(sanitizeReturnDestination(null), '/');
      expect(sanitizeReturnDestination(''), '/');
      expect(sanitizeReturnDestination('proposals'), '/');
    });
  });
}
