import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile_photo/application/profile_photo_requirement.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';

import '../../../support/fake_profile_photo.dart';

void main() {
  test('current canonical owner photo satisfies the trust preflight', () async {
    final harness = RequirementHarness()..gateway.photo = profilePhotoFixture();
    addTearDown(harness.dispose);

    expect(
      await harness.requirement.check('user-1'),
      ProfilePhotoRequirementStatus.satisfied,
    );
  });

  test('successful empty owner read is the only missing result', () async {
    final harness = RequirementHarness();
    addTearDown(harness.dispose);

    expect(
      await harness.requirement.check('user-1'),
      ProfilePhotoRequirementStatus.missing,
    );
  });

  test(
    'read failure and identity mismatch defer to backend enforcement',
    () async {
      final harness = RequirementHarness()
        ..gateway.loadError = StateError('offline');
      addTearDown(harness.dispose);

      expect(
        await harness.requirement.check('user-1'),
        ProfilePhotoRequirementStatus.unavailable,
      );
      expect(
        await harness.requirement.check('user-2'),
        ProfilePhotoRequirementStatus.unavailable,
      );
    },
  );
}

class RequirementHarness {
  final gateway = FakeProfilePhotoGateway();
  late final ProviderContainer container =
      ProviderContainer(
          overrides: [profilePhotoGatewayProvider.overrideWithValue(gateway)],
        )
        ..read(authSessionProvider.notifier)
            .markProfileReady(const AuthIdentity(id: 'user-1'));

  ProfilePhotoRequirement get requirement =>
      container.read(profilePhotoRequirementProvider);

  void dispose() => container.dispose();
}
