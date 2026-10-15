import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/core/widgets/browse_filter_button.dart';
import 'package:planets_mobile/core/widgets/compact_skill_preview.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/features/template_workshop/application/template_controllers.dart';
import 'package:planets_mobile/features/template_workshop/data/template_gateway.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_proposal.dart';
import '../../../support/fake_template.dart';
import '../../../support/rendered_evidence.dart';
import 'template_workshop_test.dart' as workshop;

void main() {
  setUpAll(() => RenderedEvidence.loadFonts(force: true));
  for (final locale in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'localized cards, recovery, filters and keyboard $locale $dark $width $scale',
            (tester) async {
              await tester.binding.setSurfaceSize(Size(width, 900));
              addTearDown(() => tester.binding.setSurfaceSize(null));
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetDevicePixelRatio);
              final theme = dark ? AppTheme.dark : AppTheme.light;
              final row = templateRowFixture()
                ..['resource_blueprint_count'] = 0
                ..['title'] = 'A long synthetic title for building and repairing together in the neighborhood'
                ..['summary'] = 'A complete synthetic summary that stays available while metadata and skills adapt.'
                ..['skills'] = [
                  {
                    'id': needId(1),
                    'slug': 'woodworking',
                    'label': 'Woodworking',
                    'category_id': needId(10),
                    'category_slug': 'diy-practical',
                    'category_label': 'DIY & Practical',
                    'importance': 'required',
                  },
                  {
                    'id': needId(2),
                    'slug': 'future-skill',
                    'label':
                        'A new controlled skill with a long canonical label',
                    'category_id': needId(10),
                    'category_slug': 'diy-practical',
                    'category_label': 'DIY & Practical',
                    'importance': 'useful',
                  },
                ];
              const parser = TemplateParser();
              final card = parser.card(row);
              final known = locale == 'it' ? 'Falegnameria' : 'Woodworking';
              var taps = 0;
              await tester.pumpWidget(
                ProviderScope(
                  child: MaterialApp(
                    locale: Locale(locale),
                    theme: theme,
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
                              skills: card.skills,
                            ),
                            onTap: () => taps++,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ProposalSkillRequirements(
                              skills: card.skills,
                              multiline: true,
                            ),
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
              final labels = find.descendant(
                of: find.byType(CompactSkillPreview),
                matching: find.byType(Text),
              );
              expect(tester.widgetList<Text>(labels).first.data, known);
              expect(
                labels
                    .evaluate()
                    .map((e) => tester.getRect(find.byWidget(e.widget)).top)
                    .toSet()
                    .length,
                1,
              );
              await tester.tap(labels.first);
              expect(taps, 1);
              await tester.scrollUntilVisible(
                find.byType(ProposalSkillRequirements),
                200,
              );
              final priority = locale == 'it' ? 'Necessaria' : 'Required';
              expect(find.text('$priority: $known'), findsOneWidget);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());

              final templates = FakeTemplateGateway()
                ..cards = [card]
                ..value = parser.detail(row);
              Set<String>? received;
              templates.listLoader = (_, _, ids) async {
                received = ids;
                return [card];
              };
              final app = await workshop.pumpWorkshop(
                tester,
                locale: locale,
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
              var calls = templates.calls.where((c) => c == 'list').length;
              expect(
                find.byKey(const Key('skill-filter-trigger')),
                findsNothing,
              );
              await tester.tap(find.byType(BrowseFilterButton));
              await tester.pumpAndSettle();
              expect(templates.calls.where((c) => c == 'list').length, calls);
              await tester.tap(find.byKey(const Key('skill-filter-trigger')));
              await tester.pumpAndSettle();
              expect(find.text(known), findsWidgets);
              await tester.tap(
                find.byKey(const Key('skill-filter-option-woodworking')),
              );
              await tester.pumpAndSettle();
              expect(received, isNull);
              await tester.tap(find.byKey(const Key('skill-filter-apply')));
              await tester.pumpAndSettle();
              expect(received, {needId(1)});
              expect(app.container.read(templateCatalogProvider).skills, {
                needId(1),
              });
              // Picker-route return retains its existing public revalidation.
              // Collapsing the disclosure itself must add no catalog request.
              calls = templates.calls.where((c) => c == 'list').length;
              await tester.tap(find.byType(BrowseFilterButton));
              await tester.pumpAndSettle();
              expect(
                find.byKey(const Key('skill-filter-trigger')),
                findsNothing,
              );
              expect(templates.calls.where((c) => c == 'list').length, calls);
              await tester.tap(find.byKey(const Key('template-reset-filters')));
              await tester.pumpAndSettle();
              expect(received, isNull);
              expect(
                app.container.read(templateCatalogProvider).skills,
                isEmpty,
              );
              calls = templates.calls.where((c) => c == 'list').length;
              await tester.showKeyboard(
                find.byKey(const Key('template-query')),
              );
              tester.view.viewInsets = const FakeViewPadding(bottom: 280);
              addTearDown(tester.view.resetViewInsets);
              await tester.enterText(
                find.byKey(const Key('template-query')),
                'new query',
              );
              await tester.pump(const Duration(milliseconds: 349));
              expect(templates.calls.where((c) => c == 'list').length, calls);
              await tester.pump(const Duration(milliseconds: 2));
              await tester.pumpAndSettle();
              expect(
                templates.calls.where((c) => c == 'list').length,
                calls + 1,
              );
              expect(
                app.container.read(templateCatalogProvider).query,
                'new query',
              );
              expect(tester.takeException(), isNull);
              tester.testTextInput.hide();
              tester.view.resetViewInsets();
              await tester.tap(find.byKey(const Key('template-reset-filters')));
              await tester.pumpAndSettle();

              templates.applyError = Exception(
                'Synthetic lost acknowledgement',
              );
              final applications = app.container.read(
                templateApplicationsProvider.notifier,
              );
              await applications.use(templateActor, templates.value!, false);
              await tester.pumpAndSettle();
              final attempt = applications.latest(templateActor, templateId)!;
              final notice = find.byKey(
                Key('template-attempt-notice-${attempt.requestId}'),
              );
              await workshop.reveal(tester, notice);
              final bounds = tester.getRect(notice);
              expect(bounds.left, greaterThanOrEqualTo(0));
              expect(bounds.right, lessThanOrEqualTo(width));
              final l = AppLocalizations.of(tester.element(notice));
              expect(find.text(l.workshopPending), findsOneWidget);
              expect(find.text(l.workshopAccepted), findsNothing);
              expect(tester.takeException(), isNull);
              await workshop.reveal(tester, find.text(card.title));
              await tester.tap(find.text(card.title));
              await tester.pumpAndSettle();
              final full = find.text('$known · $priority');
              await workshop.reveal(tester, full);
              expect(
                tester.renderObject<RenderParagraph>(full).didExceedMaxLines,
                isFalse,
              );
              expect(
                find.text(
                  'A new controlled skill with a long canonical label · ${locale == 'it' ? 'Utile' : 'Useful'}',
                ),
                findsOneWidget,
              );
              expect(templates.value!.skills.first.id, needId(1));
              expect(
                templates.value!.skills.first.importance,
                ProposalSkillImportance.required,
              );
              expect(templates.commands, hasLength(1));
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
