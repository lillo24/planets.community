import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/template_workshop/application/template_controllers.dart';
import 'package:planets_mobile/features/template_workshop/data/template_gateway.dart';
import 'package:planets_mobile/features/template_workshop/presentation/template_workshop_screens.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../test/features/template_workshop/presentation/template_workshop_test.dart'
    as workshop;
import '../test/support/fake_template.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  const phase = bool.fromEnvironment('UIPOLISH_BEFORE') ? 'before' : 'after';
  for (final sample in [(360.0, 1.0, false), (320.0, 2.0, true)]) {
    testWidgets('UIPOLISH02 native $sample', (tester) async {
      final (width, scale, dark) = sample;
      await binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => binding.setSurfaceSize(null));
      final theme = dark ? AppTheme.dark : AppTheme.light;
      final row = templateRowFixture()
        ..['resource_blueprint_count'] = 0
        ..['skills'] = [
          for (final entry in [
            ('woodworking', 'Woodworking'),
            ('gardening', 'Gardening'),
            ('event-organization', 'Event organization'),
            ('facilitation', 'Facilitation'),
          ].indexed)
            {
              'id': needId(entry.$1 + 1),
              'slug': entry.$2.$1,
              'label': entry.$2.$2,
              'category_id': needId(10),
              'category_slug': 'diy-practical',
              'category_label': 'DIY & Practical',
              'importance': entry.$1.isEven ? 'required' : 'useful',
            },
        ];
      const parser = TemplateParser();
      final templates = FakeTemplateGateway()
        ..cards = [parser.card(row)]
        ..value = parser.detail(row);
      final app = await workshop.pumpWorkshop(
        tester,
        locale: 'it',
        scale: scale,
        themeOverride: theme,
        templateOverride: templates,
        categories: [
          ProposalSkillCategory(
            id: needId(10),
            slug: 'diy-practical',
            label: 'DIY & Practical',
            sortOrder: 1,
            skills: [
              ProposalCatalogSkill(
                id: needId(1),
                categoryId: needId(10),
                slug: 'woodworking',
                label: 'Woodworking',
                sortOrder: 1,
              ),
            ],
          ),
        ],
      );
      await binding.convertFlutterSurfaceToImage();
      final name = 'uipolish02-$phase-${width.toInt()}-${scale.toInt()}x';
      await workshop.reveal(
        tester,
        find
            .textContaining(phase == 'before' ? 'Woodworking' : 'Falegnameria')
            .first,
      );
      await capture(tester, binding, '$name-catalog');
      await tester.tap(find.byKey(const Key('template-card-$templateId')));
      await tester.pumpAndSettle();
      await workshop.reveal(
        tester,
        find
            .textContaining(phase == 'before' ? 'Woodworking' : 'Falegnameria')
            .first,
      );
      await capture(tester, binding, '$name-detail');
      app.router.pop();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 10000));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byKey(const Key('template-query')));
      await tester.enterText(find.byKey(const Key('template-query')), 'orto');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await capture(tester, binding, '$name-keyboard');
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.enterText(find.byKey(const Key('template-query')), '');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final controller = app.container.read(
        templateApplicationsProvider.notifier,
      );
      await controller.use(templateActor, templates.value!, false);
      await tester.pumpAndSettle();
      var l = AppLocalizations.of(
        tester.element(find.byType(TemplateWorkshopScreen)),
      );
      await workshop.reveal(tester, find.text(l.workshopAccepted));
      await capture(tester, binding, '$name-created');
      expect(templates.commands, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      final uncertain = FakeTemplateGateway()
        ..applyError = Exception('Synthetic lost acknowledgement');
      final second = await workshop.pumpWorkshop(
        tester,
        locale: 'it',
        scale: scale,
        themeOverride: theme,
        templateOverride: uncertain,
      );
      await second.container
          .read(templateApplicationsProvider.notifier)
          .use(templateActor, uncertain.value!, false);
      await tester.pumpAndSettle();
      l = AppLocalizations.of(
        tester.element(find.byType(TemplateWorkshopScreen)),
      );
      await workshop.reveal(tester, find.text(l.workshopPending));
      await capture(tester, binding, '$name-uncertain');
      expect(uncertain.commands, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> capture(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
  await Future<void>.delayed(const Duration(milliseconds: 80));
  await binding.takeScreenshot(name);
}
