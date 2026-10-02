import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/application/auth_command_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_controllers.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/project_workspace/application/project_workspace_controller.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_chat.dart';
import '../../../support/fake_project_workspace.dart';

AccountSuspensionStatus activeStatus() => AccountSuspensionStatus.active(
  consequenceId: 'fb300000-0000-4000-8000-000000000001',
  appliedAt: DateTime.utc(2026, 10, 2),
  userReason: 'Synthetic subject reason',
);

void main() {
  test('bootstrap suspension precedes all profile reads/creation', () async {
    final auth = FakeAuthGateway()..suspension = activeStatus();
    final profile = FakeProfileAnchorGateway();
    final container = makeContainer(auth, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);
    await container
        .read(authSessionProvider.notifier)
        .bootstrap(const AuthIdentity(id: 'user-1'), ensureProfile: true);
    final state = container.read(authSessionProvider);
    expect(state.phase, AuthSessionPhase.suspended);
    expect(state.suspension?.userReason, 'Synthetic subject reason');
    expect(state.accountAccessIdentityId, isNull);
    expect(profile.ensureCount, 0);
    expect(profile.existsCount, 0);
  });

  test(
    'status failure fails closed and retry recovers ordinary readiness',
    () async {
      final auth = FakeAuthGateway()
        ..suspensionError = StateError('sensitive server detail');
      final profile = FakeProfileAnchorGateway()..exists = true;
      final container = makeContainer(auth, profile);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      final session = container.read(authSessionProvider.notifier);
      await session.bootstrap(const AuthIdentity(id: 'user-1'));
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.accountCheckFailed,
      );
      expect(profile.existsCount, 0);
      auth.suspensionError = null;
      await session.refresh();
      expect(container.read(authSessionProvider).phase, AuthSessionPhase.ready);
    },
  );

  test(
    'manual refresh still suspended then revoked returns to profile setup',
    () async {
      final auth = FakeAuthGateway()..suspension = activeStatus();
      final container = makeContainer(auth, FakeProfileAnchorGateway());
      addTearDown(container.dispose);
      addTearDown(auth.close);
      final session = container.read(authSessionProvider.notifier);
      await session.bootstrap(const AuthIdentity(id: 'user-1'));
      await session.refresh();
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.suspended,
      );
      auth.suspension = const AccountSuspensionStatus.inactive();
      await session.refresh();
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.profileSetupRequired,
      );
      expect(container.read(authSessionProvider).suspension, isNull);
    },
  );

  test(
    'late status completion cannot undo sign out or account switch',
    () async {
      final delay = Completer<void>();
      final auth = FakeAuthGateway()
        ..suspension = activeStatus()
        ..suspensionDelay = delay.future;
      final profile = FakeProfileAnchorGateway()..exists = true;
      final container = makeContainer(auth, profile);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      final session = container.read(authSessionProvider.notifier);
      final pending = session.bootstrap(const AuthIdentity(id: 'user-1'));
      session.markSignedOut();
      auth.suspensionDelay = null;
      auth.suspension = const AccountSuspensionStatus.inactive();
      await session.bootstrap(const AuthIdentity(id: 'user-2'));
      delay.complete();
      await pending;
      expect(container.read(authSessionProvider).phase, AuthSessionPhase.ready);
      expect(container.read(authSessionProvider).identity?.id, 'user-2');
      expect(container.read(authSessionProvider).suspension, isNull);
    },
  );

  test(
    'suspension closes existing private chat signals and discards cached state',
    () async {
      final auth = FakeAuthGateway();
      final profile = FakeProfileAnchorGateway()..exists = true;
      final chat = FakeProjectChatGateway()
        ..summaries = [projectChatSummaryFixture()];
      final container = makeContainer(auth, profile, chat: chat);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      final session = container.read(authSessionProvider.notifier);
      await session.bootstrap(const AuthIdentity(id: 'user-1'));
      final controller = container.read(projectChatListProvider.notifier);
      await controller.load('user-1');
      controller.startSignals('user-1');
      final subscription = chat.subscriptions.single;
      auth.suspension = activeStatus();
      await session.refresh();
      expect(subscription.isClosed, isTrue);
      expect(container.read(projectChatListProvider).items, isEmpty);
      expect(await controller.load('user-1'), isFalse);
    },
  );

  test(
    'OTP verification cannot create a suspended profile or mark it ready',
    () async {
      final auth = FakeAuthGateway()..suspension = activeStatus();
      final profile = FakeProfileAnchorGateway();
      final container = makeContainer(auth, profile);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      final commands = container.read(authCommandProvider.notifier);
      await commands.requestCode(email: 'suspension@planets.invalid');
      expect(await commands.verifyCode('123456'), isTrue);
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.suspended,
      );
      expect(profile.ensureCount, 0);
      await commands.signOut();
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.signedOut,
      );
      expect(container.read(authSessionProvider).suspension, isNull);
    },
  );

  test(
    'suspension discards workspace secrets and rejects late reads',
    () async {
      final auth = FakeAuthGateway();
      final pending = Completer<void>();
      final workspace = FakeProjectWorkspaceGateway()
        ..workspace = projectWorkspaceFixture();
      final container = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(
            FakeProfileAnchorGateway()..exists = true,
          ),
          projectWorkspaceGatewayProvider.overrideWithValue(workspace),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.close);
      final session = container.read(authSessionProvider.notifier);
      await session.bootstrap(const AuthIdentity(id: 'user-1'));
      final controller = container.read(projectWorkspaceProvider.notifier);
      await controller.load(
        expectedProfileId: 'user-1',
        projectId: 'proposal-1',
      );
      expect(container.read(projectWorkspaceProvider).workspace, isNotNull);
      workspace.readDelay = pending.future;
      final lateRead = controller.load(
        expectedProfileId: 'user-1',
        projectId: 'proposal-1',
      );
      auth.suspension = activeStatus();
      await session.refresh();
      pending.complete();
      await lateRead;
      expect(container.read(projectWorkspaceProvider).workspace, isNull);
      expect(
        container.read(projectWorkspaceProvider).expectedProfileId,
        isNull,
      );
    },
  );

  test('status decoder rejects extra private fields, malformed and success-shaped empty results', () {
    expect(
      AccountSuspensionStatus.fromJson({
        'is_suspended': false,
        'consequence_id': null,
        'applied_at': null,
        'user_reason': null,
      }).isSuspended,
      isFalse,
    );
    for (final row in <Map<String, dynamic>>[
      {},
      {'is_suspended': false},
      {
        'is_suspended': false,
        'consequence_id': 'private',
        'applied_at': null,
        'user_reason': null,
      },
      {
        'is_suspended': false,
        'consequence_id': null,
        'applied_at': null,
        'user_reason': null,
        'staff_note': 'private',
      },
    ]) {
      expect(
        () => AccountSuspensionStatus.fromJson(row),
        throwsFormatException,
      );
    }
    final active = AccountSuspensionStatus.fromJson({
      'is_suspended': true,
      'consequence_id': 'episode',
      'applied_at': '2026-10-02T12:00:00Z',
      'user_reason': 'Safe reason',
    });
    expect(active.userReason, 'Safe reason');
    // PostgreSQL char_length counts Unicode code points, not UTF-16 units.
    final unicodeReason = List.filled(2000, '🌍').join();
    expect(
      AccountSuspensionStatus.fromJson({
        'is_suspended': true,
        'consequence_id': 'episode',
        'applied_at': '2026-10-02T12:00:00Z',
        'user_reason': unicodeReason,
      }).userReason,
      unicodeReason,
    );
  });
}

ProviderContainer makeContainer(
  FakeAuthGateway auth,
  FakeProfileAnchorGateway profile, {
  FakeProjectChatGateway? chat,
}) => ProviderContainer(
  overrides: [
    authGatewayProvider.overrideWithValue(auth),
    profileAnchorGatewayProvider.overrideWithValue(profile),
    if (chat != null) projectChatGatewayProvider.overrideWithValue(chat),
  ],
);
