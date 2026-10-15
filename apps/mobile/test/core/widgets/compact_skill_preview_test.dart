import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/core/widgets/compact_skill_preview.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  for (final locale in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('one row $locale $dark $width ${scale}x', (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              await tester.binding.setSurfaceSize(Size(width, 900));
              addTearDown(() => tester.binding.setSurfaceSize(null));
              for (final labels in <List<String>>[
                [],
                ['Art'],
                ['Art', 'Music'],
                ['Art', 'Music', 'Care'],
                [
                  'Woodworking',
                  'Gardening',
                  'Basic repairs',
                  'Facilitation',
                  'Music',
                ],
                [
                  'An extremely long skill name that cannot fit on a narrow card',
                ],
                [
                  'An extremely long skill name that cannot fit on a narrow card',
                  'Art',
                ],
              ]) {
                var taps = 0;
                await tester.pumpWidget(
                  MaterialApp(
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
                      body: Padding(
                        padding: const EdgeInsets.all(24),
                        child: InkWell(
                          onTap: () => taps++,
                          child: CompactSkillPreview(labels: labels),
                        ),
                      ),
                    ),
                  ),
                );
                await tester
                    .pump(); // No post-frame multirow-to-single-row change.
                expect(tester.takeException(), isNull);
                if (labels.isEmpty) {
                  expect(
                    find.byKey(const Key('compact-skill-row')),
                    findsNothing,
                  );
                  continue;
                }
                final texts = find.descendant(
                  of: find.byType(CompactSkillPreview),
                  matching: find.byType(Text),
                );
                final widgets = tester.widgetList<Text>(texts).toList();
                final visible = widgets.where((w) => w.data != '...').length;
                expect(visible, inInclusiveRange(1, 3));
                expect(
                  find.text('...'),
                  visible < labels.length ? findsOneWidget : findsNothing,
                );
                expect(
                  widgets.where((w) => w.data != '...').map((w) => w.data),
                  labels.take(visible),
                );
                final row = tester.getRect(
                  find.byKey(const Key('compact-skill-row')),
                );
                final tops = <double>[];
                for (final text in texts.evaluate()) {
                  final finder = find.byWidget(text.widget);
                  final rect = tester.getRect(finder);
                  tops.add(rect.top);
                  expect(rect.left, greaterThanOrEqualTo(row.left));
                  expect(rect.right, lessThanOrEqualTo(row.right + .01));
                  final render = tester.renderObject<RenderParagraph>(finder);
                  expect(render.maxLines, 1);
                  expect(render.textScaler.scale(14), scale * 14);
                }
                expect(tops.toSet().length, 1);
                if (visible < labels.length) {
                  expect(
                    tester.getSemantics(find.text('...')).label,
                    contains('${labels.length - visible}'),
                  );
                  await tester.tap(find.text('...'));
                } else {
                  expect(
                    tester.getSemantics(find.text(labels.first)).label,
                    contains(labels.first),
                  );
                  await tester.tap(find.text(labels.first));
                }
                expect(taps, 1);
                final height = tester
                    .getSize(find.byType(CompactSkillPreview))
                    .height;
                await tester.pumpAndSettle();
                expect(
                  tester.getSize(find.byType(CompactSkillPreview)).height,
                  height,
                );
                expect(tester.takeException(), isNull);
              }
            } finally {
              semantics.dispose();
            }
          });
        }
      }
    }
  }
}
