import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/widgets/tag_multi_select.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_creation_choice.dart';
import 'package:planets_mobile/features/template_workshop/presentation/template_workshop_screens.dart';

import '../../../support/fake_proposal.dart';
import '../../template_workshop/presentation/template_workshop_test.dart'
    as workshop;
import 'proposal_draft_departure_test.dart' as draft;

void main() {
  testWidgets(
    'demo overwrite requires confirmation and actions remain reachable with narrow large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = await draft.pumpEditor(tester);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'My meaningful draft',
      );
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      final save = find.byKey(const Key('proposal-save-draft'));
      await draft.reveal(tester, save);
      expect(save.hitTestable(), findsOneWidget);
      final publish = find.byKey(const Key('proposal-publish'));
      await draft.reveal(tester, publish);
      expect(publish.hitTestable(), findsOneWidget);
      final fill = find.byKey(const Key('proposal-fill-sample'));
      await draft.reveal(tester, fill);
      expect(
        tester.getTopLeft(fill).dy,
        greaterThan(tester.getTopLeft(publish).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(fill);
      await tester.pumpAndSettle();
      expect(find.text('Replace your entries?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await draft.reveal(tester, find.byKey(const Key('proposal-title')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('proposal-title')))
            .controller!
            .text,
        'My meaningful draft',
      );
      expect(app.gateway.calls, isNot(contains('create')));
    },
  );

  testWidgets(
    'chooser cancel, template browsing and repeated scratch taps create no draft',
    (tester) async {
      final app = await workshop.pumpWorkshop(
        tester,
        actualRouter: true,
        initial: '/proposals/create',
      );
      expect(find.byType(ProposalCreationChoice), findsOneWidget);
      await tester.tap(find.byKey(const Key('proposal-start-template')));
      await tester.pumpAndSettle();
      expect(find.byType(TemplateWorkshopScreen), findsOneWidget);
      expect(app.templates.commands, isEmpty);
      app.router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proposal-start-scratch')));
      await tester.tap(find.byKey(const Key('proposal-start-scratch')));
      await tester.pumpAndSettle();
      expect(find.byType(ProposalEditorScreen), findsOneWidget);
      expect(
        find.byType(ProposalCreationChoice, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byKey(const Key('proposal-editor-workshop')), findsNothing);
      app.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ProposalCreationChoice), findsOneWidget);
      app.router.go('/proposals');
      await tester.pumpAndSettle();
      expect(app.proposals.calls, isNot(contains('create')));
      expect(app.templates.commands, isEmpty);
    },
  );

  testWidgets(
    'scratch capacity stays unset, supports direct large values and retains malformed edits',
    (tester) async {
      final app = await draft.pumpEditor(tester);
      final field = find.byKey(const Key('proposal-people-capacity'));
      await draft.reveal(tester, field);
      TextEditingController controller() =>
          tester.widget<TextFormField>(field).controller!;
      expect(controller().text, '');
      await tester.tap(find.byKey(const Key('proposal-capacity-plus')));
      await tester.pump();
      expect(controller().text, '1');
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('proposal-capacity-minus')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(field, '99999');
      await tester.tap(find.byKey(const Key('proposal-capacity-plus')));
      await tester.pump();
      expect(controller().text, '100000');
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('proposal-capacity-plus')))
            .onPressed,
        isNull,
      );
      await tester.enterText(field, '12x');
      await tester.pump();
      expect(controller().text, '12x');
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('proposal-capacity-plus')))
            .onPressed,
        isNull,
      );
      app.router.go('/destination');
      await tester.pumpAndSettle();
      expect(find.text('Keep your draft'), findsOneWidget);
      expect(app.gateway.calls, isNot(contains('create')));
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await draft.reveal(tester, field);
      expect(controller().text, '12x');
    },
  );

  testWidgets(
    'picker cancel does not save suggestions; scratch save uses Europe/Rome',
    (tester) async {
      final app = await draft.pumpEditor(tester);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'New Italian draft',
      );
      final start = find.byKey(const Key('proposal-pick-start'));
      await draft.reveal(tester, start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      final cancel = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      ).cancelButtonLabel;
      await tester.tap(find.text(cancel));
      await tester.pumpAndSettle();
      app.router.go('/destination');
      await tester.pumpAndSettle();
      expect(app.gateway.lastInput!.eventTimezone, 'Europe/Rome');
      expect(app.gateway.lastInput!.startsAt, isNull);
      expect(app.gateway.lastInput!.endsAt, isNull);
    },
  );

  testWidgets(
    'compact selection preserves existing importance while searching',
    (tester) async {
      final app = await draft.pumpEditor(
        tester,
        proposal: ownProposalFixture(),
      );
      final selector = find.byType(TagMultiSelect);
      await draft.reveal(tester, selector);
      final original = tester.widget<TagMultiSelect>(selector).selectedIds;
      // The fixture's existing Required choice must survive opening/searching.
      final initial = Map<String, ProposalSkillImportance>.of(
        app.gateway.ownItems.single.skills.fold(
          {},
          (values, skill) => {...values, skill.id: skill.importance},
        ),
      );
      await tester.tap(find.byKey(const Key('proposal-skills-trigger')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-skills-search')),
        'Arts',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('proposal-skills-apply')));
      await tester.pumpAndSettle();
      expect(tester.widget<TagMultiSelect>(selector).selectedIds, original);
      app.router.go('/destination');
      await tester.pumpAndSettle();
      expect(
        app.gateway.calls.where((call) => call.startsWith('update:')),
        isEmpty,
      );
      expect(initial, isNotEmpty);
    },
  );

  testWidgets(
    'new skill is Useful and removing its summary chip clears the draft selection',
    (tester) async {
      final app = await draft.pumpEditor(tester);
      await draft.selectMural(tester);
      final importance = find.byKey(const Key('proposal-skill-mural'));
      expect(
        tester
            .widget<DropdownButton<ProposalSkillImportance>>(importance)
            .value,
        ProposalSkillImportance.useful,
      );
      final chip = find.byKey(const Key('proposal-skills-selected-mural'));
      tester.widget<InputChip>(chip).onDeleted!();
      await tester.pump();
      app.router.go('/destination');
      await tester.pumpAndSettle();
      expect(app.gateway.calls, isNot(contains('create')));
    },
  );
}
