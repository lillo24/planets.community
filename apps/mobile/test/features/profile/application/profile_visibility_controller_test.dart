import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/application/profile_controller.dart';
import 'package:planets_mobile/features/profile/application/profile_visibility_controller.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/data/profile_visibility_gateway.dart';
import 'package:planets_mobile/features/profile/domain/profile_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_profile_visibility.dart';

void main() {
  late ProviderContainer container;
  late FakeProfileGateway profile;
  late FakeProfileVisibilityGateway gateway;
  late ProfileVisibilityController controller;
  late AuthSessionController session;
  setUp(() {
    final auth = FakeAuthGateway();
    addTearDown(auth.close);
    profile = FakeProfileGateway(data: profileFixture(complete: true));
    gateway = FakeProfileVisibilityGateway();
    container = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway(),
        ),
        profileGatewayProvider.overrideWithValue(profile),
        profileVisibilityGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    session = container.read(authSessionProvider.notifier);
    session.markProfileReady(const AuthIdentity(id: 'user-1'));
    controller = container.read(profileVisibilityProvider.notifier);
  });

  test(
    'canonical targeted saves preserve cached content and survive reopening',
    () async {
      await container.read(profileProvider.notifier).load('user-1');
      final before = container.read(profileProvider).data!.profile;
      expect(await controller.load('user-1'), isTrue);
      expect(container.read(profileVisibilityProvider).values, gateway.values);
      expect(
        await controller.select(
          'user-1',
          ProfileFieldKey.bio,
          ProfileAudience.private,
        ),
        isTrue,
      );
      expect(gateway.writes, [
        ('user-1', ProfileFieldKey.bio, ProfileAudience.private),
      ]);
      final after = container.read(profileProvider).data!.profile;
      expect(after.displayName, before.displayName);
      expect(after.bio, before.bio);
      expect(after.selectedSkillIds, before.selectedSkillIds);
      expect(after.visibility[ProfileFieldKey.bio], ProfileAudience.private);
      session.markSignedOut();
      expect(container.read(profileVisibilityProvider).values, isNull);
      session.markProfileReady(const AuthIdentity(id: 'user-1'));
      await controller.load('user-1');
      expect(
        container.read(profileVisibilityProvider).values![ProfileFieldKey.bio],
        ProfileAudience.private,
      );
    },
  );

  test(
    'write failure retains confirmed selection and does not report saved',
    () async {
      await controller.load('user-1');
      gateway.updateError = StateError('not authorized');
      expect(
        await controller.select(
          'user-1',
          ProfileFieldKey.bio,
          ProfileAudience.private,
        ),
        isFalse,
      );
      final state = container.read(profileVisibilityProvider);
      expect(state.values![ProfileFieldKey.bio], ProfileAudience.public);
      expect(state.failed, isTrue);
      expect(state.saved, isFalse);
      gateway.updateError = null;
      expect(
        await controller.select(
          'user-1',
          ProfileFieldKey.bio,
          ProfileAudience.private,
        ),
        isTrue,
      );
    },
  );

  test(
    'unconfirmed reread fails truthfully and retry loads committed value',
    () async {
      await controller.load('user-1');
      gateway.loadError = StateError('offline');
      expect(
        await controller.select(
          'user-1',
          ProfileFieldKey.bio,
          ProfileAudience.private,
        ),
        isFalse,
      );
      expect(container.read(profileVisibilityProvider).saved, isFalse);
      expect(
        container.read(profileVisibilityProvider).values![ProfileFieldKey.bio],
        ProfileAudience.public,
      );
      gateway.loadError = null;
      await controller.load('user-1');
      expect(
        container.read(profileVisibilityProvider).values![ProfileFieldKey.bio],
        ProfileAudience.private,
      );
    },
  );

  for (final write in [false, true]) {
    test(
      'A-B-A invalidates delayed ${write ? 'write' : 'load'} and concurrent actions',
      () async {
        final pending = Completer<void>();
        if (write) {
          await controller.load('user-1');
          gateway.onUpdate = () => pending.future;
        } else {
          gateway.onLoad = (_) async {
            await pending.future;
            return gateway.values;
          };
        }
        final work = write
            ? controller.select(
                'user-1',
                ProfileFieldKey.bio,
                ProfileAudience.private,
              )
            : controller.load('user-1');
        expect(await controller.load('user-1'), isFalse);
        session.markProfileReady(const AuthIdentity(id: 'user-2'));
        expect(container.read(profileVisibilityProvider).values, isNull);
        session.markProfileReady(const AuthIdentity(id: 'user-1'));
        pending.complete();
        expect(await work, isFalse);
        expect(container.read(profileVisibilityProvider).values, isNull);
        expect(container.read(profileVisibilityProvider).saved, isFalse);
        expect(await controller.load('user-2'), isFalse);
      },
    );
  }

  test(
    'new visibility wins over an older content response, including a cold read',
    () async {
      final pending = Completer<ProfileEditorData>();
      profile.loadResult = (_) => pending.future;
      final loading = container.read(profileProvider.notifier).load('user-1');
      await controller.load('user-1');
      await controller.select(
        'user-1',
        ProfileFieldKey.bio,
        ProfileAudience.private,
      );
      pending.complete(profileFixture(complete: true));
      await loading;
      expect(
        container.read(profileProvider).data!.profile.visibility,
        gateway.values,
      );
      profile.loadResult = null;
      // A content save never carries a visibility snapshot.
      await container
          .read(profileProvider.notifier)
          .save(
            const AuthIdentity(id: 'user-1'),
            const ProfileUpdate(
              displayName: 'New name',
              bio: 'New bio',
              selectedSkillIds: {'skill-mural'},
            ),
          );
      expect(profile.lastUpdate!.bio, 'New bio');
      expect(gateway.writes.length, 1);
    },
  );
}
