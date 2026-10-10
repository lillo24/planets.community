import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_tokens.dart';
import 'package:planets_mobile/core/widgets/tag_multi_select.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_creation_choice.dart';
import 'package:planets_mobile/features/template_workshop/presentation/template_workshop_screens.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_proposal.dart';
import '../../template_workshop/presentation/template_workshop_test.dart'
    as workshop;
import 'proposal_draft_departure_test.dart' as draft;

void main() {
  for (final locale in ['en', 'it']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('creation choice centered at 320px $locale ${scale}x', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await workshop.pumpWorkshop(
          tester,
          actualRouter: true,
          initial: '/proposals/create',
          locale: locale,
          scale: scale,
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(ProposalCreationChoice)),
        );
        final heading = find.text(l.proposalStartChoice);
        expect(tester.widget<Text>(heading).textAlign, TextAlign.center);
        expect(tester.getCenter(heading).dx, closeTo(160, 1));
        expect(find.text(l.proposalFromTemplate), findsOneWidget);
        expect(find.text(l.proposalFromScratch), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
      testWidgets(
        'editor explains brief text, people and resources $locale ${scale}x',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 900));
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() => tester.binding.setSurfaceSize(null));
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final app = await draft.pumpEditor(tester, locale: locale);
          final l = AppLocalizations.of(
            tester.element(find.byType(ProposalEditorScreen)),
          );
          final brief = find.byKey(const Key('proposal-summary'));
          await draft.reveal(tester, brief);
          final input = tester.widget<TextField>(
            find.descendant(of: brief, matching: find.byType(TextField)),
          );
          expect(input.decoration!.labelText, l.proposalSummaryLabel);
          expect(input.decoration!.helperText, l.projectShortDescriptionHint);
          final full = find.byKey(const Key('proposal-description'));
          await draft.reveal(tester, full);
          expect(
            tester
                .widget<TextField>(
                  find.descendant(of: full, matching: find.byType(TextField)),
                )
                .decoration!
                .labelText,
            l.proposalDescriptionLabel,
          );
          await draft.reveal(tester, find.text(l.proposalSkillsHint));
          expect(find.text(l.proposalSkillsHint), findsOneWidget);
          await draft.reveal(tester, find.text(l.projectResourcesHint));
          expect(find.text(l.projectResourcesHint), findsOneWidget);
          await draft.reveal(tester, find.text(l.projectResourcesAfterDraft));
          expect(
            find.byKey(const Key('proposal-manage-resources')),
            findsNothing,
          );
          expect(find.text(l.locationAreaPublic), findsNothing);
          expect(app.gateway.calls, isNot(contains('create')));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'Project editor input and competence picker keep spacing at 320px and 2x text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await draft.pumpEditor(tester);
      final picker = find.byKey(const Key('proposal-skills-trigger'));
      final previewFinder = find.byKey(
        const Key('location-visibility-preview'),
      );
      await draft.reveal(tester, previewFinder);
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      final previewBottom =
          tester.getRect(previewFinder).bottom + position.pixels;
      await draft.reveal(tester, picker);
      expect(
        tester.getRect(picker).top + position.pixels - previewBottom,
        greaterThanOrEqualTo(AppSpacing.large),
      );
      expect(tester.getRect(picker).right, lessThanOrEqualTo(320));
      await tester.tap(picker);
      await tester.pumpAndSettle();
      final search = tester.getRect(
        find.byKey(const Key('proposal-skills-search')),
      );
      final count = tester.getRect(
        find.byKey(const Key('proposal-skills-selection-count')),
      );
      expect(count.top - search.bottom, greaterThanOrEqualTo(AppSpacing.small));
      expect(tester.takeException(), isNull);
    },
  );
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
      await draft.reveal(tester, importance);
      expect(
        tester
            .widget<DropdownButton<ProposalSkillImportance>>(importance)
            .value,
        ProposalSkillImportance.useful,
      );
      final chip = find.byKey(const Key('proposal-skills-selected-mural'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      tester.widget<InputChip>(chip).onDeleted!();
      await tester.pump();
      app.router.go('/destination');
      await tester.pumpAndSettle();
      expect(app.gateway.calls, isNot(contains('create')));
    },
  );
}
