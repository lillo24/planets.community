import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/router/native_project_links.dart';

void main() {
  const origin = 'https://planets.community';
  const id = 'fb040000-0000-4000-8000-000000000002';
  test('HTTPS allowlist keeps exact public routes and query multiplicity', () {
    expect(
      nativeProjectDestination(
        Uri.parse('https://planets.community:443/proposals/$id'),
      ),
      '/proposals/$id',
    );
    for (final family in ['proposals', 'tavoli']) {
      for (final query in ['', '?intent=join', '?intent=join&intent=join']) {
        final path = '/$family/$id$query';
        expect(nativeProjectDestination(Uri.parse('$origin$path')), path);
      }
    }
    for (final family in ['join', 'invite']) {
      final path = '/$family/project/${'A' * 43}';
      expect(nativeProjectDestination(Uri.parse('$origin$path')), path);
    }
  });
  test('unsafe or browser-only arrivals cannot enter app routes', () {
    for (final url in [
      'http://planets.community/proposals/$id',
      'https://other.example/proposals/$id',
      'https://www.planets.community/proposals/$id',
      'https://user@planets.community/proposals/$id',
      'https://planets.community:8443/proposals/$id',
      '//planets.community/proposals/$id',
      '$origin/proposals/$id#fragment',
      '$origin/proposals/$id/edit',
      '$origin/proposals/$id/join',
      '$origin/tavoli/$id/participant-links',
      '$origin/proposals/mine',
      '$origin/proposals/invalid',
      '$origin/proposals/${id.replaceFirst('-4000-', '-0000-')}',
      '$origin/join/project/${'A' * 40}/xx',
      '$origin/join/project/${'A' * 42}%2F',
      '$origin/join/project/${'A' * 42}%252F',
      '$origin/join/project/${'A' * 43}/',
      '$origin/join/project/${'A' * 43}?returnTo=/auth',
      '$origin/auth?returnTo=%2Fjoin%2Fproject%2F${'A' * 43}',
      '$origin/profile',
      '$origin/joined/proposals/$id',
      '$origin/admin',
      '$origin/.well-known/assetlinks.json',
      '$origin/',
    ]) {
      expect(
        nativeProjectDestination(Uri.parse(url)),
        isNull,
        reason: 'Rejected public arrival (value intentionally omitted)',
      );
    }
  });
}
