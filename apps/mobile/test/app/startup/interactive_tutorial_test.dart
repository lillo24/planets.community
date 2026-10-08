import 'package:planets_mobile/features/settings/data/language_preference_store.dart';

import '../../support/fake_settings.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/settings/application/navigation_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/navigation_preference.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_startup.dart';
import '../../support/fake_messages.dart';
import '../../support/fake_message_chats.dart';
import '../../support/fake_notifications.dart';
import '../../support/fake_profile.dart';

import 'package:planets_mobile/app/startup/tutorial_presentation.dart';
import 'package:planets_mobile/app/startup/tutorial_routes.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';

import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

import '../../support/fake_proposal.dart';
import '../../support/fake_resource_listing.dart';
import '../../support/fake_profile_photo.dart';
import '../../support/fake_project_resource_needs.dart';

void main() {
  testWidgets(
    'changing locale and text size preserves stage and rearms focus safely',
    (tester) async {
      final store = FakeStartupStore();
      final app = await _pump(tester, store: store);
      await tap(tester, 'welcome-explore');
      await tap(tester, 'tutorial-next');
      await ready(tester);
      await app
          .read(languagePreferenceProvider.notifier)
          .select(LanguagePreference.italian);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await frames(tester, 3);
      await ready(tester);
      expect(find.byKey(const Key('tutorial-copy-home')), findsOneWidget);
      expect(
        find.text('Scopri cosa stanno organizzando le persone vicino a te.'),
        findsOneWidget,
      );
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real resource example and Create are highlighted without opening an editor',
    (tester) async {
      final resources = FakeResourceListingGateway()
        ..publicItems = [publicResourceListingFixture()];
      final app = await _pump(tester, resources: resources);
      await tap(tester, 'welcome-explore');
      for (var i = 0; i < 9; i++) {
        await tap(tester, 'tutorial-next');
      }
      await ready(tester);
      expect(
        find.byKey(const Key('tutorial-illustration-label')),
        findsNothing,
      );
      expect(find.text('Garden tools'), findsOneWidget);
      await tap(tester, 'tutorial-next');
      await ready(tester);
      final target =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('tutorial-spotlight')),
                  )
                  .painter!
              as TutorialScrim;
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const Key('tutorial-overlay'))) +
            target.target!.center,
      );
      await frames(tester, 6);
      expect(
        find.byKey(const Key('tutorial-copy-resourceDrafts')),
        findsOneWidget,
      );
      expect(
        app.read(appRouterProvider).routerDelegate.state.uri.path,
        '/intro',
      );
      expect(resources.createCount, 0);
    },
  );
  testWidgets(
    'automatic production playback reaches farewell without saving until CTA',
    (tester) async {
      final store = FakeStartupStore();
      await _pump(tester, store: store);
      await tap(tester, 'welcome-explore');
      for (final step in TutorialStep.values) {
        expect(find.byKey(Key('tutorial-copy-${step.name}')), findsOneWidget);
        await ready(tester);
        if (step == TutorialStep.farewell) break;
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
      }
      expect(store.writes, 0);
      await frames(tester, 5);
      await tap(tester, 'tutorial-next');
      expect(store.version, 'interactive-1');
    },
  );
  testWidgets(
    'production first Explore shows tour, Skip stores dismissal and prevents replay',
    (tester) async {
      final store = FakeStartupStore();
      final app = await _pump(tester, store: store);
      await tap(tester, 'welcome-explore');
      expect(
        find.byKey(const Key('tutorial-copy-introduction')),
        findsOneWidget,
      );
      expect(store.writes, 0);
      await tap(tester, 'tutorial-skip');
      expect(store.version, 'dismissed:interactive-1');
      expect(
        app.read(startupFlowProvider).preference.dismissedVersion,
        'interactive-1',
      );
      expect(app.read(startupFlowProvider).needsTutorial, isFalse);
      expect(find.byKey(const Key('browse-proposals-button')), findsOneWidget);
    },
  );
  testWidgets(
    'whole empty/offline guest tour has visible spotlights and no product mutations',
    (tester) async {
      final store = FakeStartupStore();
      final projects = FakeProposalGateway();
      final resources = FakeResourceListingGateway();
      final chats = FakeMessageChatsGateway();
      final messages = FakeMessagesGateway();
      await _pump(
        tester,
        store: store,
        proposals: projects,
        resources: resources,
        chats: chats,
        messages: messages,
      );
      await tap(tester, 'welcome-explore');
      for (final step in TutorialStep.values) {
        expect(find.byKey(Key('tutorial-copy-${step.name}')), findsOneWidget);
        await ready(tester);
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.byKey(const Key('tutorial-spotlight')),
                    )
                    .painter!
                as TutorialScrim;
        expect(painter.target, isNotNull, reason: step.name);
        if (const {
          TutorialStep.projectCard,
          TutorialStep.projectPurpose,
          TutorialStep.projectNeeds,
          TutorialStep.projectParticipation,
          TutorialStep.resourceCard,
        }.contains(step)) {
          expect(
            find.byKey(const Key('tutorial-illustration-label')),
            findsOneWidget,
          );
        }
        expect(store.writes, 0);
        await tap(tester, 'tutorial-next');
      }
      expect(store.version, 'interactive-1');
      expect(find.byKey(const Key('tutorial-screen')), findsNothing);
      expect(
        projects.calls.every(
          (c) => c.startsWith('list-public') || c.startsWith('public-detail'),
        ),
        isTrue,
      );
      expect(resources.createCount, 0);
      expect(chats.calls, isEmpty);
      expect(messages.calls, isEmpty);
    },
  );
  testWidgets(
    'real eligible card and detail scroll use canonical public data without Join tap-through',
    (tester) async {
      final projects = FakeProposalGateway()
        ..publicItems = [
          proposalSummaryFixture(
            id: 'closed',
            status: ProposalStatus.completed,
          ),
          proposalSummaryFixture(),
        ]
        ..publicDetail = proposalDetailFixture();
      final needs = FakeProjectResourceNeedsGateway()
        ..publicItems = [publicProjectResourceNeedFixture()];
      final app = await _pump(tester, proposals: projects, needs: needs);
      await tap(tester, 'welcome-explore');
      await tap(tester, 'tutorial-next');
      await tap(tester, 'tutorial-next');
      await ready(tester);
      expect(
        find.byKey(const Key('proposal-card-title-proposal-1')),
        findsOneWidget,
      );
      await tap(tester, 'tutorial-next');
      await ready(tester);
      expect(
        find.byKey(const Key('tutorial-illustration-label')),
        findsNothing,
      );
      expect(find.byKey(const Key('tutorial-project-purpose')), findsOneWidget);
      await tap(tester, 'tutorial-next');
      await ready(tester);
      expect(find.byKey(const Key('tutorial-project-needs')), findsOneWidget);
      await tap(tester, 'tutorial-next');
      await ready(tester);
      expect(
        find.byKey(const Key('participation-join-proposal-1')),
        findsOneWidget,
      );
      final target =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('tutorial-spotlight')),
                  )
                  .painter!
              as TutorialScrim;
      final surface = tester.getTopLeft(
        find.byKey(const Key('tutorial-overlay')),
      );
      await tester.tapAt(surface + target.target!.center);
      await frames(tester, 6);
      expect(
        find.byKey(const Key('tutorial-copy-projectCreate')),
        findsOneWidget,
      );
      expect(
        app.read(appRouterProvider).routerDelegate.state.uri.path,
        '/intro',
      );
      expect(
        projects.calls.where((c) => c == 'create' || c == 'publish'),
        isEmpty,
      );
      expect(needs.calls.every((c) => c.startsWith('list-public')), isTrue);
    },
  );
  testWidgets(
    'double taps advance once and automatic playback advances once after ready',
    (tester) async {
      await _pump(tester);
      await tap(tester, 'welcome-explore');
      await ready(tester);
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
      expect(find.byKey(const Key('tutorial-copy-home')), findsOneWidget);
      await ready(tester);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(
        find.byKey(const Key('tutorial-copy-projectCard')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'pending content does not consume explanation timer and late data cannot replace fallback',
    (tester) async {
      final pending = Completer<List<ProposalSummary>>();
      final projects = FakeProposalGateway()
        ..publicLoader = ({
          required limit,
          cursor,
          query,
          locality,
          skillIds,
        }) => pending.future;
      await _pump(tester, proposals: projects);
      await tap(tester, 'welcome-explore');
      await tap(tester, 'tutorial-next');
      await tap(tester, 'tutorial-next');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(
        find.byKey(const Key('tutorial-copy-projectCard')),
        findsOneWidget,
      );
      expect(
        (tester
                    .widget<CustomPaint>(
                      find.byKey(const Key('tutorial-spotlight')),
                    )
                    .painter!
                as TutorialScrim)
            .target,
        isNull,
      );
      await ready(tester);
      expect(
        find.byKey(const Key('tutorial-illustration-label')),
        findsOneWidget,
      );
      pending.complete([proposalSummaryFixture()]);
      await frames(tester, 3);
      expect(
        find.byKey(const Key('tutorial-illustration-label')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'background interruption pauses clock without recording status; Back is safe',
    (tester) async {
      final store = FakeStartupStore();
      final app = await _pump(tester, store: store);
      await tap(tester, 'welcome-explore');
      await ready(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      expect(
        find.byKey(const Key('tutorial-copy-introduction')),
        findsOneWidget,
      );
      expect(store.writes, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await app.read(appRouterProvider).routerDelegate.popRoute();
      await frames(tester, 5);
      expect(store.writes, 0);
      expect(app.read(appRouterProvider).routerDelegate.state.uri.path, '/');
    },
  );
  testWidgets(
    'replay after dismissal keeps status and pops to originating Settings on Skip and Back',
    (tester) async {
      final store = FakeStartupStore();
      final app = await _pump(tester, store: store);
      await tap(tester, 'welcome-explore');
      await tap(tester, 'tutorial-skip');
      final router = app.read(appRouterProvider);
      router.go('/settings');
      await frames(tester, 8);
      TutorialRoutes.replay(
        tester.element(find.byKey(const Key('settings-language-row'))),
        returnTo: '/settings',
      );
      await frames(tester, 8);
      expect(find.byKey(const Key('tutorial-screen')), findsOneWidget);
      await tap(tester, 'tutorial-skip');
      expect(router.routerDelegate.state.uri.path, '/settings');
      expect(store.writes, 1);
      TutorialRoutes.replay(
        tester.element(find.byKey(const Key('settings-language-row'))),
        returnTo: '/settings',
      );
      await frames(tester, 5);
      await router.routerDelegate.popRoute();
      await frames(tester, 5);
      expect(router.routerDelegate.state.uri.path, '/settings');
      expect(store.writes, 1);
      router.go('/intro?replay=true&returnTo=/messages');
      await frames(tester, 5);
      expect(find.byKey(const Key('tutorial-screen')), findsNothing);
    },
  );

  for (final language in [
    LanguagePreference.english,
    LanguagePreference.italian,
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'all targets at 320px and 2x text with reduced motion $language dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await _pump(tester, language: language);
          await tap(tester, 'welcome-explore');
          for (final step in TutorialStep.values) {
            await ready(tester);
            expect(
              find.byKey(Key('tutorial-copy-${step.name}')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('tutorial-next')).hitTestable(),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('tutorial-skip')).hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull, reason: step.name);
            await tap(tester, 'tutorial-next');
          }
          expect(find.byKey(const Key('tutorial-screen')), findsNothing);
        },
      );
    }
  }
  testWidgets(
    'ready replay Finish preserves first-run status and never loads conversations',
    (tester) async {
      final store = FakeStartupStore();
      final chats = FakeMessageChatsGateway();
      final messages = FakeMessagesGateway();
      final app = await _pump(
        tester,
        store: store,
        chats: chats,
        messages: messages,
        auth: FakeAuthGateway(
          snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
        ),
      );
      expect(find.byKey(const Key('tutorial-screen')), findsNothing);
      final context = tester.element(
        find.byKey(const Key('browse-proposals-button')),
      );
      TutorialRoutes.replay(context);
      await frames(tester, 6);
      for (final step in TutorialStep.values) {
        await ready(tester);
        if (step == TutorialStep.messagesScopes) {
          expect(
            find.text('Tutorial: your conversations stay private.'),
            findsWidgets,
          );
        }
        await tap(tester, 'tutorial-next');
      }
      expect(store.writes, 0);
      expect(chats.calls, isEmpty);
      expect(messages.calls, isEmpty);
      expect(app.read(startupFlowProvider).needsTutorial, isTrue);
    },
  );
  testWidgets('successful initial Login opens production tutorial', (
    tester,
  ) async {
    final app = await _pump(tester);
    await tap(tester, 'welcome-login');
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.test',
    );
    await tap(tester, 'auth-request-button');
    await tester.enterText(find.byKey(const Key('auth-code-field')), '123456');
    await tap(tester, 'auth-verify-button');
    expect(find.byKey(const Key('tutorial-copy-introduction')), findsOneWidget);
    expect(app.read(authSessionProvider).phase, AuthSessionPhase.ready);
  });
  testWidgets(
    'explicit public journey defers production tutorial and Back never opens protected editor',
    (tester) async {
      final app = await _pump(tester);
      final router = app.read(appRouterProvider);
      router.go('/proposals');
      await frames(tester, 8);
      expect(find.byKey(const Key('tutorial-screen')), findsNothing);
      expect(app.read(startupFlowProvider).tutorialDeferred, isTrue);
      expect(tutorialExitDestination('/proposals/create'), '/proposals');
      expect(tutorialExitDestination('/auth/verify'), '/');
    },
  );
  testWidgets('write failure stays explicit and dismissal retries', (
    tester,
  ) async {
    final store = FakeStartupStore()..failWrite = true;
    final app = await _pump(tester, store: store);
    await tap(tester, 'welcome-explore');
    await tap(tester, 'tutorial-skip');
    expect(find.byKey(const Key('tutorial-write-error')), findsOneWidget);
    expect(app.read(startupFlowProvider).needsTutorial, isTrue);
    store.failWrite = false;
    await tap(tester, 'tutorial-skip');
    expect(app.read(startupFlowProvider).needsTutorial, isFalse);
  });
  testWidgets(
    'account replacement interrupts without saving or opening private conversations',
    (tester) async {
      final auth = FakeAuthGateway();
      final store = FakeStartupStore();
      final chats = FakeMessageChatsGateway();
      await _pump(tester, auth: auth, store: store, chats: chats);
      await tap(tester, 'welcome-explore');
      auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'replacement')));
      await frames(tester, 15);
      expect(find.byKey(const Key('tutorial-screen')), findsNothing);
      expect(store.writes, 0);
      expect(chats.calls, isEmpty);
    },
  );
}

Future<void> frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)).hitTestable());
  await frames(tester, 6);
}

Future<void> ready(WidgetTester tester) async {
  for (var i = 0; i < 65; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    final paint =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('tutorial-spotlight')),
                )
                .painter!
            as TutorialScrim;
    if (paint.target != null) return;
  }
  fail(
    'spotlight never became ready: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join(' | ')}',
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  FakeAuthGateway? auth,
  FakeProfileAnchorGateway? anchor,
  FakeStartupStore? store,
  TutorialRegistry registry = productionTutorial,
  FakeProposalGateway? proposals,
  FakeResourceListingGateway? resources,
  FakeProjectResourceNeedsGateway? needs,
  LanguagePreference language = LanguagePreference.english,
  FakeMessagesGateway? messages,
  FakeMessageChatsGateway? chats,
  BottomTabDestination destination = BottomTabDestination.messages,
  bool settle = true,
}) async {
  final gateway = auth ?? FakeAuthGateway();
  addTearDown(gateway.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialLanguagePreferenceProvider.overrideWithValue(language),
        languagePreferenceStoreProvider.overrideWithValue(
          FakeLanguagePreferenceStore(),
        ),
        proposalGatewayProvider.overrideWithValue(
          proposals ?? FakeProposalGateway(),
        ),
        resourceListingGatewayProvider.overrideWithValue(
          resources ?? FakeResourceListingGateway(),
        ),
        projectResourceNeedsGatewayProvider.overrideWithValue(
          needs ?? FakeProjectResourceNeedsGateway(),
        ),
        profilePhotoGatewayProvider.overrideWithValue(
          FakeProfilePhotoGateway(),
        ),
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'test-key',
          ),
        ),
        authGatewayProvider.overrideWithValue(gateway),
        profileAnchorGatewayProvider.overrideWithValue(
          anchor ??
              (FakeProfileAnchorGateway()
                ..readiness = ProfileAnchorReadiness.complete),
        ),
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(data: profileFixture(complete: false)),
        ),
        startupPreferenceStoreProvider.overrideWithValue(
          store ?? FakeStartupStore(),
        ),
        tutorialRegistryProvider.overrideWithValue(registry),
        messagesGatewayProvider.overrideWithValue(
          messages ?? FakeMessagesGateway(),
        ),
        messageChatsGatewayProvider.overrideWithValue(
          chats ?? FakeMessageChatsGateway(),
        ),
        notificationsGatewayProvider.overrideWithValue(
          FakeNotificationsGateway(),
        ),
        initialNavigationPreferenceProvider.overrideWithValue(
          NavigationPreferenceState(destination: destination),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  if (settle) await frames(tester, 10);
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

Future<ProviderContainer> pumpTutorialSmoke(
  WidgetTester tester, {
  FakeStartupStore? store,
}) => _pump(tester, store: store);
