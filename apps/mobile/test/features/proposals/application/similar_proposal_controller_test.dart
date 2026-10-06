import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/proposals/application/similar_proposal_controller.dart';
import 'package:planets_mobile/features/proposals/data/similar_proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/similar_proposal.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_similar_proposal.dart';

void main() {
  ({ProviderContainer c, FakeSimilarProposalGateway gateway}) setup() {
    final auth = FakeAuthGateway(), gateway = FakeSimilarProposalGateway();
    final c = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        similarProposalGatewayProvider.overrideWithValue(gateway),
      ],
    );
    c
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'actor'));
    addTearDown(c.dispose);
    addTearDown(auth.close);
    return (c: c, gateway: gateway);
  }

  SimilarProposalQuery query(
    String title, {
    String? excluded,
    Iterable<String> skills = const [],
  }) => SimilarProposalQuery(
    actorId: 'actor',
    title: title,
    skillIds: skills,
    excludedProposalId: excluded,
  );
  testWidgets(
    '350 ms debounce latest title-only idea and no unchanged-query request',
    (tester) async {
      final app = setup(),
          controller = app.c.read(similarProposalProvider('one').notifier);
      controller.setActive(true);
      controller.setQuery(query('repair'));
      await tester.pump(const Duration(milliseconds: 200));
      controller.setQuery(query('murale'));
      await tester.pump(const Duration(milliseconds: 349));
      expect(app.gateway.calls, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(app.gateway.calls.single.title, 'murale');
      controller.setQuery(query('murale'));
      await tester.pump(const Duration(seconds: 1));
      expect(app.gateway.calls, hasLength(1));
    },
  );
  testWidgets(
    'query change hides settled results immediately; late older response ignored',
    (tester) async {
      final app = setup(),
          old = Completer<List<SimilarProposal>>(),
          newer = Completer<List<SimilarProposal>>();
      app.gateway.loader = (q) =>
          q.title == 'repair' ? old.future : newer.future;
      final controller = app.c.read(similarProposalProvider('one').notifier);
      controller.setActive(true);
      controller.setQuery(query('repair'));
      await tester.pump(const Duration(milliseconds: 350));
      controller.setQuery(query('murale'));
      expect(app.c.read(similarProposalProvider('one')).items, isEmpty);
      await tester.pump(const Duration(milliseconds: 350));
      newer.complete([similarFixture(title: 'Current')]);
      await tester.pump();
      old.complete([similarFixture(title: 'Old')]);
      await tester.pump();
      expect(
        app.c.read(similarProposalProvider('one')).items.single.title,
        'Current',
      );
    },
  );
  testWidgets(
    'same selected set suppresses calls; changed set/exclusion refresh; dismissal survives binding',
    (tester) async {
      final app = setup(),
          controller = app.c.read(similarProposalProvider('one').notifier);
      controller.setActive(true);
      controller.setQuery(query('repair', skills: ['b', 'a']));
      await tester.pump(const Duration(milliseconds: 350));
      controller.setQuery(query('repair', skills: ['a', 'b', 'a']));
      await tester.pump(const Duration(milliseconds: 350));
      expect(app.gateway.calls, hasLength(1));
      controller.setQuery(query('repair', skills: ['a']));
      await tester.pump(const Duration(milliseconds: 350));
      expect(app.gateway.calls, hasLength(2));
      controller.dismiss();
      controller.setQuery(query('repair', excluded: 'bound'));
      await tester.pump(const Duration(seconds: 1));
      expect(app.gateway.calls, hasLength(2));
      expect(app.c.read(similarProposalProvider('one')).dismissed, isTrue);
      controller.reopen();
      await tester.pump(const Duration(milliseconds: 350));
      expect(app.gateway.calls.last.excludedProposalId, 'bound');
    },
  );
  testWidgets(
    'sheet pauses with settled preview; real inactivity invalidates callbacks; resume refreshes once',
    (tester) async {
      final app = setup();
      app.gateway.items = [similarFixture()];
      final controller = app.c.read(similarProposalProvider('one').notifier);
      controller.setActive(true);
      controller.setQuery(query('repair'));
      await tester.pump(const Duration(milliseconds: 350));
      final ticket = controller.selection()!;
      controller.setActive(false, sheet: true);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.accepts(ticket, similarId), isTrue);
      expect(app.gateway.calls, hasLength(1));
      controller.setActive(false);
      expect(controller.accepts(ticket, similarId), isFalse);
      expect(app.c.read(similarProposalProvider('one')).items, isEmpty);
      controller.setActive(true);
      await tester.pump(const Duration(milliseconds: 350));
      expect(app.gateway.calls, hasLength(2));
    },
  );
  testWidgets(
    'account/readiness changes reject an in-flight lookup and selection',
    (tester) async {
      final app = setup(), pending = Completer<List<SimilarProposal>>();
      app.gateway.loader = (_) => pending.future;
      final controller = app.c.read(similarProposalProvider('one').notifier);
      controller.setActive(true);
      controller.setQuery(query('repair'));
      await tester.pump(const Duration(milliseconds: 350));
      app.c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'another'));
      pending.complete([similarFixture()]);
      await tester.pump();
      expect(app.c.read(similarProposalProvider('one')).items, isEmpty);
      controller.setActive(true);
      controller.setQuery(query('repair'));
      await tester.pump(const Duration(seconds: 1));
      expect(app.gateway.calls, hasLength(1));
    },
  );
  testWidgets(
    'separate editors never share query/result/dismissal or selection',
    (tester) async {
      final app = setup();
      app.gateway.loader = (q) async => [similarFixture(title: q.title)];
      final a = app.c.read(similarProposalProvider('one').notifier),
          b = app.c.read(similarProposalProvider('two').notifier);
      a.setActive(true);
      b.setActive(true);
      a.setQuery(query('repair'));
      b.setQuery(query('murale'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        app.c.read(similarProposalProvider('one')).items.single.title,
        'repair',
      );
      expect(
        app.c.read(similarProposalProvider('two')).items.single.title,
        'murale',
      );
      expect(b.accepts(a.selection()!, similarId), isFalse);
      a.dismiss();
      expect(app.c.read(similarProposalProvider('two')).dismissed, isFalse);
    },
  );
  testWidgets(
    'explicit failure distinct from empty; Retry uses latest eligible query',
    (tester) async {
      final app = setup();
      app.gateway.error = StateError('Synthetic transport failure');
      final controller = app.c.read(similarProposalProvider('one').notifier);
      controller.setActive(true);
      controller.setQuery(query('repair'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        app.c.read(similarProposalProvider('one')).phase,
        SimilarProposalPhase.failure,
      );
      app.gateway.error = null;
      controller.setQuery(query('murale'));
      controller.retry();
      await tester.pump(const Duration(milliseconds: 350));
      expect(app.gateway.calls.last.title, 'murale');
      expect(
        app.c.read(similarProposalProvider('one')).phase,
        SimilarProposalPhase.ready,
      );
      expect(app.c.read(similarProposalProvider('one')).items, isEmpty);
    },
  );
  testWidgets('release cancels timer; immediate remount has a fresh epoch', (
    tester,
  ) async {
    final app = setup(),
        controller = app.c.read(similarProposalProvider('one').notifier);
    controller.setActive(true);
    controller.setQuery(query('repair'));
    controller.dismiss();
    controller.releaseSession();
    controller.acquireSession();
    controller.setActive(true);
    controller.setQuery(query('murale'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(app.gateway.calls.single.title, 'murale');
    expect(app.c.read(similarProposalProvider('one')).dismissed, isFalse);
  });
  testWidgets('null title-query and disposal cancel pending scheduled work', (
    tester,
  ) async {
    final app = setup(),
        controller = app.c.read(similarProposalProvider('one').notifier);
    controller.setActive(true);
    controller.setQuery(query('repair'));
    controller.setQuery(null);
    await tester.pump(const Duration(seconds: 1));
    expect(app.gateway.calls, isEmpty);
    controller.setQuery(query('murale'));
    controller.releaseSession();
    await tester.pump(const Duration(seconds: 1));
    expect(app.gateway.calls, isEmpty);
  });
}
