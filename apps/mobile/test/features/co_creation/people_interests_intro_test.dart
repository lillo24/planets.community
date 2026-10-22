import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/co_creation/data/people_intro_preference.dart';
import 'package:planets_mobile/features/co_creation/data/people_posts_gateway.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_browse_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_entry_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_interests_intro.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/settings/application/co_creation_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/co_creation_preference.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/rendered_evidence.dart';
import '../../support/fake_auth.dart';
import '../../support/fake_proposal.dart';

class MemoryIntroStore implements PeopleIntroPreferenceStore {
  bool seen = false, failRead = false, failWrite = false;
  int reads = 0, writes = 0;
  Completer<bool>? pendingRead;
  @override
  Future<bool> readSeen() async {
    reads++;
    if (failRead) throw StateError('Synthetic read failure');
    return pendingRead == null ? seen : pendingRead!.future;
  }

  @override
  Future<void> markSeen() async {
    writes++;
    if (failWrite) throw StateError('Synthetic write failure');
    seen = true;
  }
}

class SandboxController extends CoCreationPreferenceController {
  SandboxController(this.enabled);
  final bool enabled;
  @override
  CoCreationPreferenceState build() => CoCreationPreferenceState(
    mode: enabled ? CoCreationMode.on : CoCreationMode.off,
  );
  void change(bool enabled) => state = CoCreationPreferenceState(
    mode: enabled ? CoCreationMode.on : CoCreationMode.off,
  );
}

Widget app(
  Widget child, {
  String language = 'en',
  bool dark = false,
  double scale = 1,
  bool reduced = false,
}) => RenderedEvidence.wrap(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.dark : AppTheme.light,
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reduced,
      ),
      child: child!,
    ),
    home: child,
  ),
);

double labels(WidgetTester tester, int i) =>
    tester.widget<Opacity>(find.byKey(Key('interest-labels-$i'))).opacity;

void size(WidgetTester tester, {double height = 740}) {
  tester.view.physicalSize = Size(320, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class BrowseFixture extends StatelessWidget {
  const BrowseFixture({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        IconButton(
          tooltip: AppLocalizations.of(context).coIntroReplay,
          onPressed: () => context.push('/people/intro'),
          icon: const Icon(Icons.info_outline),
        ),
      ],
    ),
    body: ListView(children: const [TextField(key: Key('browse-filter'))]),
  );
}

Future<(ProviderContainer, GoRouter)> entry(
  WidgetTester tester,
  MemoryIntroStore store, {
  String path = '/people',
  bool enabled = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      peopleIntroPreferenceStoreProvider.overrideWithValue(store),
      coCreationPreferenceProvider.overrideWith(
        () => SandboxController(enabled),
      ),
    ],
  );
  final router = GoRouter(
    initialLocation: path,
    redirect: (_, state) =>
        state.uri.path.startsWith('/people') &&
            !container.read(coCreationPreferenceProvider).enabled
        ? '/'
        : null,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/people',
        builder: (_, state) => PeopleEntryScreen(
          ordinaryEntry: state.uri.path == '/people' && !state.uri.hasQuery,
          child: const BrowseFixture(),
        ),
        routes: [
          GoRoute(
            path: 'intro',
            builder: (context, _) => PeopleInterestsIntro(
              onExplore: () => context.pop(),
              onClose: () => context.pop(),
            ),
          ),
          GoRoute(
            path: 'compose',
            builder: (_, _) => const Scaffold(body: Text('Protected composer')),
          ),
        ],
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  return (container, router);
}

void main() {
  setUpAll(() => RenderedEvidence.loadFonts(force: true));

  testWidgets(
    'actual app router preserves live filters on replay and gates OFF mid-view',
    (tester) async {
      final auth = FakeAuthGateway();
      addTearDown(auth.close);
      var enabled = true;
      final store = MemoryIntroStore();
      final router = createAppRouter(
        initialLocation: '/people',
        readCoCreation: () => enabled,
        readPolicyAccepted: () => true,
      );
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              appEnvironment: 'local',
              supabaseUrl: 'http://127.0.0.1:54321',
              supabasePublishableKey: 'test-key',
            ),
          ),
          appRouterProvider.overrideWithValue(router),
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(
            FakeProfileAnchorGateway(),
          ),
          proposalGatewayProvider.overrideWithValue(FakeProposalGateway()),
          peopleIntroPreferenceStoreProvider.overrideWithValue(store),
          coCreationPreferenceProvider.overrideWith(
            () => SandboxController(true),
          ),
          peoplePostsGatewayProvider.overrideWithValue(
            PeoplePostsGateway((name, _) async {
                if (name == 'get_cocreate_availability') {
                return {'enabled': false};
                }
              throw StateError('Unexpected VIS01 domain call: $name');
            }),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PlanetsApp(),
        ),
      );
      await tester.pump();
      expect(find.byType(PeopleInterestsIntro), findsOneWidget);
      await tester.tap(find.byKey(const Key('people-intro-explore')));
      await tester.pumpAndSettle();
      expect(find.byType(PeopleBrowseScreen), findsOneWidget);
      expect(
        find.text('The co-creation experiment is unavailable.'),
        findsWidgets,
      );
      await tester.enterText(find.byType(TextField).first, 'Trento games');
      await tester.tap(find.byTooltip('Replay intro'));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/people/intro');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Trento games'), findsOneWidget);
      await tester.tap(find.byTooltip('Replay intro'));
      await tester.pump();
      enabled = false;
      (container.read(
        coCreationPreferenceProvider.notifier,
      ) as SandboxController).change(false);
      router.refresh();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/proposals');
      expect(find.byType(PeopleInterestsIntro), findsNothing);
      expect(store.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'six-second initial, staggered and settled frames never navigate or loop',
    (tester) async {
      size(tester);
      var exits = 0;
      await tester.pumpWidget(
        app(PeopleInterestsIntro(onExplore: () => exits++, onClose: () {})),
      );
      await tester.pump();
      expect(labels(tester, 0), 0);
      expect(labels(tester, 1), 0);
      expect(
        find.byKey(const Key('people-intro-skip')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('people-intro-explore')).hitTestable(),
        findsOneWidget,
      );
      await RenderedEvidence.capture(tester, 'intro-en-light-initial');
      await tester.pump(const Duration(milliseconds: 1800));
      expect(labels(tester, 0), inExclusiveRange(0, 1));
      expect(labels(tester, 1), 0);
      await RenderedEvidence.capture(tester, 'intro-en-light-in-flight');
      await tester.pump(const Duration(milliseconds: 4200));
      for (var i = 0; i < 3; i++) {
        expect(labels(tester, i), 1);
      }
      await RenderedEvidence.capture(tester, 'intro-en-light-settled');
      expect(exits, 0);
      await tester.pump(const Duration(seconds: 30));
      expect(tester.binding.transientCallbackCount, 0);
      expect(exits, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  for (final button in ['skip', 'explore']) {
    testWidgets('$button works from first frame and mid animation', (
      tester,
    ) async {
      var exits = 0;
      await tester.pumpWidget(
        app(PeopleInterestsIntro(onExplore: () => exits++, onClose: () {})),
      );
      await tester.tap(find.byKey(Key('people-intro-$button')));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byKey(Key('people-intro-$button')));
      expect(exits, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'background and TickerMode pause phase and resume without time jumps',
    (tester) async {
      Widget scene(bool enabled) => app(
        TickerMode(
          enabled: enabled,
          child: PeopleInterestsIntro(onExplore: () {}, onClose: () {}),
        ),
      );
      await tester.pumpWidget(scene(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));
      final before = labels(tester, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      expect(labels(tester, 0), before);
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(labels(tester, 0), greaterThan(before));
      final resumed = labels(tester, 0);
      await tester.pumpWidget(scene(false));
      await tester.pump(const Duration(seconds: 20));
      expect(labels(tester, 0), resumed);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(scene(true));
      await tester.pumpAndSettle();
      expect(labels(tester, 2), 1);
    },
  );

  testWidgets('a covering popup pauses the intro and Back resumes it', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(PeopleInterestsIntro(onExplore: () {}, onClose: () {})),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    final context = tester.element(find.byType(PeopleInterestsIntro));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('Covered')),
      ),
    );
    await tester.pump();
    final paused = labels(tester, 0);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    expect(labels(tester, 0), paused);
    expect(tester.binding.transientCallbackCount, 0);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(labels(tester, 2), 1);
  });

  for (final language in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'static $language dark=$dark 320x480 scale=$scale remains readable and actionable',
          (tester) async {
            size(tester, height: 480);
            final semantics = tester.ensureSemantics();
            await tester.pumpWidget(
              app(
                PeopleInterestsIntro(onExplore: () {}, onClose: () {}),
                language: language,
                dark: dark,
                scale: scale,
                reduced: true,
              ),
            );
            await tester.pumpAndSettle();
            for (var i = 0; i < 3; i++) {
              expect(labels(tester, i), 1);
            }
            expect(tester.binding.transientCallbackCount, 0);
            expect(
              find.byKey(const Key('people-intro-skip')).hitTestable(),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('people-intro-explore')).hitTestable(),
              findsOneWidget,
            );
            expect(
              find.bySemanticsLabel(
                RegExp(
                  language == 'it' ? 'Tre pianeti' : 'Three interest planets',
                ),
              ),
              findsOneWidget,
            );
            expect(find.bySemanticsLabel('Valorant'), findsNothing);
            await tester.ensureVisible(find.text('Valorant'));
            await tester.pumpAndSettle();
            expect(find.text('Valorant').hitTestable(), findsOneWidget);
            await RenderedEvidence.capture(
              tester,
              'intro-$language-$dark-${scale}x-static',
            );
            expect(tester.takeException(), isNull);
            semantics.dispose();
          },
        );
      }
    }
  }

  testWidgets(
    'first ordinary entry persists seen; subsequent entry and OFF→ON do not repeat',
    (tester) async {
      final store = MemoryIntroStore();
      final (_, router) = await entry(tester, store);
      expect(find.byType(PeopleInterestsIntro), findsOneWidget);
      expect(store.seen, isTrue);
      expect(store.writes, 1);
      await tester.tap(find.byKey(const Key('people-intro-skip')));
      await tester.pumpAndSettle();
      expect(find.byType(BrowseFixture), findsOneWidget);
      router.go('/');
      await tester.pumpAndSettle();
      router.go('/people');
      await tester.pumpAndSettle();
      expect(find.byType(PeopleInterestsIntro), findsNothing);
      expect(store.writes, 1);
      // A fresh container models an app restart and restores the disk value.
      await entry(tester, store);
      await tester.pumpAndSettle();
      expect(find.byType(PeopleInterestsIntro), findsNothing);
    },
  );

  testWidgets('replay Explore, Skip and Back preserve browse filters', (
    tester,
  ) async {
    final store = MemoryIntroStore()..seen = true;
    final (_, router) = await entry(tester, store);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('browse-filter')),
      'Trento games',
    );
    for (final action in ['skip', 'explore', 'back']) {
      await tester.tap(find.byTooltip('Replay intro'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PeopleInterestsIntro), findsOneWidget);
      if (action == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byKey(Key('people-intro-$action')));
      }
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/people');
      expect(find.text('Trento games'), findsOneWidget);
    }
    expect(store.writes, 0);
  });

  for (final path in [
    '/people/compose',
    '/people?returnTo=%2Fpeople%2Fcompose',
  ]) {
    testWidgets('$path does not claim or interrupt a protected destination', (
      tester,
    ) async {
      final store = MemoryIntroStore();
      await entry(tester, store, path: path);
      await tester.pumpAndSettle();
      expect(find.byType(PeopleInterestsIntro), findsNothing);
      expect(store.reads, 0);
      expect(store.writes, 0);
    });
  }

  testWidgets(
    'navigation away during preference restore does not open a stale intro',
    (tester) async {
      final pending = Completer<bool>();
      final store = MemoryIntroStore()..pendingRead = pending;
      final (_, router) = await entry(tester, store);
      router.go('/people/compose');
      await tester.pump();
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Protected composer'), findsOneWidget);
      expect(find.byType(PeopleInterestsIntro), findsNothing);
      expect(store.writes, 0);
    },
  );

  for (final replay in [false, true]) {
    testWidgets(
      'OFF mid-view replay=$replay leaves no intro route and preserves seen',
      (tester) async {
        final store = MemoryIntroStore()..seen = replay;
        final (container, router) = await entry(tester, store);
        if (replay) {
          await tester.pumpAndSettle();
          router.push('/people/intro');
        }
        await tester.pump();
        (container.read(
          coCreationPreferenceProvider.notifier,
        ) as SandboxController).change(false);
        router.refresh();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(find.byType(PeopleInterestsIntro), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
        expect(store.seen, isTrue);
        expect(tester.takeException(), isNull);
        (container.read(
          coCreationPreferenceProvider.notifier,
        ) as SandboxController).change(true);
        router.go('/people');
        await tester.pumpAndSettle();
        expect(find.byType(PeopleInterestsIntro), findsNothing);
      },
    );
  }

  testWidgets('automatic Close returns Home without trapping navigation', (
    tester,
  ) async {
    final (_, router) = await entry(tester, MemoryIntroStore());
    await tester.tap(find.byKey(const Key('page-close')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  for (final readFailure in [false, true]) {
    testWidgets(
      'storage failure read=$readFailure is explicit and browsing remains usable',
      (tester) async {
        final store = MemoryIntroStore()
          ..failRead = readFailure
          ..failWrite = !readFailure;
        await entry(tester, store);
        await tester.pump();
        expect(find.textContaining('Could not save or read'), findsOneWidget);
        if (!readFailure) {
          await tester.tap(find.byKey(const Key('people-intro-explore')));
        }
        await tester.pumpAndSettle();
        expect(find.byType(BrowseFixture), findsOneWidget);
        expect(store.seen, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
