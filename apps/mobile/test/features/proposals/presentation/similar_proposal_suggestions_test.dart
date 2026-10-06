import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/router/draft_departure_coordinator.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/cover_media/domain/cover_media_models.dart';
import 'package:planets_mobile/features/cover_media/presentation/cover_editor_section.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/domain/similar_proposal.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';

import '../../../support/fake_cover_media.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_similar_proposal.dart';
import '../../../support/fake_template.dart';
import '../../template_workshop/presentation/template_workshop_test.dart'
    as workshop;
import 'proposal_draft_departure_test.dart' as draft;

Future<void> settleLookup(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  // The editor lazily mounts fields; start from the top when revisiting an
  // earlier field after inspecting geography/skills farther down the form.
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 250, scrollable: scrollable);
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

Future<void> openSheet(WidgetTester tester) async {
  await reveal(tester, find.byKey(const Key('similar-view')));
  await tester.tap(find.byKey(const Key('similar-view')));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('similar-open-$similarId')));
  await tester.pumpAndSettle();
}

void main() {
  for (final loss in ['input', 'readiness', 'dispose']) {
    testWidgets('stale sheet selection after $loss cannot navigate or save', (
      tester,
    ) async {
      final similar = FakeSimilarProposalGateway()..items = [similarFixture()];
      final app = await draft.pumpEditor(tester, similar: similar);
      final title = tester
          .widget<TextFormField>(find.byKey(const Key('proposal-title')))
          .controller!;
      title.text = 'repair';
      await settleLookup(tester);
      await openSheet(tester);
      final old = tester
          .widget<TextButton>(find.byKey(const Key('similar-open-$similarId')))
          .onPressed!;
      if (loss == 'input') {
        title.text = 'murale';
      } else if (loss == 'readiness') {
        app.container
            .read(authSessionProvider.notifier)
            .markProfileSetupRequired(
              const AuthIdentity(id: 'user-1'),
              hasProfileAnchor: true,
            );
      } else {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      old();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('similar-sheet')), findsNothing);
      expect(find.text('Candidate detail'), findsNothing);
      expect(app.gateway.calls, isNot(contains('create')));
    });
  }
  testWidgets(
    'explicit discard authorizes selected detail without saved feedback',
    (tester) async {
      final similar = FakeSimilarProposalGateway()..items = [similarFixture()];
      final app = await draft.pumpEditor(tester, similar: similar);
      await tester.enterText(find.byKey(const Key('proposal-title')), 'repair');
      await reveal(tester, find.byKey(const Key('proposal-country')));
      await tester.enterText(find.byKey(const Key('proposal-country')), 'I');
      await settleLookup(tester);
      await openSheet(tester);
      await choose(tester);
      await tester.tap(find.text('Discard unsaved changes'));
      await tester.pumpAndSettle();
      expect(find.text('Candidate detail'), findsOneWidget);
      expect(find.text('Draft saved'), findsNothing);
      expect(app.gateway.calls, isNot(contains('create')));
      app.router.pop();
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('proposal-title')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('proposal-title')))
            .controller!
            .text,
        '',
      );
    },
  );
  testWidgets(
    'real template-copy editor matching preserves destination and prior editor',
    (tester) async {
      final similar = FakeSimilarProposalGateway()..items = [similarFixture()];
      final app = await workshop.pumpWorkshop(
        tester,
        initial: '/proposals/create',
        similar: similar,
      );
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Prior repair idea',
      );
      await settleLookup(tester);
      await reveal(tester, find.byKey(const Key('similar-dismiss')));
      await tester.tap(find.byKey(const Key('similar-dismiss')));
      await tester.tap(find.byKey(const Key('proposal-editor-workshop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('template-card-$templateId')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('template-use')));
      await tester.tap(find.byKey(const Key('template-use')));
      await tester.pumpAndSettle();
      await settleLookup(tester);
      expect(similar.calls.last.excludedProposalId, templateDestination);
      expect(similar.calls.last.excludedProposalId, isNot(templateId));
      expect(find.byKey(const Key('similar-reopen')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Copied repair idea',
      );
      await settleLookup(tester);
      await openSheet(tester);
      await choose(tester);
      expect(find.text('Candidate detail'), findsOneWidget);
      expect(app.proposals.calls, contains('update:$templateDestination'));
      app.router.pop();
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('proposal-title')));
      expect(find.text('Copied repair idea'), findsOneWidget);
      app.router.pop();
      await tester.pumpAndSettle();
      app.router.pop();
      await tester.pumpAndSettle();
      app.router.pop();
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('proposal-title')));
      expect(find.text('Prior repair idea'), findsOneWidget);
      expect(find.byKey(const Key('similar-reopen')), findsOneWidget);
      expect(app.templates.commands, hasLength(1));
    },
  );
  for (final locale in ['en', 'it']) {
    testWidgets(
      'quiet current matches, modal dismissal without save, dismiss/reopen ($locale)',
      (tester) async {
        final similar = FakeSimilarProposalGateway()
          ..items = [similarFixture()];
        final app = await draft.pumpEditor(
          tester,
          similar: similar,
          locale: locale,
        );
        await tester.enterText(
          find.byKey(const Key('proposal-title')),
          'Repair Café',
        );
        await settleLookup(tester);
        expect(find.byKey(const Key('similar-entry')), findsOneWidget);
        expect(app.gateway.calls, isNot(contains('create')));
        expect(find.byKey(const Key('similar-sheet')), findsNothing);
        await openSheet(tester);
        expect(find.text('Repair Café del sabato'), findsOneWidget);
        expect(
          find.text(locale == 'it' ? 'Vedi progetto' : 'View Project'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('similar-sheet-close')));
        await tester.pumpAndSettle();
        await settleLookup(tester);
        expect(app.gateway.calls, isNot(contains('create')));
        expect(
          find.text(locale == 'it' ? 'Bozza salvata' : 'Draft saved'),
          findsNothing,
        );
        await reveal(tester, find.byKey(const Key('similar-dismiss')));
        await tester.tap(find.byKey(const Key('similar-dismiss')));
        await tester.pumpAndSettle();
        final calls = similar.calls.length;
        await reveal(tester, find.byKey(const Key('proposal-title')));
        await tester.enterText(
          find.byKey(const Key('proposal-title')),
          'Murale',
        );
        await settleLookup(tester);
        expect(similar.calls, hasLength(calls));
        expect(find.byKey(const Key('similar-reopen')), findsOneWidget);
        await reveal(tester, find.byKey(const Key('similar-reopen')));
        await tester.tap(find.byKey(const Key('similar-reopen')));
        await settleLookup(tester);
        expect(similar.calls.last.title, 'Murale');
      },
    );
  }
  testWidgets(
    'real departure owner restored before one push; save and Back preserve first bound draft',
    (tester) async {
      final similar = FakeSimilarProposalGateway()..items = [similarFixture()];
      final owners = <DraftDepartureOwner?>[];
      final app = await draft.pumpEditor(
        tester,
        similar: similar,
        onCandidateEnter: owners.add,
      );
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Repair Café',
      );
      await settleLookup(tester);
      expect(similar.calls.single.excludedProposalId, isNull);
      await openSheet(tester);
      expect(app.container.read(draftDepartureProvider).activeOwner, isNull);
      final callback = tester
          .widget<TextButton>(find.byKey(const Key('similar-open-$similarId')))
          .onPressed!;
      callback();
      callback();
      await tester.pumpAndSettle();
      expect(find.text('Candidate detail'), findsOneWidget);
      expect(owners, hasLength(1));
      expect(owners.single?.actorId, 'user-1');
      expect(app.gateway.calls.where((c) => c == 'create'), hasLength(1));
      expect(find.text('Draft saved'), findsOneWidget);
      app.router.pop();
      await tester.pumpAndSettle();
      await settleLookup(tester);
      await reveal(tester, find.byKey(const Key('proposal-title')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('proposal-title')))
            .controller!
            .text,
        'Repair Café',
      );
      expect(similar.calls.last.excludedProposalId, 'new-draft');
      expect(app.gateway.ownItems, hasLength(1));
    },
  );
  testWidgets(
    'description and importance edits do not request; selected IDs and valid hints do',
    (tester) async {
      final similar = FakeSimilarProposalGateway();
      await draft.pumpEditor(tester, similar: similar);
      await tester.enterText(find.byKey(const Key('proposal-title')), 'Aiuola');
      await settleLookup(tester);
      final skill = find.byKey(const Key('proposal-skill-mural'));
      await reveal(tester, skill);
      void select(ProposalSkillImportance value) => tester
          .widget<DropdownButton<ProposalSkillImportance?>>(skill)
          .onChanged!(value);
      select(ProposalSkillImportance.useful);
      await settleLookup(tester);
      final count = similar.calls.length;
      select(ProposalSkillImportance.required);
      await settleLookup(tester);
      await reveal(tester, find.byKey(const Key('proposal-description')));
      await tester.enterText(
        find.byKey(const Key('proposal-description')),
        'Private description not sent',
      );
      await settleLookup(tester);
      expect(similar.calls, hasLength(count));
      await reveal(tester, find.byKey(const Key('proposal-country')));
      await tester.enterText(find.byKey(const Key('proposal-country')), 'ITA');
      await settleLookup(tester);
      expect(similar.calls, hasLength(count));
      await tester.enterText(find.byKey(const Key('proposal-country')), 'it');
      await settleLookup(tester);
      expect(similar.calls.last.countryCode, 'IT');
      await tester.enterText(
        find.byKey(const Key('proposal-locality')),
        'Trento',
      );
      await settleLookup(tester);
      expect(similar.calls.last.locality, 'trento');
    },
  );
  testWidgets(
    'loading/error/Retry distinct from settled empty and input invalidates immediately',
    (tester) async {
      final similar = FakeSimilarProposalGateway(),
          pending = Completer<List<SimilarProposal>>();
      similar.loader = (_) => pending.future;
      await draft.pumpEditor(tester, similar: similar);
      await tester.enterText(find.byKey(const Key('proposal-title')), 'repair');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.byKey(const Key('similar-loading')), findsOneWidget);
      pending.completeError(StateError('Synthetic failure'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('similar-error')), findsOneWidget);
      similar.loader = (_) async => [];
      await tester.tap(find.byKey(const Key('similar-retry')));
      await settleLookup(tester);
      expect(find.byKey(const Key('similar-error')), findsNothing);
      similar.loader = (_) async => [similarFixture()];
      await tester.enterText(find.byKey(const Key('proposal-title')), 'murale');
      await settleLookup(tester);
      expect(find.byKey(const Key('similar-entry')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'another',
      );
      await tester.pump();
      expect(find.byKey(const Key('similar-entry')), findsNothing);
      tester
              .widget<TextFormField>(find.byKey(const Key('proposal-title')))
              .controller!
              .text =
          'x' * 101;
      await settleLookup(tester);
      expect(find.byKey(const Key('similar-entry')), findsNothing);
      await tester.enterText(find.byKey(const Key('proposal-title')), '');
      final calls = similar.calls.length;
      await settleLookup(tester);
      expect(similar.calls, hasLength(calls));
    },
  );
  testWidgets(
    'background and detail suspension; return refreshes once with current bound ID',
    (tester) async {
      final similar = FakeSimilarProposalGateway()..items = [similarFixture()];
      final app = await draft.pumpEditor(tester, similar: similar);
      await tester.enterText(find.byKey(const Key('proposal-title')), 'repair');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 1));
      expect(similar.calls, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleLookup(tester);
      expect(similar.calls, hasLength(1));
      await openSheet(tester);
      await choose(tester);
      final count = similar.calls.length;
      await tester.pump(const Duration(seconds: 2));
      expect(similar.calls, hasLength(count));
      app.router.pop();
      await tester.pumpAndSettle();
      await settleLookup(tester);
      expect(similar.calls, hasLength(count + 1));
      expect(similar.calls.last.excludedProposalId, 'new-draft');
    },
  );
  testWidgets(
    'stale account sheet callback cannot expose old results or navigate',
    (tester) async {
      final similar = FakeSimilarProposalGateway()..items = [similarFixture()];
      final app = await draft.pumpEditor(tester, similar: similar);
      await tester.enterText(find.byKey(const Key('proposal-title')), 'repair');
      await settleLookup(tester);
      await openSheet(tester);
      final old = tester
          .widget<TextButton>(find.byKey(const Key('similar-open-$similarId')))
          .onPressed!;
      app.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      old();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('similar-sheet')), findsNothing);
      expect(find.text('Candidate detail'), findsNothing);
      expect(find.text('Draft saved'), findsNothing);
      expect(app.gateway.calls, isNot(contains('create')));
    },
  );
  testWidgets(
    'invalid draft blocks selected detail; keep raw input, correct, and retry',
    (tester) async {
      final similar = FakeSimilarProposalGateway()..items = [similarFixture()];
      final app = await draft.pumpEditor(tester, similar: similar);
      await tester.enterText(find.byKey(const Key('proposal-title')), 'repair');
      await reveal(tester, find.byKey(const Key('proposal-country')));
      await tester.enterText(find.byKey(const Key('proposal-country')), 'I');
      await settleLookup(tester);
      await openSheet(tester);
      await choose(tester);
      expect(find.text('Keep your draft'), findsOneWidget);
      expect(find.text('Candidate detail'), findsNothing);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      final country = find.byKey(const Key('proposal-country'));
      await reveal(tester, country);
      expect(tester.widget<TextFormField>(country).controller!.text, 'I');
      await tester.enterText(country, 'IT');
      await settleLookup(tester);
      await openSheet(tester);
      await choose(tester);
      expect(find.text('Candidate detail'), findsOneWidget);
      expect(app.gateway.calls.where((c) => c == 'create'), hasLength(1));
    },
  );
  testWidgets(
    'lost save acknowledgment retry keeps exact creation intent and one destination feedback',
    (tester) async {
      final similar = FakeSimilarProposalGateway()..items = [similarFixture()];
      final gateway = FakeProposalGateway()
        ..createResponseError = StateError('Synthetic lost response');
      await draft.pumpEditor(tester, similar: similar, gateway: gateway);
      await tester.enterText(find.byKey(const Key('proposal-title')), 'repair');
      await settleLookup(tester);
      await openSheet(tester);
      await choose(tester);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(gateway.ownItems, hasLength(1));
      expect(find.text('Draft saved'), findsNothing);
      await settleLookup(tester);
      await openSheet(tester);
      await choose(tester);
      expect(gateway.ownItems, hasLength(1));
      expect(find.text('Candidate detail'), findsOneWidget);
      expect(find.text('Draft saved'), findsOneWidget);
    },
  );
  testWidgets(
    'accepted candidate wins competing route while one save is pending',
    (tester) async {
      final pending = Completer<void>(),
          gateway = FakeProposalGateway()..mutationDelay = pending.future;
      final similar = FakeSimilarProposalGateway()..items = [similarFixture()];
      final app = await draft.pumpEditor(
        tester,
        similar: similar,
        gateway: gateway,
      );
      await tester.enterText(find.byKey(const Key('proposal-title')), 'repair');
      await settleLookup(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('similar-open-$similarId')));
      await tester.pumpAndSettle();
      app.router.go('/proposals/mine');
      await tester.pump();
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Candidate detail'), findsOneWidget);
      expect(gateway.calls.where((c) => c == 'create'), hasLength(1));
      expect(find.text('Draft saved'), findsOneWidget);
      app.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ProposalEditorScreen), findsOneWidget);
    },
  );
  testWidgets('partial image departure keeps truthful DRAFT01 warning', (
    tester,
  ) async {
    final similar = FakeSimilarProposalGateway()..items = [similarFixture()];
    final cover = FakeProjectCoverReconciler()
      ..failure = const CoverPersistenceException(
        CoverPersistenceFailureKind.upload,
      );
    final app = await draft.pumpEditor(tester, similar: similar, covers: cover);
    await tester.enterText(find.byKey(const Key('proposal-title')), 'repair');
    tester
        .widget<CoverEditorSection>(find.byType(CoverEditorSection))
        .onChanged(CoverChange.replacement(processedCoverFixture()));
    await settleLookup(tester);
    await openSheet(tester);
    await choose(tester);
    await tester.tap(find.text('Leave without image change'));
    await tester.pumpAndSettle();
    expect(
      find.text('Draft content saved; image change not confirmed.'),
      findsOneWidget,
    );
    expect(find.text('Draft saved'), findsNothing);
    expect(app.gateway.ownItems, hasLength(1));
  });
  testWidgets(
    'published editors never lookup; unchanged owned draft has no false saved feedback',
    (tester) async {
      final similar = FakeSimilarProposalGateway()..items = [similarFixture()];
      await draft.pumpEditor(
        tester,
        similar: similar,
        proposal: ownProposalFixture(lifecycle: ProposalLifecycle.published),
      );
      await tester.enterText(find.byKey(const Key('proposal-title')), 'repair');
      await settleLookup(tester);
      expect(similar.calls, isEmpty);
      expect(find.byKey(const Key('similar-entry')), findsNothing);
    },
  );
  testWidgets(
    'unchanged independent draft excludes its destination and does not save on selection',
    (tester) async {
      final similar = FakeSimilarProposalGateway()..items = [similarFixture()];
      final app = await draft.pumpEditor(
        tester,
        similar: similar,
        proposal: ownProposalFixture(id: 'copy'),
      );
      await settleLookup(tester);
      expect(similar.calls.single.excludedProposalId, 'copy');
      await openSheet(tester);
      await choose(tester);
      expect(find.text('Candidate detail'), findsOneWidget);
      expect(find.text('Draft saved'), findsNothing);
      expect(app.gateway.calls.where((c) => c.startsWith('update:')), isEmpty);
    },
  );
  testWidgets(
    'Full/unknown previews accessible on a small screen at large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final similar = FakeSimilarProposalGateway()
        ..items = [
          similarFixture(
            title: 'A very long public title with enough words to wrap safely',
            availability: SimilarAvailability.full,
          ),
          similarFixture(
            id: 'e6000000-0000-4000-8000-000000000003',
            availability: SimilarAvailability.capacityUnknown,
          ),
        ];
      await draft.pumpEditor(tester, similar: similar);
      await tester.enterText(find.byKey(const Key('proposal-title')), 'repair');
      await settleLookup(tester);
      await openSheet(tester);
      expect(find.text('Full'), findsOneWidget);
      expect(find.text('Join now'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Registration capacity not set'),
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('similar-sheet')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Registration capacity not set'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
