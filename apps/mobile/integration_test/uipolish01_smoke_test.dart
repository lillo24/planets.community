import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:planets_mobile/features/template_workshop/data/template_gateway.dart';

import '../test/support/fake_proposal.dart';
import '../test/support/fake_project_resource_needs.dart';
import '../test/support/fake_template.dart';
import '../test/features/template_workshop/presentation/template_workshop_test.dart'
    as workshop;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  const phase = bool.fromEnvironment('UIPOLISH_BEFORE') ? 'before' : 'after';
  for (final sample in [(360.0, 1.0, false), (320.0, 2.0, true)]) {
    testWidgets('UIPOLISH01 native $sample', (tester) async {
      final (width, scale, dark) = sample;
      await binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => binding.setSurfaceSize(null));
      final theme = dark ? AppTheme.dark : AppTheme.light;
      final skills = [
        for (final entry in [
          'Woodworking',
          'Gardening',
          'Basic repairs',
          'Facilitation',
        ].indexed)
          ProposalSkill(
            id: needId(entry.$1 + 1),
            slug: 'skill-${entry.$1}',
            label: entry.$2,
            categoryId: needId(10),
            categorySlug: 'practical',
            categoryLabel: 'Practical',
            importance: entry.$1.isEven
                ? ProposalSkillImportance.required
                : ProposalSkillImportance.useful,
          ),
      ];
      Widget app(Widget child) => ProviderScope(
        overrides: [
          proposalGatewayProvider.overrideWithValue(
            FakeProposalGateway()
              ..publicDetail = proposalDetailFixture(skills: skills),
          ),
          projectResourceNeedsGatewayProvider.overrideWithValue(
            FakeProjectResourceNeedsGateway(),
          ),
        ],
        child: MaterialApp(
          theme: theme,
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      );
      var taps = 0;
      await tester.pumpWidget(
        app(
          ListView(
            children: [
              ProposalCard(
                proposal: proposalSummaryFixture(skills: skills),
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      final name = 'uipolish01-$phase-${width.toInt()}-${scale.toInt()}x';
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('$name-project-card');
      await tester.tapAt(Offset(width / 2, 300));
      expect(taps, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        app(const ProposalDetailScreen(proposalId: 'proposal-1')),
      );
      await tester.pumpAndSettle();
      await workshop.reveal(tester, find.text('Programma'));
      await binding.takeScreenshot('$name-schedule');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      final row = templateRowFixture()
        ..['skills'] = [
          for (final skill in skills)
            {
              'id': skill.id,
              'slug': skill.slug,
              'label': skill.label,
              'category_id': skill.categoryId,
              'category_slug': skill.categorySlug,
              'category_label': skill.categoryLabel,
              'importance': skill.importance == ProposalSkillImportance.required
                  ? 'required'
                  : 'useful',
            },
        ];
      const parser = TemplateParser();
      await workshop.pumpWorkshop(
        tester,
        locale: 'it',
        scale: scale,
        themeOverride: theme,
        templateOverride: FakeTemplateGateway()
          ..cards = [parser.card(row)]
          ..value = parser.detail(row),
      );
      await workshop.reveal(tester, find.textContaining('Woodworking').first);
      await binding.takeScreenshot('$name-template');
      expect(tester.takeException(), isNull);
    });
  }
}
