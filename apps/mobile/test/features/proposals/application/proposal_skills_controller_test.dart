import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/application/proposal_skills_controller.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_proposal.dart';

const useful = {'skill-mural': ProposalSkillImportance.useful};

void main() {
  for (final role in [
    ProjectManagementRole.creator,
    ProjectManagementRole.coCreator,
  ]) {
    test('$role saves only skills and reloads canonical importance', () async {
      final h = setup(role: role);
      await h.controller.load('user-1');
      final original = h.state.proposal!;
      h.controller.change(useful);
      expect(await h.controller.save(), isTrue);
      expect(h.gateway.calls, contains('skills:proposal-1'));
      expect(h.gateway.calls.where((s) => s.startsWith('update:')), isEmpty);
      expect(h.gateway.lastExpectedSkills, {
        'skill-mural': ProposalSkillImportance.required,
      });
      expect(h.state.proposal!.description, original.description);
      expect(h.state.edits, useful);
      expect(h.state.dirty, isFalse);
      expect(
        h.state.proposal!.skills.single.importance,
        ProposalSkillImportance.useful,
      );
    });
  }
  for (final role in [
    ProjectManagementRole.coOrganizer,
    ProjectManagementRole.none,
  ]) {
    test('$role cannot enter skill editing or send a mutation', () async {
      final h = setup(role: role);
      expect(await h.controller.load('user-1'), isFalse);
      expect(h.state.failure, ProposalSkillsFailure.forbidden);
      h.controller.change(useful);
      expect(await h.controller.save(), isFalse);
      expect(h.gateway.calls.where((s) => s.startsWith('skills:')), isEmpty);
    });
  }
  for (final code in ['503', '40001', '42501', '55000']) {
    test('$code failure retains unsaved skills and reports its gate', () async {
      final h = setup();
      await h.controller.load('user-1');
      h.controller.change(useful);
      h.gateway.mutationError = PostgrestException(
        message: 'Rejected',
        code: code,
      );
      expect(await h.controller.save(), isFalse);
      expect(h.state.edits, useful);
      expect(h.state.dirty, isTrue);
      expect(h.state.savedUnverified, isFalse);
      expect(h.state.editableAt(DateTime.utc(2026, 9, 1)), code == '503');
    });
  }
  test(
    'acknowledged write with failed reread blocks a duplicate mutation',
    () async {
      final h = setup();
      await h.controller.load('user-1');
      h.controller.change(useful);
      h.gateway.ownReadError = StateError('Read unavailable');
      expect(await h.controller.save(), isFalse);
      expect(h.state.savedUnverified, isTrue);
      expect(h.state.edits, useful);
      expect(await h.controller.save(), isFalse);
      expect(
        h.gateway.calls.where((s) => s.startsWith('skills:')),
        hasLength(1),
      );
      h.gateway.ownReadError = null;
      expect(await h.controller.load('user-1'), isTrue);
      expect(h.state.savedUnverified, isFalse);
      expect(h.state.edits, useful);
    },
  );
  test(
    'late save and read cannot resurrect state after identity changes',
    () async {
      final h = setup();
      await h.controller.load('user-1');
      h.controller.change(useful);
      final gate = Completer<void>();
      h.gateway.mutationDelay = gate.future;
      final save = h.controller.save();
      h.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      gate.complete();
      expect(await save, isFalse);
      expect(h.state.actorId, isNull);
      expect(h.state.edits, isEmpty);
      expect(await h.controller.load('user-1'), isFalse);
      expect(h.state.busy, isFalse);
    },
  );
  test(
    'role loss on foreground reload disables writes without erasing edits',
    () async {
      final h = setup();
      await h.controller.load('user-1');
      h.controller.change(useful);
      h.delegates.role = ProjectManagementRole.coOrganizer;
      expect(await h.controller.load('user-1'), isFalse);
      expect(h.state.edits, useful);
      expect(await h.controller.save(), isFalse);
    },
  );
  test('reload preserves local changes; external skill edit requires explicit discard', () async {
    final h = setup();
    await h.controller.load('user-1');
    h.controller.change(useful);
    await h.controller.load('user-1');
    expect(h.state.edits, useful);
    expect(h.state.failure, isNull);
    h.gateway.ownItems = [
      ownProposalFixture(lifecycle: ProposalLifecycle.published, skills: []),
    ];
    await h.controller.load('user-1');
    expect(h.state.failure, ProposalSkillsFailure.conflict);
    expect(h.state.edits, useful);
    expect(await h.controller.save(), isFalse);
    await h.controller.load('user-1', discardEdits: true);
    expect(h.state.edits, isEmpty);
    expect(h.state.dirty, isFalse);
  });
  test(
    'started records are read-only and provider state belongs to one project',
    () async {
      final h = setup();
      h.gateway.ownItems = [
        ownProposalFixture(
          lifecycle: ProposalLifecycle.published,
          startsAt: DateTime.utc(2020),
        ),
      ];
      await h.controller.load('user-1');
      expect(h.state.failure, ProposalSkillsFailure.readOnly);
      expect(await h.controller.save(), isFalse);
      expect(
        h.container.read(proposalSkillsProvider('different-project')).proposal,
        isNull,
      );
    },
  );
}

class Harness {
  Harness(this.container, this.gateway, this.delegates);
  final ProviderContainer container;
  final FakeProposalGateway gateway;
  final FakeProjectDelegateGateway delegates;
  ProposalSkillsController get controller =>
      container.read(proposalSkillsProvider('proposal-1').notifier);
  ProposalSkillsState get state =>
      container.read(proposalSkillsProvider('proposal-1'));
}

Harness setup({ProjectManagementRole role = ProjectManagementRole.creator}) {
  final gateway = FakeProposalGateway()
    ..ownItems = [ownProposalFixture(lifecycle: ProposalLifecycle.published)];
  final delegates = FakeProjectDelegateGateway()..role = role;
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      proposalGatewayProvider.overrideWithValue(gateway),
      projectDelegateGatewayProvider.overrideWithValue(delegates),
      authGatewayProvider.overrideWithValue(auth),
      proposalClockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 1)),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  final subscription = container.listen(
    proposalSkillsProvider('proposal-1'),
    (_, _) {},
  );
  addTearDown(subscription.close);
  addTearDown(container.dispose);
  addTearDown(auth.close);
  return Harness(container, gateway, delegates);
}
