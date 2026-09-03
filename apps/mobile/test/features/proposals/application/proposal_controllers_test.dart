import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_proposal.dart';

void main() {
  test('public filters and cursor pagination are preserved', () async {
    final gateway = FakeProposalGateway()
      ..publicItems = [proposalSummaryFixture()];
    final container = ProviderContainer(
      overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);

    await container
        .read(publicProposalsProvider.notifier)
        .applyFilters(locality: ' Bologna ', skillIds: {'skill-mural'});
    expect(gateway.lastLocality, 'Bologna');
    expect(gateway.lastSkillIds, {'skill-mural'});
    await container.read(publicProposalsProvider.notifier).load(reset: false);
    expect(gateway.lastCursor?.id, 'proposal-1');
  });

  test(
    'create draft keeps Required/Useful selections and can publish',
    () async {
      final gateway = FakeProposalGateway();
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      await session.container
          .read(proposalEditorProvider.notifier)
          .load('user-1', null);

      final id = await session.container
          .read(proposalEditorProvider.notifier)
          .publish('user-1', proposalInputFixture());
      expect(id, 'new-draft');
      expect(
        gateway.calls,
        containsAllInOrder(['create', 'publish:new-draft']),
      );
      expect(
        gateway.lastInput?.skillImportanceById['skill-mural'],
        ProposalSkillImportance.required,
      );
    },
  );

  test('existing draft restores, updates and can cancel', () async {
    final gateway = FakeProposalGateway()..ownItems = [ownProposalFixture()];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    await session.container
        .read(proposalEditorProvider.notifier)
        .load('user-1', 'proposal-1');
    expect(
      session.container.read(proposalEditorProvider).proposal?.title,
      'Paint the square',
    );
    await session.container
        .read(proposalEditorProvider.notifier)
        .saveDraft('user-1', proposalInputFixture());
    await session.container
        .read(proposalEditorProvider.notifier)
        .cancel('user-1');
    expect(gateway.calls, contains('update:proposal-1'));
    expect(gateway.calls, contains('cancel:proposal-1'));
  });

  test('started published proposal is rejected before update', () async {
    final value = ownProposalFixture();
    final started = OwnProposal(
      id: value.id,
      lifecycle: ProposalLifecycle.published,
      title: value.title,
      summary: value.summary,
      description: value.description,
      startsAt: DateTime.utc(2026, 9, 1),
      endsAt: DateTime.utc(2026, 9, 2),
      eventTimezone: value.eventTimezone,
      countryCode: value.countryCode,
      locality: value.locality,
      administrativeArea: value.administrativeArea,
      publicLocationLabel: value.publicLocationLabel,
      status: ProposalStatus.completed,
      skills: value.skills,
      exactMeetingText: value.exactMeetingText,
      exactLocationVisibility: value.exactLocationVisibility,
      createdAt: value.createdAt,
      updatedAt: value.updatedAt,
      publishedAt: value.createdAt,
      cancelledAt: null,
    );
    final gateway = FakeProposalGateway()..ownItems = [started];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    await session.container
        .read(proposalEditorProvider.notifier)
        .load('user-1', started.id);
    await session.container
        .read(proposalEditorProvider.notifier)
        .saveDraft('user-1', proposalInputFixture());
    expect(gateway.calls, isNot(contains('update:proposal-1')));
    expect(
      session.container.read(proposalEditorProvider).failure,
      ProposalFailureKind.invalidState,
    );
  });

  test('stale account switch cannot issue an owner mutation', () async {
    final gateway = FakeProposalGateway()..ownItems = [ownProposalFixture()];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    await session.container
        .read(proposalEditorProvider.notifier)
        .load('user-1', 'proposal-1');
    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    final result = await session.container
        .read(proposalEditorProvider.notifier)
        .saveDraft('user-1', proposalInputFixture());
    expect(result, isNull);
    expect(gateway.calls, isNot(contains('update:proposal-1')));
    expect(
      session.container.read(proposalEditorProvider).failure,
      ProposalFailureKind.forbidden,
    );
  });

  test('incomplete profile cannot create a proposal', () async {
    final gateway = FakeProposalGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    await session.container
        .read(proposalEditorProvider.notifier)
        .load('user-1', null);
    session.container
        .read(authSessionProvider.notifier)
        .markProfileSetupRequired(
          const AuthIdentity(id: 'user-1'),
          hasProfileAnchor: true,
        );

    final result = await session.container
        .read(proposalEditorProvider.notifier)
        .saveDraft('user-1', proposalInputFixture());
    expect(result, isNull);
    expect(gateway.calls, isNot(contains('create')));
  });

  test('unsafe backend errors become safe failure state', () async {
    final gateway = FakeProposalGateway()
      ..error = StateError('private database detail');
    final container = ProviderContainer(
      overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    await container.read(publicProposalsProvider.notifier).load();
    expect(
      container.read(publicProposalsProvider).failure,
      ProposalFailureKind.unavailable,
    );
  });
}

({ProviderContainer container, FakeAuthGateway auth}) _readyContainer(
  FakeProposalGateway gateway,
) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      proposalGatewayProvider.overrideWithValue(gateway),
      proposalClockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 3)),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return (container: container, auth: auth);
}
