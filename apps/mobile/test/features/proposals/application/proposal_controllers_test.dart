import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/cover_media/application/project_cover_reconciler.dart';
import 'package:planets_mobile/features/cover_media/domain/cover_media_models.dart';
import 'package:planets_mobile/features/participation/application/participation_controllers.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_cover_media.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_proposal.dart';

void main() {
  test(
    'account switch invalidates pending editor and owner list loads',
    () async {
      final own = Completer<OwnProposal?>();
      final list = Completer<List<OwnProposal>>();
      final gateway = FakeProposalGateway()
        ..ownResult = own.future
        ..ownListResult = list.future;
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final editorLoad = session.container
          .read(proposalEditorProvider.notifier)
          .load('user-1', 'proposal-1');
      final listLoad = session.container
          .read(ownProposalsProvider.notifier)
          .load('user-1');
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      own.complete(ownProposalFixture());
      list.complete([ownProposalFixture()]);
      await Future.wait([editorLoad, listLoad]);
      expect(session.container.read(proposalEditorProvider).proposal, isNull);
      expect(session.container.read(ownProposalsProvider).items, isEmpty);
      expect(
        session.container.read(proposalEditorProvider).expectedCreatorId,
        isNull,
      );
    },
  );

  test(
    'logout during draft creation prevents follow-up publish and stale results',
    () async {
      final pending = Completer<void>();
      final gateway = FakeProposalGateway()..mutationDelay = pending.future;
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        proposalEditorProvider.notifier,
      );
      await controller.load('user-1', null);
      final saving = controller.publish('user-1', proposalInputFixture());
      session.container.read(authSessionProvider.notifier).markSignedOut();
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-1'));
      pending.complete();
      expect(await saving, isNull);
      expect(gateway.calls, isNot(contains('publish:new-draft')));
      expect(session.container.read(proposalEditorProvider).proposal, isNull);
    },
  );

  for (final command in ['publish', 'cancel', 'edit', 'editor-cancel']) {
    test('account switch rejects late $command completion', () async {
      final pending = Completer<void>();
      final gateway = FakeProposalGateway()..ownItems = [ownProposalFixture()];
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final editor = session.container.read(proposalEditorProvider.notifier);
      final owner = session.container.read(ownProposalsProvider.notifier);
      await editor.load('user-1', 'proposal-1');
      await owner.load('user-1');
      gateway.mutationDelay = pending.future;
      final Future<Object?> mutation = switch (command) {
        'publish' => owner.publish('user-1', 'proposal-1'),
        'cancel' => owner.cancel('user-1', 'proposal-1'),
        'edit' => editor.saveDraft('user-1', proposalInputFixture()),
        _ => editor.cancel('user-1'),
      };
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      pending.complete();
      expect(await mutation, command == 'edit' ? isNull : isFalse);
      expect(session.container.read(proposalEditorProvider).proposal, isNull);
      expect(session.container.read(ownProposalsProvider).items, isEmpty);
    });
  }

  test('public filters and cursor pagination are preserved', () async {
    final gateway = FakeProposalGateway()
      ..publicItems = [proposalSummaryFixture()];
    final container = ProviderContainer(
      overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);

    await container
        .read(publicProposalsProvider.notifier)
        .applyFilters(
          query: ' mural ',
          locality: ' Bologna ',
          skillIds: {'skill-mural'},
        );
    expect(gateway.lastQuery, 'mural');
    expect(gateway.lastLocality, 'Bologna');
    expect(gateway.lastSkillIds, {'skill-mural'});
    await container.read(publicProposalsProvider.notifier).load(reset: false);
    expect(gateway.lastCursor?.id, 'proposal-1');
    expect(gateway.lastQuery, 'mural');
  });

  test('a late Proposal query cannot overwrite the newest result', () async {
    final first = Completer<List<ProposalSummary>>();
    final second = Completer<List<ProposalSummary>>();
    final gateway = FakeProposalGateway()
      ..publicLoader = ({required limit, cursor, query, locality, skillIds}) =>
          switch (query) {
            'first' => first.future,
            'second' => second.future,
            _ => Future.value(const <ProposalSummary>[]),
          };
    final container = ProviderContainer(
      overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final controller = container.read(publicProposalsProvider.notifier);

    final firstLoad = controller.applyFilters(
      query: 'first',
      locality: '',
      skillIds: const {},
    );
    final secondLoad = controller.applyFilters(
      query: 'second',
      locality: '',
      skillIds: const {},
    );
    second.complete([proposalSummaryFixture(id: 'second-result')]);
    await secondLoad;
    first.complete([proposalSummaryFixture(id: 'stale-result')]);
    await firstLoad;

    final state = container.read(publicProposalsProvider);
    expect(state.query, 'second');
    expect(state.items.single.id, 'second-result');
  });

  test('signed-out Browse skips the personalized RPC', () async {
    final gateway = FakeProposalGateway()
      ..publicItems = [proposalSummaryFixture()];
    final container = ProviderContainer(
      overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);

    await container.read(publicProposalsProvider.notifier).load();

    expect(gateway.calls, isNot(contains('list-requested')));
    expect(container.read(publicProposalsProvider).items, hasLength(1));
  });

  test(
    'requested Proposals are deduplicated without changing raw pagination',
    () async {
      final gateway = FakeProposalGateway()
        ..publicItems = [
          proposalSummaryFixture(id: 'requested'),
          proposalSummaryFixture(id: 'ordinary'),
        ]
        ..requestedItems = [requestedProposalFixture(proposalId: 'requested')];
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);

      await session.container.read(publicProposalsProvider.notifier).load();
      final state = session.container.read(publicProposalsProvider);

      expect(state.items.map((item) => item.id), ['requested', 'ordinary']);
      expect(state.requestedItems.single.proposal.id, 'requested');
      expect(state.ordinaryItems.single.id, 'ordinary');
      expect(gateway.lastRequestedIdentity, 'user-1');
    },
  );

  test(
    'requested projection receives the same active Proposal query',
    () async {
      final gateway = FakeProposalGateway()
        ..publicItems = [proposalSummaryFixture()]
        ..requestedItems = [requestedProposalFixture()];
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);

      await session.container
          .read(publicProposalsProvider.notifier)
          .applyFilters(
            query: ' mural ',
            locality: 'Bologna',
            skillIds: {'skill-mural'},
          );

      expect(gateway.lastQuery, 'mural');
      expect(gateway.lastRequestedQuery, 'mural');
      expect(gateway.lastRequestedLocality, 'Bologna');
      expect(gateway.lastRequestedSkillIds, {'skill-mural'});
    },
  );

  test('personalized failure degrades to the successful public feed', () async {
    final gateway = FakeProposalGateway()
      ..publicItems = [proposalSummaryFixture()]
      ..requestedError = StateError('private diagnostic');
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);

    await session.container.read(publicProposalsProvider.notifier).load();
    final state = session.container.read(publicProposalsProvider);

    expect(state.phase, ProposalLoadPhase.ready);
    expect(state.items, hasLength(1));
    expect(state.requestedItems, isEmpty);
    expect(state.failure, isNull);
  });

  test('account switch discards a late personalized response', () async {
    final first = Completer<List<RequestedProposalSummary>>();
    final gateway = FakeProposalGateway()
      ..publicItems = [proposalSummaryFixture()]
      ..requestedLoader = (identity, {query, locality, skillIds}) =>
          identity == 'user-1'
          ? first.future
          : Future.value([
              requestedProposalFixture(proposalId: 'user-2-request'),
            ]);
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final loading = session.container
        .read(publicProposalsProvider.notifier)
        .load();

    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    await Future<void>.delayed(Duration.zero);
    first.complete([requestedProposalFixture(proposalId: 'stale')]);
    await loading;
    await Future<void>.delayed(Duration.zero);

    expect(
      session.container
          .read(publicProposalsProvider)
          .requestedItems
          .single
          .proposal
          .id,
      'user-2-request',
    );
  });

  test(
    'filter changes clear stale Requested cards and reject late results',
    () async {
      final filtered = Completer<List<RequestedProposalSummary>>();
      final gateway = FakeProposalGateway()
        ..publicItems = [proposalSummaryFixture()]
        ..requestedLoader = (_, {query, locality, skillIds}) =>
            locality == 'Rome'
            ? filtered.future
            : Future.value([requestedProposalFixture(proposalId: 'old')]);
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        publicProposalsProvider.notifier,
      );
      await controller.load();

      final applying = controller.applyFilters(
        locality: 'Rome',
        skillIds: const {},
      );
      expect(
        session.container.read(publicProposalsProvider).requestedItems,
        isEmpty,
      );
      filtered.complete([requestedProposalFixture(proposalId: 'new')]);
      await applying;

      expect(
        session.container
            .read(publicProposalsProvider)
            .requestedItems
            .single
            .proposal
            .id,
        'new',
      );
    },
  );

  test(
    'later public pages dedupe Requested IDs but keep the raw tail cursor',
    () async {
      final firstPage = List.generate(
        proposalPageSize,
        (index) => proposalSummaryFixture(id: 'first-$index'),
      );
      final secondPage = [
        proposalSummaryFixture(id: 'requested-later'),
        proposalSummaryFixture(id: 'raw-tail'),
      ];
      final gateway = FakeProposalGateway()
        ..requestedItems = [
          requestedProposalFixture(proposalId: 'requested-later'),
        ]
        ..publicLoader = ({
          required limit,
          cursor,
          query,
          locality,
          skillIds,
        }) => Future.value(cursor == null ? firstPage : secondPage);
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        publicProposalsProvider.notifier,
      );

      await controller.load();
      expect(session.container.read(publicProposalsProvider).hasMore, isTrue);
      await controller.load(reset: false);
      final state = session.container.read(publicProposalsProvider);

      expect(state.items.last.id, 'raw-tail');
      expect(
        state.ordinaryItems.where((item) => item.id == 'requested-later'),
        isEmpty,
      );
      expect(state.hasMore, isFalse);
    },
  );

  test('participation refresh updates and removes Requested cards', () async {
    final participation = FakeParticipationGateway();
    final gateway = FakeProposalGateway()
      ..publicItems = [proposalSummaryFixture()];
    final session = _readyContainer(
      gateway,
      participationGateway: participation,
    );
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    await session.container.read(publicProposalsProvider.notifier).load();

    gateway.requestedItems = [requestedProposalFixture()];
    await session.container
        .read(ownParticipationProvider.notifier)
        .load('user-1');
    await Future<void>.delayed(Duration.zero);
    expect(
      session.container.read(publicProposalsProvider).requestedItems,
      hasLength(1),
    );

    gateway.requestedItems = [];
    await session.container
        .read(ownParticipationProvider.notifier)
        .load('user-1');
    await Future<void>.delayed(Duration.zero);
    expect(
      session.container.read(publicProposalsProvider).requestedItems,
      isEmpty,
    );
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

  test(
    'existing draft restores and updates without lifecycle cancellation',
    () async {
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
      expect(gateway.calls, contains('update:proposal-1'));
      expect(
        await session.container
            .read(proposalEditorProvider.notifier)
            .cancel('user-1'),
        isFalse,
      );
      expect(gateway.calls, isNot(contains('cancel:proposal-1')));
    },
  );

  test('draft accepts missing capacity but publish rejects it', () async {
    final gateway = FakeProposalGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(proposalEditorProvider.notifier);
    await controller.load('user-1', null);
    final input = proposalInputFixture(peopleCapacity: null);

    expect(await controller.saveDraft('user-1', input), 'new-draft');
    expect(gateway.lastInput?.peopleCapacity, isNull);
    expect(await controller.publish('user-1', input), isNull);
    expect(gateway.calls, isNot(contains('publish:new-draft')));
    expect(
      session.container.read(proposalEditorProvider).failure,
      ProposalFailureKind.invalidInput,
    );
  });

  test(
    'published save uses update only and cancellation refreshes exact state',
    () async {
      final gateway = FakeProposalGateway()
        ..ownItems = [
          ownProposalFixture(lifecycle: ProposalLifecycle.published),
        ];
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        proposalEditorProvider.notifier,
      );
      await controller.load('user-1', 'proposal-1');

      expect(
        await controller.saveChanges('user-1', proposalInputFixture()),
        'proposal-1',
      );
      expect(gateway.calls, contains('update:proposal-1'));
      expect(gateway.calls, isNot(contains('publish:proposal-1')));

      expect(await controller.cancel('user-1'), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.calls, contains('cancel:proposal-1'));
      expect(gateway.calls, containsAll(['list-own', 'list-public']));
      expect(gateway.calls, contains('public-detail:proposal-1'));
      expect(
        session.container.read(proposalEditorProvider).proposal?.lifecycle,
        ProposalLifecycle.cancelled,
      );
    },
  );

  test('stale Co-creator authority fails closed on published save', () async {
    final gateway = FakeProposalGateway()
      ..ownItems = [ownProposalFixture(lifecycle: ProposalLifecycle.published)]
      ..mutationError = const PostgrestException(
        message: 'private structural denial',
        code: '42501',
      );
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(proposalEditorProvider.notifier);
    await controller.load('user-1', 'proposal-1');

    expect(
      await controller.saveChanges('user-1', proposalInputFixture()),
      isNull,
    );
    expect(
      session.container.read(proposalEditorProvider).failure,
      ProposalFailureKind.forbidden,
    );
  });

  test(
    'published save rejects capacity below the current people count',
    () async {
      final gateway = FakeProposalGateway()
        ..ownItems = [
          ownProposalFixture(
            lifecycle: ProposalLifecycle.published,
            capacity: projectCapacityFixture(
              peopleCapacity: 5,
              currentParticipantCount: 3,
            ),
          ),
        ];
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        proposalEditorProvider.notifier,
      );
      await controller.load('user-1', 'proposal-1');

      expect(
        await controller.saveChanges(
          'user-1',
          proposalInputFixture(peopleCapacity: 3),
        ),
        isNull,
      );
      expect(gateway.calls, isNot(contains('update:proposal-1')));
      expect(
        session.container.read(proposalEditorProvider).failure,
        ProposalFailureKind.invalidInput,
      );
    },
  );

  test('legacy published save requires capacity', () async {
    final gateway = FakeProposalGateway()
      ..ownItems = [
        ownProposalFixture(
          lifecycle: ProposalLifecycle.published,
          input: proposalInputFixture(peopleCapacity: null),
        ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(proposalEditorProvider.notifier);
    await controller.load('user-1', 'proposal-1');

    expect(
      await controller.saveChanges(
        'user-1',
        proposalInputFixture(peopleCapacity: null),
      ),
      isNull,
    );
    expect(gateway.calls, isNot(contains('update:proposal-1')));
    expect(
      session.container.read(proposalEditorProvider).failure,
      ProposalFailureKind.invalidInput,
    );
  });

  test('forbidden structural Proposal read exposes no cached record', () async {
    final gateway = FakeProposalGateway()
      ..error = const PostgrestException(
        message: 'private structural denial',
        code: '42501',
      );
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);

    await session.container
        .read(proposalEditorProvider.notifier)
        .load('user-1', 'proposal-1');

    final state = session.container.read(proposalEditorProvider);
    expect(state.failure, ProposalFailureKind.forbidden);
    expect(state.proposal, isNull);
  });

  test(
    'new draft exists before cover reconciliation and is retained on failure',
    () async {
      final gateway = FakeProposalGateway();
      final covers = FakeProjectCoverReconciler()
        ..failure = const CoverPersistenceException(
          CoverPersistenceFailureKind.upload,
        )
        ..onCall = (projectId, change) async {
          expect(projectId, 'new-draft');
          expect(gateway.calls, contains('create'));
          expect(gateway.calls, isNot(contains('publish:new-draft')));
        };
      final session = _readyContainer(gateway, coverReconciler: covers);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        proposalEditorProvider.notifier,
      );
      await controller.load('user-1', null);

      final result = await controller.publish(
        'user-1',
        proposalInputFixture(),
        coverChange: CoverChange.replacement(processedCoverFixture()),
      );

      final state = session.container.read(proposalEditorProvider);
      expect(result, isNull);
      expect(state.proposal?.id, 'new-draft');
      expect(state.coverFailure, CoverPersistenceFailureKind.upload);
      expect(state.coverPartialSave, CoverPartialSaveKind.draftCreated);
      expect(gateway.calls, isNot(contains('publish:new-draft')));

      covers.failure = null;
      final retry = await controller.publish(
        'user-1',
        proposalInputFixture(),
        coverChange: CoverChange.replacement(processedCoverFixture()),
      );
      expect(retry, 'new-draft');
      expect(gateway.calls.where((call) => call == 'create'), hasLength(1));
      expect(gateway.calls, contains('update:new-draft'));
      expect(covers.calls, hasLength(2));
    },
  );

  test('pending cover is reconciled before a new draft is published', () async {
    final gateway = FakeProposalGateway();
    final covers = FakeProjectCoverReconciler()
      ..onCall = (projectId, change) async {
        expect(gateway.calls, ['create']);
      };
    final session = _readyContainer(gateway, coverReconciler: covers);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(proposalEditorProvider.notifier);
    await controller.load('user-1', null);

    final result = await controller.publish(
      'user-1',
      proposalInputFixture(),
      coverChange: CoverChange.replacement(processedCoverFixture()),
    );

    expect(result, 'new-draft');
    expect(covers.calls.single.project, 'new-draft');
    expect(gateway.calls, containsAllInOrder(['create', 'publish:new-draft']));
  });

  test(
    'existing content save plus cover failure reports accurate partial success',
    () async {
      final gateway = FakeProposalGateway()..ownItems = [ownProposalFixture()];
      final covers = FakeProjectCoverReconciler()
        ..failure = const CoverPersistenceException(
          CoverPersistenceFailureKind.commit,
        );
      final session = _readyContainer(gateway, coverReconciler: covers);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        proposalEditorProvider.notifier,
      );
      await controller.load('user-1', 'proposal-1');

      final result = await controller.saveDraft(
        'user-1',
        proposalInputFixture(),
        coverChange: CoverChange.replacement(processedCoverFixture()),
      );

      final state = session.container.read(proposalEditorProvider);
      expect(result, isNull);
      expect(gateway.calls, contains('update:proposal-1'));
      expect(state.proposal?.id, 'proposal-1');
      expect(state.coverFailure, CoverPersistenceFailureKind.commit);
      expect(state.coverPartialSave, CoverPartialSaveKind.changesSaved);
    },
  );

  test(
    'publish failure after cover success retains the created draft',
    () async {
      final gateway = FakeProposalGateway()
        ..publishError = StateError('raw publish failure');
      final covers = FakeProjectCoverReconciler();
      final session = _readyContainer(gateway, coverReconciler: covers);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        proposalEditorProvider.notifier,
      );
      await controller.load('user-1', null);

      final result = await controller.publish(
        'user-1',
        proposalInputFixture(),
        coverChange: CoverChange.replacement(processedCoverFixture()),
      );

      expect(result, isNull);
      expect(covers.calls, hasLength(1));
      expect(
        session.container.read(proposalEditorProvider).proposal?.id,
        'new-draft',
      );
    },
  );

  test(
    'account switch rejects late cover reconciliation and publish',
    () async {
      final pending = Completer<void>();
      final gateway = FakeProposalGateway();
      final covers = FakeProjectCoverReconciler()
        ..onCall = (_, _) => pending.future;
      final session = _readyContainer(gateway, coverReconciler: covers);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        proposalEditorProvider.notifier,
      );
      await controller.load('user-1', null);
      final saving = controller.publish(
        'user-1',
        proposalInputFixture(),
        coverChange: CoverChange.replacement(processedCoverFixture()),
      );
      await Future<void>.delayed(Duration.zero);

      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      pending.complete();

      expect(await saving, isNull);
      expect(gateway.calls, isNot(contains('publish:new-draft')));
      expect(session.container.read(proposalEditorProvider).proposal, isNull);
    },
  );

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
      capacity: value.capacity,
    );
    final gateway = FakeProposalGateway()..ownItems = [started];
    final covers = FakeProjectCoverReconciler();
    final session = _readyContainer(gateway, coverReconciler: covers);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    await session.container
        .read(proposalEditorProvider.notifier)
        .load('user-1', started.id);
    await session.container
        .read(proposalEditorProvider.notifier)
        .saveChanges(
          'user-1',
          proposalInputFixture(),
          coverChange: CoverChange.replacement(processedCoverFixture()),
        );
    expect(gateway.calls, isNot(contains('update:proposal-1')));
    expect(covers.calls, isEmpty);
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
  FakeProposalGateway gateway, {
  FakeParticipationGateway? participationGateway,
  ProjectCoverReconciler? coverReconciler,
}) {
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
      if (coverReconciler != null)
        projectCoverReconcilerProvider.overrideWithValue(coverReconciler),
      if (participationGateway != null)
        participationGatewayProvider.overrideWithValue(participationGateway),
      proposalClockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 3)),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return (container: container, auth: auth);
}
