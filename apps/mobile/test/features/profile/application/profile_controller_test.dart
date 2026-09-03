import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/application/profile_controller.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/domain/profile_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';

void main() {
  test(
    'valid save completes the profile through the canonical gateway',
    () async {
      final auth = FakeAuthGateway();
      final anchor = FakeProfileAnchorGateway();
      final profile = FakeProfileGateway();
      final container = _container(auth, anchor, profile);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      const identity = AuthIdentity(id: 'user-1');
      container
          .read(authSessionProvider.notifier)
          .markProfileSetupRequired(identity, hasProfileAnchor: true);
      await container.read(profileProvider.notifier).load(identity.id);

      final saved = await container
          .read(profileProvider.notifier)
          .save(
            identity,
            const ProfileUpdate(
              displayName: 'Casey',
              bio: '',
              selectedSkillIds: {'skill-mural'},
              visibility: {
                ProfileFieldKey.displayName: ProfileAudience.public,
                ProfileFieldKey.bio: ProfileAudience.private,
                ProfileFieldKey.skills: ProfileAudience.public,
              },
            ),
          );

      expect(saved, isTrue);
      expect(profile.updateCount, 1);
      expect(profile.lastExpectedProfileId, identity.id);
      expect(profile.loadCount, 2);
      expect(
        container.read(profileProvider).data?.profile.displayName,
        'Casey',
      );
      expect(container.read(profileProvider).data?.profile.bio, isNull);
      expect(container.read(authSessionProvider).phase, AuthSessionPhase.ready);
    },
  );

  test('invalid fields never reach the gateway', () async {
    final auth = FakeAuthGateway();
    final anchor = FakeProfileAnchorGateway();
    final profile = FakeProfileGateway();
    final container = _container(auth, anchor, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);

    final saved = await container
        .read(profileProvider.notifier)
        .save(
          const AuthIdentity(id: 'user-1'),
          const ProfileUpdate(
            displayName: 'X',
            bio: '',
            selectedSkillIds: {},
            visibility: {
              ProfileFieldKey.displayName: ProfileAudience.public,
              ProfileFieldKey.bio: ProfileAudience.public,
              ProfileFieldKey.skills: ProfileAudience.public,
            },
          ),
        );

    expect(saved, isFalse);
    expect(profile.updateCount, 0);
    expect(
      container.read(profileProvider).failure,
      ProfileFailureKind.invalidInput,
    );
  });

  test('backend details become a safe retryable failure', () async {
    final auth = FakeAuthGateway();
    final anchor = FakeProfileAnchorGateway();
    final profile = FakeProfileGateway()
      ..updateError = StateError('private backend diagnostics');
    final container = _container(auth, anchor, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);
    await container.read(profileProvider.notifier).load('user-1');

    final saved = await container
        .read(profileProvider.notifier)
        .save(
          const AuthIdentity(id: 'user-1'),
          const ProfileUpdate(
            displayName: 'Casey',
            bio: '',
            selectedSkillIds: {},
            visibility: {
              ProfileFieldKey.displayName: ProfileAudience.public,
              ProfileFieldKey.bio: ProfileAudience.public,
              ProfileFieldKey.skills: ProfileAudience.public,
            },
          ),
        );

    expect(saved, isFalse);
    expect(
      container.read(profileProvider).failure,
      ProfileFailureKind.unavailable,
    );
    expect(container.read(profileProvider).data, isNotNull);
  });
}

ProviderContainer _container(
  FakeAuthGateway auth,
  FakeProfileAnchorGateway anchor,
  FakeProfileGateway profile,
) {
  return ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(anchor),
      profileGatewayProvider.overrideWithValue(profile),
    ],
  );
}
