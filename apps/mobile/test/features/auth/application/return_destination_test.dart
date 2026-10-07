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

  group('profileEditCancelDestination', () {
    test('returns a Proposal or Tavolo Join intent to its public parent', () {
      expect(
        profileEditCancelDestination('/proposals/proposal-1/join'),
        '/proposals/proposal-1',
      );
      expect(
        profileEditCancelDestination('/tavoli/tavolo-1/join'),
        '/tavoli/tavolo-1',
      );
    });

    test('incomplete setup cancels to a stable public origin', () {
      expect(
        profileEditCancelDestination('/messages/chats/chat-1'),
        '/messages',
      );
      expect(
        profileEditCancelDestination('/proposals/proposal-1/join/extra'),
        '/proposals/proposal-1',
      );
      expect(profileEditCancelDestination('/resources/mine'), '/resources');
      expect(profileEditCancelDestination('/settings'), '/settings');
      expect(profileEditCancelDestination('/profile'), '/');
      expect(
        profileEditCancelDestination(null, profileReady: true),
        '/profile',
      );
      expect(
        profileEditCancelDestination('/profile', profileReady: true),
        '/profile',
      );
      for (final candidate in [
        'https://example.com/proposals/proposal-1/join',
        '//example.com/proposals/proposal-1/join',
        null,
      ]) {
        expect(profileEditCancelDestination(candidate), '/');
      }
    });
    test('cancel preserves both invitation previews and Messages context', () {
      final token = 'A' * 43;
      for (final destination in [
        '/invite/project/$token',
        '/join/project/$token',
      ]) {
        expect(profileEditCancelDestination(destination), destination);
        expect(authCancelDestination(destination), destination);
      }
      expect(authCancelDestination('/messages'), '/messages');
      expect(authCancelDestination('/messages/chats/chat-1'), '/messages');
    });
  });
}
