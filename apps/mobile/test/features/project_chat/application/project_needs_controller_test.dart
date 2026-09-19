import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_refresh.dart';
import 'package:planets_mobile/features/project_chat/application/project_needs_controller.dart';
import 'package:planets_mobile/features/project_chat/data/project_needs_gateway.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_needs.dart';

void main() {
  test('current member loads coverage and attention independently', () async {
    final gateway = FakeProjectNeedsGateway()
      ..requirements = [projectRequirementFixture()]
      ..attention = projectAttentionFixture(hasUnseen: true);
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    expect(await _load(session.container), isTrue);
    final state = session.container.read(projectNeedsProvider);
    expect(state.coveragePhase, ProjectNeedsPhase.ready);
    expect(state.attentionPhase, ProjectNeedsPhase.ready);
    expect(state.uncoveredCount, 1);
    expect(state.hasUnseenAttention, isTrue);
    expect(
      gateway.calls,
      containsAll(['coverage:proposal-1', 'attention:proposal-1']),
    );
  });

  test('former member clears state without calling live RPCs', () async {
    final gateway = FakeProjectNeedsGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    final loaded = await session.container
        .read(projectNeedsProvider.notifier)
        .load(
          expectedProfileId: 'user-1',
          projectId: 'proposal-1',
          chatId: 'chat-1',
          viewerRole: ProjectChatViewerRole.formerMember,
        );

    expect(loaded, isFalse);
    expect(gateway.calls, isEmpty);
    expect(session.container.read(projectNeedsProvider).hasTarget, isFalse);
  });

  test('attention failure does not discard successful coverage', () async {
    final gateway = FakeProjectNeedsGateway()
      ..requirements = [projectRequirementFixture()]
      ..attentionError = StateError('private diagnostic');
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    expect(await _load(session.container), isFalse);
    final state = session.container.read(projectNeedsProvider);
    expect(state.coveragePhase, ProjectNeedsPhase.ready);
    expect(state.requirements, hasLength(1));
    expect(state.attentionPhase, ProjectNeedsPhase.failure);
  });

  test(
    'attention pulse revision advances once for a false-to-true transition',
    () async {
      final gateway = FakeProjectNeedsGateway();
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      await _load(session.container);
      final controller = session.container.read(projectNeedsProvider.notifier);

      gateway.attention = projectAttentionFixture(hasUnseen: true);
      await controller.refresh(allowAttentionPulse: true);
      expect(
        session.container.read(projectNeedsProvider).attentionPulseRevision,
        1,
      );

      await controller.refresh(allowAttentionPulse: true);
      expect(
        session.container.read(projectNeedsProvider).attentionPulseRevision,
        1,
      );
    },
  );

  test('participant claim reloads canonical coverage', () async {
    final gateway = FakeProjectNeedsGateway()
      ..requirements = [projectRequirementFixture()];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await _load(session.container);
    final refreshRevision = session.container.read(projectChatRefreshProvider);

    final requirement = session.container
        .read(projectNeedsProvider)
        .requirements
        .single;
    expect(
      await session.container
          .read(projectNeedsProvider.notifier)
          .claim(requirement),
      isTrue,
    );

    final state = session.container.read(projectNeedsProvider);
    expect(state.uncoveredCount, 0);
    expect(gateway.calls, contains('claim:skill:skill-1'));
    expect(
      session.container.read(projectChatRefreshProvider),
      refreshRevision + 1,
    );
  });

  test(
    'PT409 and 22023 recover through canonical reload without retry',
    () async {
      for (final entry in const [
        ('PT409', ProjectNeedsNotice.coveredElsewhere),
        ('22023', ProjectNeedsNotice.requirementChanged),
      ]) {
        final gateway = FakeProjectNeedsGateway()
          ..requirements = [projectRequirementFixture()]
          ..actionError = PostgrestException(
            message: 'private diagnostic',
            code: entry.$1,
          );
        final session = _readyContainer(gateway);
        await _load(session.container);
        final requirement = session.container
            .read(projectNeedsProvider)
            .requirements
            .single;

        expect(
          await session.container
              .read(projectNeedsProvider.notifier)
              .claim(requirement),
          isFalse,
        );
        expect(session.container.read(projectNeedsProvider).notice, entry.$2);
        expect(
          gateway.calls.where((call) => call.startsWith('claim:')),
          hasLength(1),
        );
        expect(
          gateway.calls.where((call) => call == 'coverage:proposal-1').length,
          2,
        );
        session.dispose();
      }
    },
  );

  test('40001 is not treated as the application claim conflict', () async {
    final gateway = FakeProjectNeedsGateway()
      ..requirements = [projectRequirementFixture()]
      ..actionError = const PostgrestException(
        message: 'genuine serialization failure',
        code: '40001',
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await _load(session.container);
    final requirement = session.container
        .read(projectNeedsProvider)
        .requirements
        .single;

    expect(
      await session.container
          .read(projectNeedsProvider.notifier)
          .claim(requirement),
      isFalse,
    );
    final state = session.container.read(projectNeedsProvider);
    expect(state.notice, isNull);
    expect(state.failure, ProjectNeedsFailureKind.unavailable);
    expect(
      gateway.calls.where((call) => call.startsWith('claim:')),
      hasLength(1),
    );
    expect(
      gateway.calls.where((call) => call == 'coverage:proposal-1'),
      hasLength(1),
    );
  });

  test('creator can set and clear only manual coverage', () async {
    final gateway = FakeProjectNeedsGateway()
      ..requirements = [projectRequirementFixture()];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await _load(session.container, role: ProjectChatViewerRole.creator);
    var requirement = session.container
        .read(projectNeedsProvider)
        .requirements
        .single;

    expect(
      await session.container
          .read(projectNeedsProvider.notifier)
          .setManualCoverage(requirement, true),
      isTrue,
    );
    requirement = session.container
        .read(projectNeedsProvider)
        .requirements
        .single;
    expect(requirement.isManuallyCovered, isTrue);
    expect(
      await session.container
          .read(projectNeedsProvider.notifier)
          .setManualCoverage(requirement, false),
      isTrue,
    );
    expect(session.container.read(projectNeedsProvider).uncoveredCount, 1);
  });

  test(
    'acknowledges the rendered explicit frontier and preserves newer B',
    () async {
      final acknowledgement = Completer<void>();
      final gateway = FakeProjectNeedsGateway()
        ..requirements = [projectRequirementFixture()]
        ..attention = projectAttentionFixture(
          hasUnseen: true,
          eventId: 'event-A',
        )
        ..acknowledgeDelay = acknowledgement.future;
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      await _load(session.container);
      await session.container
          .read(projectNeedsProvider.notifier)
          .openDrawerAndRefresh();

      final pending = session.container
          .read(projectNeedsProvider.notifier)
          .acknowledgeVisible('event-A');
      gateway.attention = projectAttentionFixture(
        hasUnseen: true,
        eventId: 'event-B',
      );
      acknowledgement.complete();

      expect(await pending, isTrue);
      expect(gateway.acknowledgedEventId, 'event-A');
      expect(
        session.container
            .read(projectNeedsProvider)
            .attention
            ?.latestUnseenEventId,
        'event-B',
      );
      expect(gateway.calls, isNot(contains('ack:event-B')));
    },
  );

  test('failed coverage means acknowledgement is not allowed', () async {
    final gateway = FakeProjectNeedsGateway()
      ..coverageError = StateError('offline')
      ..attention = projectAttentionFixture(hasUnseen: true);
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await _load(session.container);
    await session.container
        .read(projectNeedsProvider.notifier)
        .openDrawerAndRefresh();

    expect(
      await session.container
          .read(projectNeedsProvider.notifier)
          .acknowledgeVisible('event-1'),
      isFalse,
    );
    expect(gateway.calls.where((call) => call.startsWith('ack:')), isEmpty);
  });

  test('acknowledgement failure keeps unseen attention retryable', () async {
    final gateway = FakeProjectNeedsGateway()
      ..attention = projectAttentionFixture(hasUnseen: true)
      ..acknowledgeError = StateError('offline');
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await _load(session.container);
    await session.container
        .read(projectNeedsProvider.notifier)
        .openDrawerAndRefresh();

    expect(
      await session.container
          .read(projectNeedsProvider.notifier)
          .acknowledgeVisible('event-1'),
      isFalse,
    );
    final state = session.container.read(projectNeedsProvider);
    expect(state.hasUnseenAttention, isTrue);
    expect(state.attentionPhase, ProjectNeedsPhase.failure);
  });

  test('attention false never sends an acknowledgement mutation', () async {
    final gateway = FakeProjectNeedsGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await _load(session.container);
    await session.container
        .read(projectNeedsProvider.notifier)
        .openDrawerAndRefresh();

    expect(
      await session.container
          .read(projectNeedsProvider.notifier)
          .acknowledgeVisible('event-1'),
      isFalse,
    );
    expect(gateway.calls.where((call) => call.startsWith('ack:')), isEmpty);
  });

  test('lifecycle and authorization SQLSTATEs map to safe states', () {
    expect(
      mapProjectNeedsFailure(
        const PostgrestException(message: 'private', code: '42501'),
      ),
      ProjectNeedsFailureKind.forbidden,
    );
    expect(
      mapProjectNeedsFailure(
        const PostgrestException(message: 'private', code: '55000'),
      ),
      ProjectNeedsFailureKind.lifecycleEnded,
    );
    expect(
      mapProjectNeedsFailure(
        const PostgrestException(message: 'private', code: 'P0002'),
      ),
      ProjectNeedsFailureKind.notFound,
    );
  });

  test('account switch clears state and rejects late coverage', () async {
    final delay = Completer<void>();
    final gateway = FakeProjectNeedsGateway()..coverageDelay = delay.future;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final loading = _load(session.container);

    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    delay.complete();

    expect(await loading, isFalse);
    expect(session.container.read(projectNeedsProvider).hasTarget, isFalse);
  });
}

Future<bool> _load(
  ProviderContainer container, {
  ProjectChatViewerRole role = ProjectChatViewerRole.currentMember,
}) => container
    .read(projectNeedsProvider.notifier)
    .load(
      expectedProfileId: 'user-1',
      projectId: 'proposal-1',
      chatId: 'chat-1',
      viewerRole: role,
    );

class _TestSession {
  _TestSession(this.container, this.auth);

  final ProviderContainer container;
  final FakeAuthGateway auth;

  void dispose() {
    container.dispose();
    auth.close();
  }
}

_TestSession _readyContainer(FakeProjectNeedsGateway gateway) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      projectNeedsGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return _TestSession(container, auth);
}
