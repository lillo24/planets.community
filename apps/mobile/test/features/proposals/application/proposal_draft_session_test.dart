import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/application/proposal_draft_session.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_proposal.dart';

void main() {
  ProposalDraftSnapshot snapshot({
    String title = '',
    String capacity = '',
    String timezone = 'UTC',
    int cover = 0,
  }) => ProposalDraftSnapshot(
    text: [title, '', '', capacity, timezone, '', '', '', '', ''],
    input: proposalInputFixture(title: title),
    coverRevision: cover,
  );

  test('raw acknowledgements preserve invalid text, and are immutable', () {
    final raw = <String>['Original'];
    final captured = ProposalDraftSnapshot(
      text: raw,
      input: proposalInputFixture(),
      coverRevision: 0,
    );
    raw[0] = 'Newer';
    expect(captured.text, ['Original']);
    expect(snapshot(capacity: 'abc').sameAs(snapshot()), isFalse);
    expect(snapshot(title: 'x').sameAs(snapshot()), isFalse);
    expect(snapshot(cover: 1).sameAs(snapshot()), isFalse);
  });

  test(
    'independent retained editor controllers never exchange bindings',
    () async {
      final auth = FakeAuthGateway();
      final gateway = FakeProposalGateway()..ownItems = [ownProposalFixture()];
      final container = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(auth),
          proposalGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.close);
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-1'));
      final first = container.read(
        proposalEditorSessionProvider('first').notifier,
      );
      final second = container.read(
        proposalEditorSessionProvider('second').notifier,
      );
      await first.load('user-1', null);
      await second.load('user-1', 'proposal-1');
      await first.saveDraft(
        'user-1',
        proposalInputFixture(title: 'First session'),
      );
      await second.saveDraft(
        'user-1',
        proposalInputFixture(title: 'Second session'),
      );
      expect(first.boundProposalId, 'new-draft');
      expect(second.boundProposalId, 'proposal-1');
      expect(
        container.read(proposalEditorSessionProvider('first')).proposal!.title,
        'First session',
      );
      expect(
        container.read(proposalEditorSessionProvider('second')).proposal!.title,
        'Second session',
      );
      await first.load('user-1', null);
      expect(
        container.read(proposalEditorSessionProvider('first')).proposal!.id,
        'new-draft',
      );
      container.read(authSessionProvider.notifier).markSignedOut();
      expect(first.boundProposalId, isNull);
      expect(second.boundProposalId, isNull);
    },
  );
}
