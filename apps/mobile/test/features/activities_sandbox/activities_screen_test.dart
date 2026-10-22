import 'package:planets_mobile/features/activities_sandbox/domain/activity_example.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/activity_interest/application/activity_interest_tracker.dart';

import '../../support/fake_activity_interest.dart';

import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/activities_sandbox/presentation/activities_screen.dart';
import 'package:planets_mobile/features/activities_sandbox/presentation/activity_example_detail_screen.dart';
import 'package:planets_mobile/features/settings/application/activities_split_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/activities_split_preference.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/rendered_evidence.dart';

void main() {
  setUpAll(() => RenderedEvidence.loadFonts(force: true));

  for (final language in ['en', 'it']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$language 320dp ${scale}x categories and discipline intersect search accessibly',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final interestSink = MemoryActivityInterestSink();
          final tracker = memoryActivityInterestTracker(interestSink);
          addTearDown(tracker.dispose);
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final router = GoRouter(
            initialLocation: '/activities',
            routes: [
              GoRoute(
                path: '/activities',
                builder: (_, _) => const ActivitiesScreen(),
                routes: [
                  GoRoute(
                    path: 'examples/:id',
                    builder: (_, state) => ActivityExampleDetailScreen(
                      exampleId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                activityInterestTrackerProvider.overrideWithValue(tracker),
                initialActivitiesSplitPreferenceProvider.overrideWithValue(
                  const ActivitiesSplitPreferenceState(
                    mode: ActivitiesSplitMode.on,
                  ),
                ),
              ],
              child: RenderedEvidence.wrap(
                MaterialApp.router(
                  theme: AppTheme.light,
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  routerConfig: router,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await RenderedEvidence.capture(
            tester,
            'activities-$language-320-${scale}x',
          );
          final sports = find.byKey(const Key('activities-category-sports'));
          await tester.ensureVisible(sports);
          await tester.tap(sports);
          await tester.pumpAndSettle();
          expect(tester.widget<ChoiceChip>(sports).selected, isTrue);
          expect(
            tester.getSemantics(sports),
            isSemantics(isSelected: true, hasSelectedState: true),
          );
          semantics.dispose();
          expect(
            find.byKey(const Key('activities-native-tavoli')),
            findsNothing,
          );
          final dropdown = find.byType(
            DropdownButtonFormField<ExampleDiscipline?>,
          );
          await tester.scrollUntilVisible(
            dropdown,
            200,
            scrollable: _listScrollable(),
          );
          await tester.pumpAndSettle();
          await tester.tap(dropdown);
          await tester.pumpAndSettle();
          final running = find
              .text(language == 'it' ? 'Corsa' : 'Running')
              .last;
          await tester.ensureVisible(running);
          await tester.tap(running);
          await tester.pumpAndSettle();
          final search = find.byKey(const Key('activities-example-search'));
          tester.state<ScrollableState>(_listScrollable()).position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            search,
            200,
            scrollable: _listScrollable(),
          );
          await tester.enterText(
            search,
            language == 'it' ? 'sentieri' : 'trail',
          );
          await tester.pumpAndSettle();
          final item = find.byKey(const Key('example-trail'));
          await tester.scrollUntilVisible(
            item,
            200,
            scrollable: _listScrollable(),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('example-running')), findsNothing);
          await RenderedEvidence.capture(
            tester,
            'sports-$language-320-${scale}x',
          );
          await tester.tap(item);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text(language == 'it' ? 'Evento singolo' : 'Single event'),
            200,
            scrollable: _listScrollable(),
          );
          expect(
            find.text(language == 'it' ? 'Evento singolo' : 'Single event'),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.text(
              language == 'it'
                  ? '28 novembre 2026 · 09:00–11:00'
                  : '28 Nov 2026 · 09:00–11:00',
            ),
            200,
            scrollable: _listScrollable(),
          );
          expect(
            find.text(
              language == 'it'
                  ? '28 novembre 2026 · 09:00–11:00'
                  : '28 Nov 2026 · 09:00–11:00',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          router.pop();
          await tester.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          tester.state<ScrollableState>(_listScrollable()).position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            search,
            200,
            scrollable: _listScrollable(),
          );
          expect(
            tester.widget<TextField>(search).controller!.text,
            language == 'it' ? 'sentieri' : 'trail',
          );
          await tester.scrollUntilVisible(
            dropdown,
            200,
            scrollable: _listScrollable(),
          );
          expect(
            tester
                .widget<DropdownButtonFormField<ExampleDiscipline?>>(dropdown)
                .initialValue,
            ExampleDiscipline.running,
          );
          expect(tester.takeException(), isNull);
          expect(interestSink.events, isEmpty);
        },
      );
    }
  }
}

Finder _listScrollable() => find
    .descendant(
      of: find.byType(ListView).hitTestable().first,
      matching: find.byType(Scrollable),
    )
    .first;
