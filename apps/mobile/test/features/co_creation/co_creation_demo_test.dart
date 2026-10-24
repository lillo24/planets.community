import 'package:flutter/material.dart';

import 'dart:ui' show Tristate;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/app/foundation_screen.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_demo_screens.dart';
import 'package:planets_mobile/features/settings/application/activities_split_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/activities_split_preference.dart';
import 'package:planets_mobile/features/settings/application/co_creation_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/co_creation_preference_store.dart';
import 'package:planets_mobile/features/settings/data/activities_split_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/co_creation_preference.dart';
import 'package:planets_mobile/features/settings/presentation/co_creation_setting.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_settings.dart';
import '../../support/rendered_evidence.dart';

class Session extends AuthSessionController {
  @override
  AuthSessionState build() => const AuthSessionState.signedOut();
  void change(String id) =>
      state = AuthSessionState.ready(AuthIdentity(id: id));
}

void main() {
  setUpAll(() => RenderedEvidence.loadFonts(force: true));
  for (final language in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'Co-Creation Home 320dp ${scale}x $language dark=$dark has three intentions',
          (tester) async {
            tester.view.physicalSize = Size(320, scale == 1 ? 740 : 480);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final router = GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const FoundationScreen()),
                for (final path in [
                  '/people',
                  '/people/hubs',
                  '/proposals',
                  '/resources',
                ])
                  GoRoute(
                    path: path,
                    builder: (_, _) => Scaffold(body: Text(path)),
                  ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  initialCoCreationPreferenceProvider.overrideWithValue(
                    const CoCreationPreferenceState(mode: CoCreationMode.on),
                  ),
                  initialActivitiesSplitPreferenceProvider.overrideWithValue(
                    const ActivitiesSplitPreferenceState(
                      mode: ActivitiesSplitMode.on,
                    ),
                  ),
                  authSessionProvider.overrideWith(Session.new),
                ],
                child: RenderedEvidence.wrap(
                  MaterialApp.router(
                    routerConfig: router,
                    theme: dark ? AppTheme.dark : AppTheme.light,
                    locale: Locale(language),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        disableAnimations: true,
                      ),
                      child: child!,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(Card), findsNWidgets(3));
            expect(
              find.text(
                language == 'it' ? 'Trova le tue persone' : 'Find your people',
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                language == 'it' ? 'Trova attività' : 'Find activities',
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                language == 'it'
                    ? 'Proponi una comunità'
                    : 'Propose a community',
              ),
              findsOneWidget,
            );
            expect(find.byKey(const Key('crazy-ideas-button')), findsNothing);
            expect(
              find.byKey(const Key('browse-proposals-button')),
              findsNothing,
            );
            expect(
              find.byKey(const Key('browse-resources-button')),
              findsNothing,
            );
            final semantics = tester.ensureSemantics();
            for (final entry in {
              'browse-people-button': '/people',
              'find-activities-button': '/proposals',
              'propose-community-button': '/people/hubs',
            }.entries) {
              final card = find.byKey(Key(entry.key));
              await tester.ensureVisible(card);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              if (entry.key == 'browse-people-button') {
                await RenderedEvidence.capture(
                  tester,
                  'peoplehome01-home-$language-$dark-${scale}x',
                );
              }
              expect(
                tester.getSemantics(card).flagsCollection.isEnabled,
                Tristate.isTrue,
              );
              await tester.tap(card);
              await tester.pumpAndSettle();
              expect(router.routerDelegate.state.uri.path, entry.value);
              router.go('/');
              await tester.pumpAndSettle();
            }
            expect(
              find.byKey(const Key('browse-activities-button')),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
            semantics.dispose();
          },
        );
      }
    }
  }
  for (final language in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('demo navigation $language dark=$dark 320dp scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final router = GoRouter(
            initialLocation: '/people',
            routes: [
              GoRoute(
                path: '/people',
                builder: (_, _) => const CoCreationDemoBrowseScreen(),
                routes: [
                  GoRoute(
                    path: 'demo/hubs/:id',
                    builder: (_, s) =>
                        CoCreationDemoHubScreen(id: s.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'general',
                        builder: (_, s) => CoCreationDemoRoomScreen(
                          hubId: s.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'groups/:number',
                        builder: (_, s) => CoCreationDemoRoomScreen(
                          hubId: s.pathParameters['id']!,
                          number: int.parse(s.pathParameters['number']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                initialCoCreationPreferenceProvider.overrideWithValue(
                  const CoCreationPreferenceState(mode: CoCreationMode.on),
                ),
              ],
              child: RenderedEvidence.wrap(
                MaterialApp.router(
                  routerConfig: router,
                  theme: dark ? AppTheme.dark : AppTheme.light,
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await RenderedEvidence.capture(
            tester,
            'cocreate-posts-$language-$dark-$scale',
          );
          final community = find.text(
            language == 'it' ? 'Comunità' : 'Communities',
          );
          await tester.ensureVisible(community);
          await tester.tap(community);
          await tester.pumpAndSettle();
          final hub = find.byKey(const Key('demo-football'));
          await tester.scrollUntilVisible(
            hub,
            200,
            scrollable: _listScrollable(),
          );
          await tester.tap(hub);
          await tester.pumpAndSettle();
          expect(
            find.text(language == 'it' ? 'Calcetto' : 'Five-a-side football'),
            findsOneWidget,
          );
          final group = find.byKey(const Key('demo-group-2'));
          await tester.scrollUntilVisible(
            group,
            200,
            scrollable: _listScrollable(),
          );
          await tester.ensureVisible(group);
          await tester.pumpAndSettle();
          await RenderedEvidence.capture(
            tester,
            'cocreate-hub-$language-$dark-$scale',
          );
          await tester.tap(group);
          await tester.pumpAndSettle();
          expect(
            find.text(language == 'it' ? 'Gruppo 2' : 'Group 2'),
            findsOneWidget,
          );
          expect(find.byType(TextField), findsNothing);
          await RenderedEvidence.capture(
            tester,
            'cocreate-room-$language-$dark-$scale',
          );
          router.pop();
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('demo-group-2')), findsOneWidget);
          router.pop();
          await tester.pumpAndSettle();
          final search = find.byKey(const Key('co-creation-search'));
          await tester.ensureVisible(search);
          await tester.enterText(search, 'zz-no-fixture');
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('demo-football')), findsNothing);
          expect(
            find.text(
              language == 'it'
                  ? 'Nessun esempio corrispondente. Cambia ricerca o tema.'
                  : 'No matching examples. Change the search or topic.',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
    'composer is ephemeral, never publishes and clears on account change',
    (tester) async {
      final app = ProviderContainer(
        overrides: [
          initialCoCreationPreferenceProvider.overrideWithValue(
            const CoCreationPreferenceState(mode: CoCreationMode.on),
          ),
          authSessionProvider.overrideWith(Session.new),
        ],
      );
      addTearDown(app.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: app,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CoCreationDemoComposer(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final entry in {
        'demo-post-title': 'Test title',
        'demo-post-body': 'Fictional body',
        'demo-post-locality': 'Trento',
      }.entries) {
        final field = find.byKey(Key(entry.key));
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      final preview = find.byKey(const Key('demo-post-preview'));
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(find.text('Local preview · not published'), findsOneWidget);
      (app.read(authSessionProvider.notifier) as Session).change('account-b');
      await tester.pumpAndSettle();
      expect(find.text('Local preview · not published'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('demo-post-title')))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mode precedence preserves split and tutorial baseline', (
    tester,
  ) async {
    final store = FakeCoCreationPreferenceStore();
    final app = ProviderContainer(
      overrides: [
        initialCoCreationPreferenceProvider.overrideWithValue(
          const CoCreationPreferenceState(mode: CoCreationMode.on),
        ),
        initialActivitiesSplitPreferenceProvider.overrideWithValue(
          const ActivitiesSplitPreferenceState(mode: ActivitiesSplitMode.on),
        ),
        coCreationPreferenceStoreProvider.overrideWithValue(store),
        authSessionProvider.overrideWith(Session.new),
      ],
    );
    addTearDown(app.dispose);
    Future<void> show({bool tutorial = false}) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: app,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: FoundationScreen(
              activitiesSplitPreview: tutorial ? false : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show();
    expect(find.byKey(const Key('browse-people-button')), findsOneWidget);
    expect(find.byKey(const Key('browse-activities-button')), findsNothing);
    await show(tutorial: true);
    expect(find.byKey(const Key('browse-people-button')), findsNothing);
    expect(find.byKey(const Key('browse-activities-button')), findsNothing);
    await app
        .read(coCreationPreferenceProvider.notifier)
        .select(CoCreationMode.off);
    await show();
    expect(find.byKey(const Key('browse-activities-button')), findsOneWidget);
    expect(app.read(activitiesSplitPreferenceProvider).enabled, isTrue);
  });

  testWidgets(
    'setting reports failed save and retries without optimistic success',
    (tester) async {
      final store = FakeCoCreationPreferenceStore()
        ..writeError = StateError('disk');
      final app = ProviderContainer(
        overrides: [
          coCreationPreferenceStoreProvider.overrideWithValue(store),
          activitiesSplitPreferenceStoreProvider.overrideWithValue(
            FakeActivitiesSplitPreferenceStore(),
          ),
        ],
      );
      addTearDown(app.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: app,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: CoCreationSetting()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(app.read(coCreationPreferenceProvider).enabled, isFalse);
      expect(find.byKey(const Key('co-creation-error')), findsOneWidget);
      store.writeError = null;
      await tester.tap(find.byKey(const Key('co-creation-retry')));
      await tester.pumpAndSettle();
      expect(app.read(coCreationPreferenceProvider).enabled, isTrue);
    },
  );
}

Finder _listScrollable() => find
    .descendant(
      of: find.byType(ListView).hitTestable().first,
      matching: find.byType(Scrollable),
    )
    .first;
