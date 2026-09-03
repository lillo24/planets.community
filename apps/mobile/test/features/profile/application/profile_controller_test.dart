import 'dart:async';

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
    'late profile load cannot overwrite the newly authenticated owner',
    () async {
      final oldLoad = Completer<ProfileEditorData>();
      final profile = FakeProfileGateway()
        ..loadResult = (id) => id == 'user-1'
            ? oldLoad.future
            : Future.value(
                profileFixture(id: id, complete: true, displayName: 'Jordan'),
              );
      final auth = FakeAuthGateway();
      final container = _container(auth, FakeProfileAnchorGateway(), profile);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      final session = container.read(authSessionProvider.notifier);
      session.markProfileReady(const AuthIdentity(id: 'user-1'));
      final controller = container.read(profileProvider.notifier);
      final loading = controller.load('user-1');
      session.markProfileReady(const AuthIdentity(id: 'user-2'));
      await controller.load('user-2');
      oldLoad.complete(profileFixture(complete: true));
      await loading;
      expect(container.read(profileProvider).data?.profile.id, 'user-2');
      expect(
        container.read(profileProvider).data?.profile.displayName,
        'Jordan',
      );
    },
  );

  test(
    'logout and re-login as the same ID still invalidate a pending save',
    () async {
      final pending = Completer<void>();
      final profile = FakeProfileGateway()..updateDelay = pending.future;
      final auth = FakeAuthGateway();
      final container = _container(auth, FakeProfileAnchorGateway(), profile);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      final session = container.read(authSessionProvider.notifier);
      const identity = AuthIdentity(id: 'user-1');
      session.markProfileSetupRequired(identity, hasProfileAnchor: true);
      final saving = container
          .read(profileProvider.notifier)
          .save(
            identity,
            ProfileUpdate(
              displayName: 'Casey',
              bio: '',
              selectedSkillIds: {},
              visibility: profile.data.profile.visibility,
            ),
          );
      session.markSignedOut();
      session.markProfileSetupRequired(identity, hasProfileAnchor: true);
      pending.complete();
      expect(await saving, isFalse);
      expect(profile.loadCount, 0);
      expect(container.read(profileProvider).data, isNull);
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.profileSetupRequired,
      );
    },
  );

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
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-1'));
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
