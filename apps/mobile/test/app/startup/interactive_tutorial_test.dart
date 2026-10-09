import '../../support/fake_policy.dart';

import 'package:planets_mobile/features/settings/data/language_preference_store.dart';

import '../../support/fake_settings.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/resource_listings/application/resource_listing_controllers.dart';
import 'package:planets_mobile/app/startup/tutorial_presentation.dart';
import 'package:planets_mobile/app/startup/tutorial_routes.dart';
import 'package:planets_mobile/app/startup/tutorial_motion.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/cover_media/application/cover_image_loader.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';

import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

import '../../support/fake_proposal.dart';
import '../../support/fake_cover_media.dart';
import '../../support/fake_resource_listing.dart';
import '../../support/fake_profile_photo.dart';
import '../../support/fake_project_resource_needs.dart';

void main() {
  testWidgets(
    'fade pauses; refresh and rotation remeasure without page entry',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final projects = FakeProposalGateway()
        ..publicItems = [proposalSummaryFixture()]
        ..publicDetail = proposalDetailFixture();
      final app = await _pump(tester, proposals: projects);
      await tap(tester, 'welcome-explore');
      await tap(tester, 'tutorial-next');
      for (var i = 0; i < 30 && scrim(tester).color.a == 0; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      final opacity = scrim(tester).color.a;
      expect(opacity, inExclusiveRange(0, .62));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(scrim(tester).color.a, opacity);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await ready(tester);
      await tap(tester, 'tutorial-next');
      await ready(tester);
      await app.read(publicProposalsProvider.notifier).load();
      await tester.pump();
      expect(scrim(tester).color.a, closeTo(.62, .001));
      await ready(tester);
      for (var i = 0; i < 3; i++) {
        await tap(tester, 'tutorial-next');
        await ready(tester);
      }
      expectFocus(tester, 'my-proposals-action');
      await tester.binding.setSurfaceSize(const Size(844, 390));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pump();
      expect(scrim(tester).color.a, closeTo(.62, .001));
      await ready(tester);
      expectFocus(tester, 'my-proposals-action');
      await tap(tester, 'tutorial-previous');
      await ready(tester);
      expectFocus(tester, 'proposal-create-action');
      await tap(tester, 'tutorial-previous');
      expect(scrim(tester).color.a, 0);
      await ready(tester);
      expectFocus(tester, 'participation-join-proposal-1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ready warmup follows Requested first and preserves active filters',
    (tester) async {
      final requested = proposalSummaryFixture(id: 'requested-first');
      final projects = FakeProposalGateway()
        ..publicItems = [proposalSummaryFixture()]
        ..requestedItems = [
          RequestedProposalSummary(
            requestId: 'request-1',
            requestCreatedAt: DateTime.utc(2026, 10, 1),
            proposal: requested,
          ),
        ]
        ..publicDetail = proposalDetailFixture(id: requested.id);
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'viewer')),
      );
      final app = await _pump(tester, proposals: projects, auth: auth);
      await app
          .read(publicProposalsProvider.notifier)
          .applyFilters(
            query: 'garden',
            locality: 'Bologna',
            skillIds: {'skill-mural'},
          );
      final calls = projects.calls.where((c) => c == 'list-public').length;
      app.read(appRouterProvider).go('/settings');
      await frames(tester, 6);
      TutorialRoutes.replay(
        tester.element(find.byKey(const Key('settings-language-row'))),
        returnTo: '/settings',
      );
      await frames(tester, 6);
      expect(projects.calls.where((c) => c == 'list-public'), hasLength(calls));
      expect(projects.lastQuery, 'garden');
      expect(projects.lastLocality, 'Bologna');
      expect(projects.lastSkillIds, {'skill-mural'});
      expect(projects.calls.where((c) => c.startsWith('public-detail')), [
        'public-detail:requested-first',
      ]);
      await tap(tester, 'tutorial-next');
      await tap(tester, 'tutorial-next');
      await ready(tester);
      expectFocus(tester, 'proposal-card-requested-first');
    },
  );

  testWidgets(
    'prefetched detail coalesces, retries and rejects account replacement',
    (tester) async {
      final delay = Completer<ProposalDetail?>();
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'alice')),
      );
      final projects = FakeProposalGateway()..publicDetailResult = delay.future;
      final app = await _pump(tester, auth: auth, proposals: projects);
      final controller = app.read(proposalDetailProvider.notifier);
      final first = controller.ensureLoaded('proposal-1');
      final second = controller.ensureLoaded('proposal-1');
      expect(
        projects.calls.where((c) => c.startsWith('public-detail')),
        hasLength(1),
      );
      auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'bob')));
      await frames(tester, 6);
      delay.complete(proposalDetailFixture());
      await Future.wait([first, second]);
      expect(app.read(proposalDetailProvider).detail, isNull);
      projects.publicDetailResult = Future.error(
        StateError('unavailable public detail'),
      );
      await controller.ensureLoaded('proposal-1');
      expect(app.read(proposalDetailProvider).phase, ProposalLoadPhase.failure);
      projects.publicDetailResult = null;
      projects.publicDetail = proposalDetailFixture();
      await controller.ensureLoaded('proposal-1');
      await controller.ensureLoaded('proposal-1');
      expect(app.read(proposalDetailProvider).phase, ProposalLoadPhase.ready);
      expect(
        projects.calls.where((c) => c.startsWith('public-detail')),
        hasLength(3),
      );
    },
  );

  testWidgets('warmup preserves a different covered detail until tour visit', (
    tester,
  ) async {
    final projects = FakeProposalGateway()
      ..publicItems = [proposalSummaryFixture()]
      ..publicDetail = proposalDetailFixture(id: 'caller');
    final app = await _pump(tester, proposals: projects);
    await app.read(proposalDetailProvider.notifier).load('caller');
    await tap(tester, 'welcome-explore');
    expect(app.read(proposalDetailProvider).proposalId, 'caller');
    expect(projects.calls.where((c) => c.startsWith('public-detail')), [
      'public-detail:caller',
    ]);
    projects.publicDetail = proposalDetailFixture();
    for (var i = 0; i < 3; i++) {
      await tap(tester, 'tutorial-next');
    }
    await ready(tester);
    expectFocus(tester, 'participation-join-proposal-1');
    expect(
      projects.calls.where((c) => c == 'public-detail:proposal-1'),
      hasLength(1),
    );
  });
  testWidgets('every new page paints unobscured before the spotlight fade', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await _pump(
      tester,
      proposals: FakeProposalGateway()
        ..publicItems = [proposalSummaryFixture()]
        ..publicDetail = proposalDetailFixture(),
    );
    await tap(tester, 'welcome-explore');
    final previous = tester.getRect(find.byKey(const Key('tutorial-previous')));
    final next = tester.getRect(find.byKey(const Key('tutorial-next')));
    expect(previous.height, greaterThanOrEqualTo(54));
    expect(next.height, greaterThanOrEqualTo(54));
    expect(previous.width, closeTo(next.width, 1));
    expect(previous.top, next.top);
    expect(find.byType(BackButton), findsNothing);
    for (final step in TutorialStep.values.skip(1)) {
      await tap(tester, 'tutorial-next');
      final newPage = {
        TutorialStep.home,
        TutorialStep.projectCard,
        TutorialStep.projectDetail,
        TutorialStep.projectCreate,
        TutorialStep.homeResources,
        TutorialStep.resources,
        TutorialStep.messagesTabs,
      }.contains(step);
      if (newPage) {
        expect(scrim(tester).color.a, 0, reason: step.name);
        expect(
          find.byKey(const Key('tutorial-next')).hitTestable(),
          findsOneWidget,
        );
        var sawFade = false;
        for (var frame = 0; frame < 150; frame++) {
          await tester.pump(const Duration(milliseconds: 40));
          final alpha = scrim(tester).color.a;
          if (alpha > 0 && alpha < .61) {
            expect(scrim(tester).opacity, closeTo(alpha / .62, .001));
            sawFade = true;
            break;
          }
        }
        expect(sawFade, isTrue, reason: step.name);
      }
      await ready(tester);
    }
    expect(scrim(tester).color.a, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('intro warms first three canonical covers and one detail only', (
    tester,
  ) async {
    final coverDelay = Completer<Uint8List>();
    final covers = FakeCoverMediaGateway()..downloadDelay = coverDelay.future;
    final projects = FakeProposalGateway()
      ..publicItems = [
        for (var i = 1; i <= 4; i++)
          proposalSummaryFixture(
            id: 'project-$i',
            coverObjectPath: 'public/$i.webp',
          ),
      ]
      ..publicDetail = proposalDetailFixture(id: 'project-1');
    final app = await _pump(tester, proposals: projects, covers: covers);
    await tap(tester, 'welcome-explore');
    expect(projects.calls.where((c) => c == 'list-public'), hasLength(1));
    expect(projects.calls.where((c) => c.startsWith('public-detail')), [
      'public-detail:project-1',
    ]);
    expect(covers.calls, [
      for (var i = 1; i <= 3; i++) 'download:public/$i.webp',
    ]);
    expect(
      app.read(publicCoverBytesProvider('public/1.webp')).isLoading,
      isTrue,
    );
    coverDelay.complete(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aB9kAAAAASUVORK5CYII=',
      ),
    );
    await frames(tester, 4);
    expect(
      app.read(publicCoverBytesProvider('public/1.webp')).hasValue,
      isTrue,
    );
    await tap(tester, 'tutorial-next');
    await tap(tester, 'tutorial-next');
    await ready(tester);
    await tap(tester, 'tutorial-next');
    await ready(tester);
    await tap(tester, 'tutorial-previous');
    await ready(tester);
    expect(projects.calls.where((c) => c == 'list-public'), hasLength(1));
    expect(
      projects.calls.where((c) => c.startsWith('public-detail')),
      hasLength(1),
    );
    expect(
      covers.calls.where((c) => c == 'download:public/1.webp'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'detail timing scales with actual short and long distance at 500px/s',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final durations = <int>[];
      final distances = <double>[];
      for (final paragraphs in [1, 55]) {
        final projects = FakeProposalGateway()
          ..publicItems = [proposalSummaryFixture()]
          ..publicDetail = longTutorialDetail(paragraphs);
        await _pump(tester, proposals: projects);
        await tap(tester, 'welcome-explore');
        for (var i = 0; i < 3; i++) {
          await tap(tester, 'tutorial-next');
        }
        final list = find.byKey(
          const PageStorageKey('proposal-detail-proposal-1'),
        );
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        var elapsed = 0;
        var distance = 0.0;
        for (var frame = 0; frame < 900; frame++) {
          final before = position.pixels;
          await tester.pump(const Duration(milliseconds: 40));
          final movement = position.pixels - before;
          expect(
            movement,
            lessThanOrEqualTo(tutorialScrollPixelsPerSecond * .04 + 1),
          );
          distance += movement.abs();
          if (movement.abs() > .1) elapsed += 40;
          if (scrim(tester).targets.isNotEmpty) break;
        }
        await ready(tester);
        expectFocus(tester, 'participation-join-proposal-1');
        final hole = scrim(tester).targets.single;
        expect(
          hole.bottom,
          lessThanOrEqualTo(
            tester.getSize(find.byKey(const Key('tutorial-overlay'))).height,
          ),
        );
        durations.add(elapsed);
        distances.add(distance);
        await tester.pumpWidget(const SizedBox());
      }
      expect(distances.last, greaterThan(distances.first * 3));
      expect(durations.last, greaterThan(durations.first * 3));
      expect(
        tutorialScrollDuration(distances.last).inMilliseconds,
        closeTo(durations.last, 100),
      );
    },
  );

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
    'manual pacing, rapid taps and Previous/system Back change one step',
    (tester) async {
      final store = FakeStartupStore();
      final app = await _pump(tester, store: store);
      await tap(tester, 'welcome-explore');
      expect(scrim(tester).targets, isEmpty);
      await tester.pump(const Duration(seconds: 16));
      expect(
        find.byKey(const Key('tutorial-copy-introduction')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('tutorial-overlay'))),
      );
      await tester.pump();
      expect(find.byKey(const Key('tutorial-copy-home')), findsOneWidget);
      await ready(tester);
      await tester.pump(const Duration(seconds: 16));
      expect(find.byKey(const Key('tutorial-copy-home')), findsOneWidget);
      await tap(tester, 'tutorial-next');
      await ready(tester);
      await app.read(appRouterProvider).routerDelegate.popRoute();
      await frames(tester, 6);
      expect(find.byKey(const Key('tutorial-copy-home')), findsOneWidget);
      await tap(tester, 'tutorial-previous');
      expect(
        find.byKey(const Key('tutorial-copy-introduction')),
        findsOneWidget,
      );
      await tap(tester, 'tutorial-previous');
      expect(app.read(appRouterProvider).routerDelegate.state.uri.path, '/');
      expect(store.writes, 0);
    },
  );

  testWidgets(
    'exact empty guest sequence uses covered examples and three disjoint resource holes',
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
        await ready(tester);
        expect(find.byKey(Key('tutorial-copy-${step.name}')), findsOneWidget);
        final count =
            step == TutorialStep.introduction || step == TutorialStep.farewell
            ? 0
            : step == TutorialStep.resources
            ? 3
            : 1;
        expect(scrim(tester).targets, hasLength(count), reason: step.name);
        if ({
          TutorialStep.projectCard,
          TutorialStep.projectDetail,
          TutorialStep.resources,
        }.contains(step)) {
          expect(
            find.byKey(const Key('tutorial-illustration-label')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('tutorial-example-cover')),
            findsOneWidget,
          );
          final image = tester.widget<Image>(
            find.byKey(const Key('tutorial-example-cover')),
          );
          expect(image.image, isA<AssetImage>());
        }
        if (step == TutorialStep.resources) {
          expectDisjointResources(tester);
        }
        if (step == TutorialStep.homeResources) {
          expect(
            find.byKey(const Key('browse-resources-button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('planets-floating-logo')),
            findsOneWidget,
          );
        }
        if (step.index > 0) {
          await tap(tester, 'tutorial-previous');
          await ready(tester);
          expect(
            find.byKey(
              Key('tutorial-copy-${TutorialStep.values[step.index - 1].name}'),
            ),
            findsOneWidget,
          );
          await tap(tester, 'tutorial-next');
          await ready(tester);
          expect(find.byKey(Key('tutorial-copy-${step.name}')), findsOneWidget);
        }
        expect(store.writes, 0);
        await tap(tester, 'tutorial-next');
      }
      expect(store.version, productionTutorial.version);
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
    'first Full Project is frozen, measured scroll pauses and Full stays truthful',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final full = projectCapacityFixture(
        registrationCapacity: 1,
        currentParticipantCount: 1,
      );
      final first = proposalSummaryFixture(id: 'first-full', capacity: full);
      final second = proposalSummaryFixture(id: 'second-joinable');
      final base = proposalDetailFixture(id: first.id, capacity: full);
      final projects = FakeProposalGateway()
        ..publicItems = [first, second]
        ..publicDetail = ProposalDetail(
          summary: base.summary,
          creatorProfileId: base.creatorProfileId,
          creatorDisplayName: base.creatorDisplayName,
          description: List.filled(
            8,
            'Read how neighbors will build and share a mural together.',
          ).join('\n\n'),
          exactMeetingText: base.exactMeetingText,
          exactLocationRestricted: base.exactLocationRestricted,
        );
      final app = await _pump(tester, proposals: projects);
      await tap(tester, 'welcome-explore');
      await tap(tester, 'tutorial-next');
      await tap(tester, 'tutorial-next');
      await ready(tester);
      expect(
        find.byKey(const Key('tutorial-illustration-label')),
        findsNothing,
      );
      expectFocus(tester, 'proposal-card-first-full');
      projects.publicItems = [second, first];
      await app.read(publicProposalsProvider.notifier).load();
      await ready(tester);
      expectFocus(tester, 'proposal-card-first-full');
      await tap(tester, 'tutorial-next');
      expect(projects.calls, contains('public-detail:first-full'));
      expect(projects.calls, isNot(contains('public-detail:second-joinable')));
      final list = find.byKey(
        const PageStorageKey('proposal-detail-first-full'),
      );
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position;
      expect(position.pixels, 0);
      expect(scrim(tester).targets, isEmpty);
      await frames(tester, 8);
      expect(position.pixels, greaterThan(0));
      expect(position.pixels, lessThan(position.maxScrollExtent));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = position.pixels;
      await tester.pump(const Duration(seconds: 16));
      expect(position.pixels, paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await ready(tester);
      expectFocus(tester, 'participation-full-first-full');
      expect(
        find.byKey(const Key('participation-join-first-full')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('tutorial-illustration-label')),
        findsNothing,
      );
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const Key('tutorial-overlay'))) +
            scrim(tester).targets.single.center,
      );
      await frames(tester, 6);
      expect(find.byKey(const Key('proposal-create-action')), findsOneWidget);
      expect(
        find.byKey(const Key('tutorial-copy-projectCreate')),
        findsOneWidget,
      );
      await tap(tester, 'tutorial-previous');
      await ready(tester);
      expectFocus(tester, 'participation-full-first-full');
      expect(
        projects.calls.where((c) => c == 'create' || c == 'publish'),
        isEmpty,
      );
    },
  );

  testWidgets('late Needs layout keeps the spotlight on the real Join action', (
    tester,
  ) async {
    final pending = Completer<void>();
    final needs = FakeProjectResourceNeedsGateway()
      ..publicDelay = pending.future
      ..publicItems = [
        for (var i = 0; i < 6; i++)
          publicProjectResourceNeedFixture(
            id: 'late-$i',
            title: 'Material $i',
            details:
                'A real resource description that changes the layout. ' * 5,
          ),
      ];
    final projects = FakeProposalGateway()
      ..publicItems = [proposalSummaryFixture()]
      ..publicDetail = proposalDetailFixture();
    await _pump(tester, proposals: projects, needs: needs);
    await tap(tester, 'welcome-explore');
    for (var i = 0; i < TutorialStep.projectDetail.index; i++) {
      await tap(tester, 'tutorial-next');
    }
    await ready(tester);
    expectFocus(tester, 'participation-join-proposal-1');
    await frames(tester, 30);
    pending.complete();
    await frames(tester, 30);
    await ready(tester);
    expectFocus(tester, 'participation-join-proposal-1');
    expect(
      find.byKey(const Key('tutorial-copy-projectDetail')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('tutorial-illustration-label')), findsNothing);
  });

  testWidgets('Previous interrupts detail scroll and restores the same card', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final projects = FakeProposalGateway()
      ..publicItems = [proposalSummaryFixture()]
      ..publicDetail = proposalDetailFixture();
    await _pump(tester, proposals: projects);
    await tap(tester, 'welcome-explore');
    for (var i = 0; i < 3; i++) {
      await tap(tester, 'tutorial-next');
    }
    await frames(tester, 18);
    await tap(tester, 'tutorial-previous');
    await ready(tester);
    expectFocus(tester, 'proposal-card-proposal-1');
    await tester.pump(const Duration(seconds: 16));
    expect(find.byKey(const Key('tutorial-copy-projectCard')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real guest Join is spotlighted but overlay tap cannot open Auth or send a request',
    (tester) async {
      final projects = FakeProposalGateway()
        ..publicItems = [proposalSummaryFixture()]
        ..publicDetail = proposalDetailFixture();
      final app = await _pump(tester, proposals: projects);
      await tap(tester, 'welcome-explore');
      for (var i = 0; i < TutorialStep.projectDetail.index; i++) {
        await tap(tester, 'tutorial-next');
      }
      await ready(tester);
      expectFocus(tester, 'participation-join-proposal-1');
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const Key('tutorial-overlay'))) +
            scrim(tester).targets.single.center,
      );
      await frames(tester, 6);
      expect(
        find.byKey(const Key('tutorial-copy-projectCreate')),
        findsOneWidget,
      );
      expect(
        app.read(appRouterProvider).routerDelegate.state.uri.path,
        '/intro',
      );
      expect(app.read(authSessionProvider).phase, AuthSessionPhase.signedOut);
      expect(
        projects.calls.every(
          (c) => c.startsWith('list-public') || c.startsWith('public-detail'),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'real Scambio card, Create and Drafts share one explanation without writes or filters',
    (tester) async {
      final resources = FakeResourceListingGateway()
        ..publicItems = [publicResourceListingFixture()];
      final app = await _pump(tester, resources: resources);
      await tap(tester, 'welcome-explore');
      for (var i = 0; i < TutorialStep.resources.index; i++) {
        await tap(tester, 'tutorial-next');
      }
      await ready(tester);
      expect(
        find.byKey(const Key('tutorial-illustration-label')),
        findsNothing,
      );
      expectDisjointResources(tester);
      expectFocus(tester, 'resource-card-$resourceListingId', index: 0);
      final filter = app.read(publicResourceListingsProvider).modeFilter;
      await tester.pump(const Duration(seconds: 16));
      expect(find.byKey(const Key('tutorial-copy-resources')), findsOneWidget);
      await tap(tester, 'tutorial-previous');
      await ready(tester);
      expectFocus(tester, 'browse-resources-button');
      await tap(tester, 'tutorial-next');
      await ready(tester);
      expectDisjointResources(tester);
      expect(app.read(publicResourceListingsProvider).modeFilter, filter);
      expect(resources.createCount, 0);
      expect(
        app.read(appRouterProvider).routerDelegate.state.uri.path,
        '/intro',
      );
    },
  );

  testWidgets(
    'bounded unavailable feed uses a stable covered fallback even after late data',
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
      expect(scrim(tester).targets, isEmpty);
      await ready(tester);
      expect(find.byKey(const Key('tutorial-example-cover')), findsOneWidget);
      pending.complete([proposalSummaryFixture()]);
      await frames(tester, 3);
      expect(find.byKey(const Key('tutorial-example-cover')), findsOneWidget);
      await tap(tester, 'tutorial-next');
      await ready(tester);
      expect(
        find.byKey(const Key('tutorial-example-participation')),
        findsOneWidget,
      );
      expect(
        projects.calls.where((c) => c.startsWith('public-detail')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'Next during feed loading still opens the first real Project when it arrives',
    (tester) async {
      final pending = Completer<List<ProposalSummary>>();
      final projects = FakeProposalGateway()
        ..publicDetail = proposalDetailFixture(id: 'late-real')
        ..publicLoader = ({
          required limit,
          cursor,
          query,
          locality,
          skillIds,
        }) => pending.future;
      await _pump(tester, proposals: projects);
      await tap(tester, 'welcome-explore');
      for (var i = 0; i < TutorialStep.projectDetail.index; i++) {
        await tap(tester, 'tutorial-next');
      }
      expect(
        find.byKey(const Key('tutorial-copy-projectDetail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('tutorial-illustration-label')),
        findsNothing,
      );
      pending.complete([
        proposalSummaryFixture(id: 'late-real'),
        proposalSummaryFixture(),
      ]);
      await ready(tester);
      expect(projects.calls, contains('public-detail:late-real'));
      expect(projects.calls, isNot(contains('public-detail:proposal-1')));
      expectFocus(tester, 'participation-join-late-real');
      expect(
        find.byKey(const Key('tutorial-illustration-label')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'disappearing selected detail is a labelled cover-bearing fallback, never another Project',
    (tester) async {
      final projects = FakeProposalGateway()
        ..publicItems = [
          proposalSummaryFixture(),
          proposalSummaryFixture(id: 'other'),
        ];
      await _pump(tester, proposals: projects);
      await tap(tester, 'welcome-explore');
      for (var i = 0; i < 3; i++) {
        await tap(tester, 'tutorial-next');
      }
      await ready(tester);
      expect(projects.calls, contains('public-detail:proposal-1'));
      expect(projects.calls, isNot(contains('public-detail:other')));
      expect(find.byKey(const Key('tutorial-example-cover')), findsOneWidget);
    },
  );

  testWidgets(
    'Skip persists dismissal of the corrected version and suppresses first run',
    (tester) async {
      final store = FakeStartupStore();
      final app = await _pump(tester, store: store);
      await tap(tester, 'welcome-explore');
      await tap(tester, 'tutorial-skip');
      expect(store.version, 'dismissed:${productionTutorial.version}');
      expect(
        app.read(startupFlowProvider).preference.dismissedVersion,
        productionTutorial.version,
      );
      expect(app.read(startupFlowProvider).needsTutorial, isFalse);
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
            if (step == TutorialStep.projectDrafts) {
              expectFocus(tester, 'my-proposals-action');
            }
            if (step == TutorialStep.messagesTabs) {
              expectFocus(tester, 'messages-requests-action');
              expect(find.byType(TabBar), findsNothing);
              expect(find.byType(BackButton), findsNothing);
            }
            if (step == TutorialStep.resources) expectDisjointResources(tester);
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
  testWidgets(
    'rapid replay Finish pops a stacked caller only once and never writes status',
    (tester) async {
      final store = FakeStartupStore();
      final app = await _pump(
        tester,
        store: store,
        auth: FakeAuthGateway(
          snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
        ),
      );
      final router = app.read(appRouterProvider);
      unawaited(router.push<void>('/settings'));
      await frames(tester, 6);
      TutorialRoutes.replay(
        tester.element(find.byKey(const Key('settings-language-row'))),
        returnTo: '/settings',
      );
      await frames(tester, 6);
      for (final step in TutorialStep.values) {
        await ready(tester);
        if (step == TutorialStep.farewell) break;
        await tap(tester, 'tutorial-next');
      }
      final finish = tester
          .widget<FilledButton>(find.byKey(const Key('tutorial-next')))
          .onPressed!;
      finish();
      finish();
      await frames(tester, 6);
      expect(router.routerDelegate.state.uri.path, '/settings');
      expect(store.writes, 0);
      expect(app.read(startupFlowProvider).tutorialDeferred, isFalse);
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
  if (find
          .byKey(const Key('tutorial-copy-introduction'))
          .evaluate()
          .isNotEmpty ||
      find.byKey(const Key('tutorial-copy-farewell')).evaluate().isNotEmpty) {
    return;
  }
  for (var i = 0; i < 500; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    final paint =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('tutorial-spotlight')),
                )
                .painter!
            as TutorialScrim;
    if (paint.targets.isNotEmpty &&
        paint.color.a > .61 &&
        (find.byKey(const Key('tutorial-copy-resources')).evaluate().isEmpty ||
            paint.targets.length == 3)) {
      return;
    }
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
  FakeCoverMediaGateway? covers,
}) async {
  final gateway = auth ?? FakeAuthGateway();
  addTearDown(gateway.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preacceptedPolicyFixture,
        coverMediaGatewayProvider.overrideWithValue(
          covers ?? FakeCoverMediaGateway(),
        ),
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
  FakeProposalGateway? proposals,
  FakeResourceListingGateway? resources,
  FakeCoverMediaGateway? covers,
  LanguagePreference language = LanguagePreference.english,
}) => _pump(
  tester,
  store: store,
  proposals: proposals,
  resources: resources,
  covers: covers,
  language: language,
);

ProposalDetail longTutorialDetail(int paragraphs, {String? coverObjectPath}) {
  final base = proposalDetailFixture();
  return ProposalDetail(
    summary: coverObjectPath == null
        ? base.summary
        : proposalSummaryFixture(coverObjectPath: coverObjectPath),
    creatorProfileId: base.creatorProfileId,
    creatorDisplayName: base.creatorDisplayName,
    description: List.filled(
      paragraphs,
      'Neighbors build a garden together, sharing tools and practical skills.',
    ).join('\n\n'),
    exactMeetingText: base.exactMeetingText,
    exactLocationRestricted: base.exactLocationRestricted,
  );
}

TutorialScrim scrim(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(find.byKey(const Key('tutorial-spotlight')))
            .painter!
        as TutorialScrim;

void expectFocus(WidgetTester tester, String key, {int index = 0}) {
  final surface = tester.getTopLeft(find.byKey(const Key('tutorial-overlay')));
  final iconTarget =
      key == 'my-proposals-action' ||
      key == 'resource-my-listings-action' ||
      key == 'messages-requests-action';
  final anchor = find.byKey(Key(key));
  final bounds = tester
      .getRect(
        iconTarget
            ? find.descendant(of: anchor, matching: find.byType(Icon)).first
            : anchor,
      )
      .shift(-surface);
  final target = scrim(tester).targets[index];
  expect(
    bounds.inflate(1).contains(target.center),
    isTrue,
    reason: '$key bounds=$bounds target=$target',
  );
  final visible =
      (Offset.zero & tester.getSize(find.byKey(const Key('tutorial-overlay'))))
          .deflate(8);
  expect(
    target.width,
    closeTo(bounds.inflate(iconTarget ? 3 : 6).intersect(visible).width, 1),
    reason: key,
  );
  if (key.contains('card-')) expect(target.height, greaterThan(50));
}

void expectDisjointResources(WidgetTester tester) {
  final targets = scrim(tester).targets;
  expect(targets, hasLength(3));
  expectFocus(tester, 'resource-create-action', index: 1);
  expectFocus(tester, 'resource-my-listings-action', index: 2);
  for (var i = 0; i < targets.length; i++) {
    for (var j = i + 1; j < targets.length; j++) {
      expect(targets[i].overlaps(targets[j]), isFalse);
    }
  }
}
