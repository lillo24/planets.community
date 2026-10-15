import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/core/widgets/compact_skill_preview.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/features/template_workshop/data/template_gateway.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_proposal.dart';
import '../../../support/fake_template.dart';
import '../../../support/rendered_evidence.dart';
import '../../template_workshop/presentation/template_workshop_test.dart'
    as workshop;

void main() {
  setUpAll(() => RenderedEvidence.loadFonts(force: true));
  for (final locale in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'Project and template cards $locale $dark $width ${scale}x',
            (tester) async {
              await tester.binding.setSurfaceSize(Size(width, 1500));
              addTearDown(() => tester.binding.setSurfaceSize(null));
              final row = templateRowFixture()
                ..['skills'] = [
                  for (final entry in [
                    'Woodworking',
                    'Gardening',
                    'Basic repairs',
                    'Facilitation',
                  ].indexed)
                    {
                      'id': needId(entry.$1 + 1),
                      'slug': 'skill-${entry.$1}',
                      'label': entry.$2,
                      'category_id': needId(10),
                      'category_slug': 'practical',
                      'category_label': 'Practical',
                      'importance': entry.$1.isEven ? 'useful' : 'required',
                    },
                ];
              const parser = TemplateParser();
              final template = parser.card(row);
              final gateway = FakeTemplateGateway()
                ..cards = [template]
                ..value = parser.detail(row);
              var taps = 0;
              await tester.pumpWidget(
                ProviderScope(
                  child: MaterialApp(
                    locale: Locale(locale),
                    theme: dark ? AppTheme.dark : AppTheme.light,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: Scaffold(
                      body: ListView(
                        children: [
                          ProposalCard(
                            proposal: proposalSummaryFixture(
                              skills: template.skills,
                            ),
                            onTap: () => taps++,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                find.byType(CompactSkillPreview),
                200,
              );
              _checkPreview(tester, [
                for (final importance in ProposalSkillImportance.values)
                  ...template.skills.where((s) => s.importance == importance),
              ]);
              await tester.tap(find.text('...'));
              expect(taps, 1);
              expect(find.text('Skills we need from people'), findsNothing);
              await tester.pumpWidget(const SizedBox());
              await workshop.pumpWorkshop(
                tester,
                locale: locale,
                scale: scale,
                themeOverride: dark ? AppTheme.dark : AppTheme.light,
                templateOverride: gateway,
              );
              await workshop.reveal(tester, find.byType(CompactSkillPreview));
              _checkPreview(tester, template.skills);
              await tester.tap(find.text('...'));
              await tester.pumpAndSettle();
              await workshop.reveal(
                tester,
                find.text(
                  'Facilitation · ${locale == 'it' ? 'Necessaria' : 'Required'}',
                ),
              );
              for (final skill in template.skills) {
                final priority =
                    skill.importance == ProposalSkillImportance.required
                    ? (locale == 'it' ? 'Necessaria' : 'Required')
                    : (locale == 'it' ? 'Utile' : 'Useful');
                expect(find.text('${skill.label} · $priority'), findsOneWidget);
              }
              expect(find.byType(CompactSkillPreview), findsNothing);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}

void _checkPreview(WidgetTester tester, List<ProposalSkill> skills) {
  final preview = find.byType(CompactSkillPreview);
  expect(
    tester.widget<CompactSkillPreview>(preview).labels,
    skills.map((s) => s.label),
  );
  final texts = find.descendant(of: preview, matching: find.byType(Text));
  final rects = texts
      .evaluate()
      .map((e) => tester.getRect(find.byWidget(e.widget)))
      .toList();
  expect(rects.map((r) => r.top).toSet().length, 1);
  expect(rects.length, lessThanOrEqualTo(4));
  final bounds = tester.getRect(preview);
  expect(rects.last.right, lessThanOrEqualTo(bounds.right + .01));
  for (final text in tester.widgetList<Text>(texts)) {
    expect(text.data, isNot(contains('Required')));
    expect(text.data, isNot(contains('Useful')));
    expect(text.data, isNot(contains('Necessaria')));
    expect(text.data, isNot(contains('Utile')));
  }
  expect(tester.takeException(), isNull);
}
