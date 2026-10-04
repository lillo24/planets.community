import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_delegates/application/project_delegate_controllers.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/project_participant_invites/application/participant_admission_controller.dart';
import 'package:planets_mobile/features/project_participant_invites/application/participant_admission_refresh.dart';
import 'package:planets_mobile/features/project_participant_invites/application/participant_link_manager.dart';
import 'package:planets_mobile/features/project_participant_invites/data/participant_invitation_gateway.dart';
import 'package:planets_mobile/features/project_participant_invites/domain/participant_invitation_models.dart';

import '../../support/fake_participant_invitation.dart';
import '../../support/fake_project_delegates.dart';

void main() {
  late FakeParticipantInvitationGateway gateway;
  late FakeProjectDelegateGateway delegates;
  late ProviderContainer container;
  var ids = 0;
  var refreshes = 0;
  var read = const ParticipantParticipationRead(loaded: true, current: true);
  Object? refreshError;
  final token = 'A' * 43;
  setUp(() {
    ids = 0;
    refreshes = 0;
    refreshError = null;
    read = const ParticipantParticipationRead(loaded: true, current: true);
    gateway = FakeParticipantInvitationGateway();
    delegates = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.creator;
    container = ProviderContainer(
      overrides: [
        participantInvitationGatewayProvider.overrideWithValue(gateway),
        projectDelegateGatewayProvider.overrideWithValue(delegates),
        participantActionIdProvider.overrideWithValue(() => 'action-${++ids}'),
        participantAdmissionRefreshProvider.overrideWithValue((
          account,
          project,
          kind,
        ) async {
          refreshes++;
          expect(account, container.read(authSessionProvider).identity?.id);
          expect(project, 'project-1');
          if (refreshError case final error?) throw error;
          return read;
        }),
      ],
    );
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-1'));
  });
  tearDown(() => container.dispose());
  ParticipantAdmissionController admission() =>
      container.read(participantAdmissionProvider.notifier);
  ParticipantLinkManager manager() =>
      container.read(participantLinkManagerProvider.notifier);
  ParticipantAdmissionState state() =>
      container.read(participantAdmissionProvider);

  test(
    'opening, refreshing and restoring do not generate an action or join',
    () async {
      await admission().load(token);
      await admission().load(token);
      container
          .read(authSessionProvider.notifier)
          .markCheckingProfile(const AuthIdentity(id: 'user-1'));
      await admission().join('user-1');
      expect(ids, 0);
      expect(gateway.admissions, isEmpty);
    },
  );
  test(
    'explicit click creates one action, double click is suppressed',
    () async {
      final delay = Completer<void>();
      gateway.acceptDelay = delay.future;
      await admission().load(token);
      final pending = admission().join('user-1');
      await admission().join('user-1');
      expect(ids, 1);
      expect(gateway.admissions.length, 1);
      delay.complete();
      await pending;
      expect(state().currentMember, isTrue);
      expect(refreshes, 1);
      await admission().join('user-1');
      expect(gateway.admissions.length, 1);
    },
  );
  test(
    'lost response, navigation and false preview retain original receipt tuple',
    () async {
      gateway.acceptError = StateError('connection lost');
      await admission().load(token);
      await admission().join('user-1');
      final tuple = gateway.admissions.single;
      await admission().load('B' * 43);
      gateway.previewValue = const ParticipantInvitePreview(available: false);
      await admission().load(token);
      expect(state().hasAttempt, isTrue);
      expect(state().preview!.available, isFalse);
      gateway.acceptError = null;
      await admission().join('user-1');
      expect(gateway.admissions.last, tuple);
      expect(ids, 1);
      expect(state().currentMember, isTrue);
    },
  );
  test(
    'account switch clears pending action and ignores late result',
    () async {
      final delay = Completer<void>();
      gateway.acceptDelay = delay.future;
      await admission().load(token);
      final pending = admission().join('user-1');
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      await admission().load(token);
      delay.complete();
      await pending;
      expect(state().account, 'user-2');
      expect(state().result, isNull);
      expect(state().hasAttempt, isFalse);
      gateway.acceptDelay = null;
      await admission().join('user-2');
      expect(gateway.admissions.last.account, 'user-2');
      expect(ids, 2);
    },
  );
  test(
    'logout destroys retry identity even when same account returns',
    () async {
      gateway.acceptError = StateError('connection lost');
      await admission().load(token);
      await admission().join('user-1');
      container.read(authSessionProvider.notifier).markSignedOut();
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-1'));
      await admission().load(token);
      expect(state().hasAttempt, isFalse);
      await admission().join('user-1');
      expect(ids, 2);
    },
  );
  test(
    'late result cannot replace another token; old attempt remains recoverable',
    () async {
      final delay = Completer<void>();
      gateway.acceptDelay = delay.future;
      await admission().load(token);
      final pending = admission().join('user-1');
      await admission().load('B' * 43);
      delay.complete();
      await pending;
      expect(state().token, 'B' * 43);
      expect(state().result, isNull);
      await admission().load(token);
      gateway.acceptDelay = null;
      await admission().join('user-1');
      expect(gateway.admissions.last, gateway.admissions.first);
      expect(ids, 1);
    },
  );
  for (final status in [MembershipStatus.left, MembershipStatus.removed]) {
    test(
      'historical $status receipt requires deliberate new re-entry',
      () async {
        gateway.receipt = ParticipantAdmissionResult(
          projectId: 'project-1',
          membershipId: 'member-1',
          outcome: ParticipantAdmissionOutcome.joined,
          status: status,
          replayed: true,
        );
        read = const ParticipantParticipationRead(loaded: true);
        await admission().load(token);
        await admission().join('user-1');
        await admission().load(token);
        await admission().refreshParticipation();
        await admission().join('user-1');
        expect(ids, 1);
        expect(state().currentMember, isFalse);
        await admission().join('user-1', reenter: true);
        expect(ids, 2);
        expect(gateway.admissions.last.action, 'action-2');
      },
    );
  }
  test(
    'historical receipt with newer current membership never offers re-entry',
    () async {
      gateway.receipt = const ParticipantAdmissionResult(
        projectId: 'project-1',
        membershipId: 'old-member',
        outcome: ParticipantAdmissionOutcome.joined,
        status: MembershipStatus.left,
        replayed: true,
      );
      await admission().load(token);
      await admission().join('user-1');
      await admission().join('user-1', reenter: true);
      expect(state().currentMember, isTrue);
      expect(ids, 1);
    },
  );
  test('unavailable current link cannot admit a new re-entry', () async {
    read = const ParticipantParticipationRead(loaded: true);
    await admission().load(token);
    await admission().join('user-1');
    gateway.previewValue = const ParticipantInvitePreview(available: false);
    await admission().load(token);
    await admission().join('user-1', reenter: true);
    expect(ids, 1);
  });
  for (final outcome in [
    ParticipantAdmissionOutcome.creator,
    ParticipantAdmissionOutcome.alreadyJoined,
  ]) {
    test(
      '$outcome receipt is retained without a duplicate admission',
      () async {
        gateway.receipt = ParticipantAdmissionResult(
          projectId: 'project-1',
          membershipId: outcome == ParticipantAdmissionOutcome.creator
              ? null
              : 'member-1',
          outcome: outcome,
          status: outcome == ParticipantAdmissionOutcome.creator
              ? null
              : MembershipStatus.current,
          replayed: false,
        );
        await admission().load(token);
        await admission().join('user-1');
        await admission().load(token);
        await admission().join('user-1', reenter: true);
        expect(gateway.admissions.length, 1);
        expect(state().result!.outcome, outcome);
      },
    );
  }
  test(
    'failed post-admission read retries only reads and cannot re-enter',
    () async {
      refreshError = StateError('read unavailable');
      await admission().load(token);
      await admission().join('user-1');
      expect(state().result, isNotNull);
      expect(state().participationLoaded, isFalse);
      await admission().join('user-1', reenter: true);
      refreshError = null;
      await admission().refreshParticipation();
      expect(state().currentMember, isTrue);
      expect(gateway.admissions.length, 1);
    },
  );
  test('disposed acceptance cannot publish or refresh', () async {
    final delay = Completer<void>();
    gateway.acceptDelay = delay.future;
    await admission().load(token);
    final pending = admission().join('user-1');
    container.dispose();
    container = ProviderContainer();
    delay.complete();
    await pending;
    expect(refreshes, 0);
  });
  test('malformed token is locally unavailable; network and parse errors remain distinct', () async {
    await admission().load('not-a-token');
    expect(gateway.calls, isEmpty);
    expect(state().preview!.available, isFalse);
    gateway.previewError = StateError('offline');
    await admission().load(token);
    expect(state().failure, ParticipantInviteFailure.network);
    gateway.previewError = const FormatException('malformed response');
    await admission().load(token);
    expect(state().failure, ParticipantInviteFailure.malformed);
    expect(state().toString(), isNot(contains(token)));
  });
  for (final role in [
    ProjectManagementRole.creator,
    ProjectManagementRole.coCreator,
    ProjectManagementRole.coOrganizer,
  ]) {
    test('$role retrieves and reshares without rotating', () async {
      delegates.role = role;
      await manager().mutate(
        'user-1',
        'project-1',
        ProjectKind.oneTime,
        ParticipantLinkOperation.create,
      );
      final first = await manager().forSharing(
        'user-1',
        'project-1',
        ProjectKind.oneTime,
      );
      final second = await manager().forSharing(
        'user-1',
        'project-1',
        ProjectKind.oneTime,
      );
      expect(first!.token, second!.token);
      expect(gateway.calls.where((s) => s.startsWith('regenerate')), isEmpty);
      expect(container.read(participantLinkManagerProvider).role, role);
    });
  }
  test('outsider cannot retrieve or create; role loss clears secret', () async {
    await manager().load('user-1', 'project-1', ProjectKind.oneTime);
    delegates.role = ProjectManagementRole.none;
    expect(
      await manager().forSharing('user-1', 'project-1', ProjectKind.oneTime),
      isNull,
    );
    expect(container.read(participantLinkManagerProvider).link, isNull);
    expect(
      container.read(participantLinkManagerProvider).failure,
      ParticipantInviteFailure.forbidden,
    );
    await manager().mutate(
      'user-1',
      'project-1',
      ProjectKind.oneTime,
      ParticipantLinkOperation.create,
    );
    expect(gateway.calls.where((s) => s.startsWith('create')), isEmpty);
  });
  test('known canonical role loss invalidates manager state', () async {
    await manager().load('user-1', 'project-1', ProjectKind.oneTime);
    delegates.role = ProjectManagementRole.none;
    await container
        .read(projectManagementRoleProvider.notifier)
        .load(
          expectedProfileId: 'user-1',
          projectId: 'project-1',
          projectKind: ProjectKind.oneTime,
        );
    expect(container.read(participantLinkManagerProvider).link, isNull);
  });
  test('uncertain rotation retrieves committed generation without repeating mutation', () async {
    await manager().load('user-1', 'project-1', ProjectKind.oneTime);
    gateway.mutationError = StateError('lost response after commit');
    await manager().mutate(
      'user-1',
      'project-1',
      ProjectKind.oneTime,
      ParticipantLinkOperation.regenerate,
    );
    final value = container.read(participantLinkManagerProvider);
    expect(value.link!.id, 'link-2');
    expect(value.ready, isTrue);
    expect(value.failure, ParticipantInviteFailure.network);
    expect(gateway.calls.where((s) => s.startsWith('regenerate')).length, 1);
  });
  test('stale revoke passes displayed id and refreshes replacement without revoking it', () async {
    await manager().load('user-1', 'project-1', ProjectKind.oneTime);
    gateway.link = ParticipantLink(
      id: 'link-2',
      token: 'B' * 43,
      createdAt: DateTime.utc(2030),
    );
    gateway.mutationError = const PostgrestException(
      message: 'Unavailable',
      code: 'PT409',
    );
    await manager().mutate(
      'user-1',
      'project-1',
      ProjectKind.oneTime,
      ParticipantLinkOperation.revoke,
      displayedInvitationId: 'link-1',
    );
    expect(container.read(participantLinkManagerProvider).link!.id, 'link-2');
    expect(gateway.calls.where((s) => s.startsWith('revoke')).toList(), [
      'revoke:user-1:project-1:link-1',
    ]);
    await manager().mutate(
      'user-1',
      'project-1',
      ProjectKind.oneTime,
      ParticipantLinkOperation.revoke,
      displayedInvitationId: 'link-1',
    );
    expect(gateway.calls.where((s) => s.startsWith('revoke')).length, 1);
  });
  test(
    'unconfirmed canonical state disables subsequent destructive action',
    () async {
      await manager().load('user-1', 'project-1', ProjectKind.oneTime);
      gateway.readError = StateError('offline');
      await manager().mutate(
        'user-1',
        'project-1',
        ProjectKind.oneTime,
        ParticipantLinkOperation.regenerate,
      );
      await manager().mutate(
        'user-1',
        'project-1',
        ProjectKind.oneTime,
        ParticipantLinkOperation.regenerate,
      );
      expect(container.read(participantLinkManagerProvider).ready, isFalse);
      expect(container.read(participantLinkManagerProvider).link, isNull);
      expect(gateway.calls.where((s) => s.startsWith('regenerate')).length, 1);
    },
  );
  test(
    'history uses last metadata row cursor and accumulates bounded pages',
    () async {
      gateway.rows = List.generate(
        20,
        (i) => ParticipantLinkHistory(
          id: 'row-$i',
          issuerId: 'user-1',
          createdAt: DateTime.utc(2030, 1, 20 - i),
        ),
      );
      await manager().load('user-1', 'project-1', ProjectKind.oneTime);
      final last = gateway.rows.last;
      gateway.rows = [
        ParticipantLinkHistory(
          id: 'older',
          issuerId: 'user-1',
          createdAt: DateTime.utc(2029),
        ),
      ];
      await manager().load(
        'user-1',
        'project-1',
        ProjectKind.oneTime,
        more: true,
      );
      expect(gateway.cursor, last);
      expect(container.read(participantLinkManagerProvider).history.length, 21);
      expect(container.read(participantLinkManagerProvider).hasMore, isFalse);
    },
  );
  test('account and project changes discard late management secrets', () async {
    final delay = Completer<void>();
    gateway.readDelay = delay.future;
    final pending = manager().load('user-1', 'project-1', ProjectKind.oneTime);
    await Future<void>.delayed(Duration.zero);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    delay.complete();
    await pending;
    expect(container.read(participantLinkManagerProvider).link, isNull);
    gateway.readDelay = null;
    await manager().load('user-2', 'project-2', ProjectKind.recurring);
    expect(
      container.read(participantLinkManagerProvider).projectId,
      'project-2',
    );
    expect(
      container.read(participantLinkManagerProvider).toString(),
      isNot(contains(token)),
    );
  });
}
