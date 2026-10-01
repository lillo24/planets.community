import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android claims only the HTTPS Project invite path', () async {
    final manifest = await File('android/app/src/main/AndroidManifest.xml')
        .readAsString();

    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, contains('android:host="planets.community"'));
    expect(manifest, contains('android:pathPrefix="/invite/project/"'));
    expect(manifest, isNot(contains('android:scheme="planets"')));
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
