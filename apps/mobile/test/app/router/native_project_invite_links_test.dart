import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android effective filters bound both link and detail families', () async {
    // Also run against the actual Gradle merged debug manifest after APK build.
    final manifest = await File(
      Platform.environment['PLANETS_MERGED_MANIFEST'] ??
          'android/app/src/main/AndroidManifest.xml',
    ).readAsString();
    final filters = RegExp(r'<intent-filter\b[\s\S]*?</intent-filter>')
        .allMatches(manifest)
        .map((m) => m[0]!)
        .where((block) => block.contains('android.intent.action.VIEW'))
        .toList();
    expect(filters, hasLength(4));
    final patterns = <RegExp>[];
    for (final filter in filters) {
      expect(filter, contains('android:autoVerify="true"'));
      expect(RegExp(r'<data\b').allMatches(filter), hasLength(1));
      expect(filter, contains('android:scheme="https"'));
      expect(filter, contains('android:host="planets.community"'));
      expect(filter, contains('android.intent.category.BROWSABLE'));
      final pattern = RegExp(r'android:pathPattern="([^"]+)"')
          .firstMatch(filter)![1]!;
      // These deliberately use only literal '/', '-' and single '.' wildcards,
      // so full-match regex and Android's API-1 simple glob are equivalent.
      expect(pattern, matches(r'^[a-z/.-]+$'));
      patterns.add(RegExp('^$pattern\$'));
    }
    bool claimed(String path) => patterns.any((p) => p.hasMatch(path));
    const id = 'fb040000-0000-4000-8000-000000000002';
    for (final path in [
      '/invite/project/${'A' * 43}',
      '/join/project/${'A' * 43}',
      '/proposals/$id',
      '/tavoli/$id',
    ]) {
      expect(claimed(path), isTrue, reason: 'Public path family must match');
      expect(claimed('$path/edit'), isFalse);
      expect(claimed('$path/participant-links'), isFalse);
      expect(claimed('$path/'), isFalse);
    }
    for (final path in [
      '/',
      '/auth',
      '/profile',
      '/admin',
      '/api/waitlist',
      '/_next/static/app.js',
      '/joined/proposals/$id',
      '/proposals/create',
      '/proposals/mine',
      '/proposals/invalid',
      '/join/project/short',
    ]) {
      expect(
        claimed(path),
        isFalse,
        reason: 'Browser/private routes stay unclaimed',
      );
    }
    // Simple globs cannot reject every slash/alphabet at API 24. Pin the
    // unavoidable same-length overreach rather than claiming UUID validation.
    expect(claimed('/join/project/${'A' * 40}/xx'), isTrue);
  });

  test(
    'iOS enables the PLANETS associated domain in every build mode',
    () async {
      final entitlements = await File('ios/Runner/Runner.entitlements')
          .readAsString();
      final project = await File('ios/Runner.xcodeproj/project.pbxproj')
          .readAsString();

      expect(entitlements, contains('applinks:planets.community'));
      expect(
        RegExp(r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;')
            .allMatches(project),
        hasLength(3),
      );
    },
  );
}
