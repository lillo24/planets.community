import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/co_creation/domain/general_message_links.dart';

void main() {
  for (final text in [
    'https://example.org/event',
    'HTTP://EXAMPLE.ORG',
    'https://caffè.it',
    'https://例子.中国',
    'https://user@example.org/garden',
    'Try WWW.Example.com!',
    '[Local garden](https://example.org/garden?q=1).',
    'Read example.community and join us.',
    '(events.example.co.uk), thanks!',
    '«example.it»; “example.org”.',
    'Meet\u00a0example.org\u2003tomorrow',
    'www.example.org/path',
    'xn--caf-dma.it',
    'https://[::1]/example',
    'https://example.org then https://example.org again',
    '${'x' * 1988} example.org',
    '${'a@b.it ' * 280}example.org',
  ]) {
    test(
      'detect likely web link: ${text.length < 100 ? text : text.length}',
      () {
        expect(containsLikelyWebLink(text), isTrue);
      },
    );
  }
  for (final text in [
    '',
    'Meet at 18.30 for 2.5 hours; cost 12.50.',
    'alice@example.org',
    'garden.org@example.it',
    'www.example.com+garden@somewhere.org',
    'garden.com@localhost',
    '<alice+garden@sub.example.org>',
    'Contact alice@www.example.org, thanks.',
    '[Email](mailto:alice@example.org)',
    '1.2.3.4',
    'Read notes.txt or archive.zip, e.g. today.',
    'Bring tools and good ideas!',
    'https://',
    'www.',
    'example.organicunknown',
    'a' * 2000,
    '18.30 ' * 333,
    'a.' * 1000,
  ]) {
    test('ignore non-web text: ${text.length < 100 ? text : text.length}', () {
      expect(containsLikelyWebLink(text), isFalse);
    });
  }
}
