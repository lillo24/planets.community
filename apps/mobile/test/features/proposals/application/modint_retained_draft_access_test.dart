import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/router/draft_departure_coordinator.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_proposal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final denied in ['suspension', 'status failure']) {
    test('$denied clears retained editor and departure ownership', () async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      final gateway = FakeProposalGateway()..ownItems = [ownProposalFixture()];
      final container = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(
            FakeProfileAnchorGateway()
              ..readiness = ProfileAnchorReadiness.complete,
          ),
          proposalGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.close);
      final session = container.read(authSessionProvider.notifier);
      session.markProfileReady(const AuthIdentity(id: 'user-1'));
      final editor = container.read(proposalEditorProvider.notifier);
      await editor.load('user-1', 'proposal-1');
      final departure = container.read(draftDepartureProvider);
      departure.register(
        DraftDepartureOwner(
          actorId: 'user-1',
          pageKey: const ValueKey('retained-editor'),
          isActive: () => true,
          prepare: () async => DraftDepartureOutcome.saved,
        ),
      );
      final late = Completer<void>();
      gateway.mutationDelay = late.future;
      final save = editor.saveDraft('user-1', proposalInputFixture());
      if (denied == 'suspension') {
        auth.suspension = AccountSuspensionStatus.active(
          consequenceId: 'episode',
          appliedAt: DateTime.utc(2026, 10, 6),
          userReason: 'Synthetic test reason',
        );
      } else {
        auth.suspensionError = StateError('status unavailable');
      }
      await session.refresh();
      expect(container.read(proposalEditorProvider).proposal, isNull);
      expect(editor.boundProposalId, isNull);
      expect(departure.activeOwner, isNull);
      late.complete();
      expect(await save, isNull);
      expect(container.read(proposalEditorProvider).proposal, isNull);
    });
  }

  test(
    'routine account check preserves the retained draft and departure owner',
    () async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      final gateway = FakeProposalGateway()..ownItems = [ownProposalFixture()];
      final container = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(
            FakeProfileAnchorGateway()
              ..readiness = ProfileAnchorReadiness.complete,
          ),
          proposalGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.close);
      final session = container.read(authSessionProvider.notifier);
      session.markProfileReady(const AuthIdentity(id: 'user-1'));
      final editor = container.read(proposalEditorProvider.notifier);
      await editor.load('user-1', 'proposal-1');
      final departure = container.read(draftDepartureProvider);
      final owner = DraftDepartureOwner(
        actorId: 'user-1',
        pageKey: const ValueKey('retained-editor'),
        isActive: () => true,
        prepare: () async => DraftDepartureOutcome.saved,
      );
      departure.register(owner);
      final gate = Completer<void>();
      auth.suspensionDelay = gate.future;
      final refresh = session.refresh();
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.checkingAccount,
      );
      expect(editor.boundProposalId, 'proposal-1');
      expect(departure.activeOwner, same(owner));
      gate.complete();
      await refresh;
      expect(container.read(authSessionProvider).phase, AuthSessionPhase.ready);
      expect(editor.boundProposalId, 'proposal-1');
      expect(departure.activeOwner, same(owner));
    },
  );
}
