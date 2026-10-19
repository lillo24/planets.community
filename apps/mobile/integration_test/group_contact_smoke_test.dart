import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/backend/supabase_backend.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/group_contact/data/group_contact_gateway.dart';
import 'package:planets_mobile/features/group_contact/presentation/group_contact_routes.dart';
import 'package:planets_mobile/features/group_contact/presentation/group_contact_compose_screen.dart';
import 'package:planets_mobile/features/group_contact/presentation/group_contact_chat_screen.dart';
import 'package:planets_mobile/features/group_coordination/presentation/coordination_routes.dart';
import 'package:planets_mobile/features/group_coordination/presentation/coordination_screen.dart';
import 'package:planets_mobile/features/messages/application/message_unread_controller.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_models.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'contact_local_identity.dart';
import 'contact_native_actions.dart';
import 'groups_smoke_test.dart' as harness show waitUntil;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('real D submit, triage, accept, read, safety and independent Project join', (
    tester,
  ) async {
    final config = AppConfig.fromCompileTime();
    if (config.environment != AppEnvironment.local ||
        !['127.0.0.1', 'localhost', '::1'].contains(config.supabaseUrl.host)) {
      throw StateError(
        'Explicit disposable loopback configuration and adb reverse required.',
      );
    }
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const alice = String.fromEnvironment('D_ALICE_ID'),
        aliceToken = String.fromEnvironment('D_ALICE_TOKEN'),
        bob = String.fromEnvironment('D_BOB_ID'),
        bobToken = String.fromEnvironment('D_BOB_TOKEN'),
        carol = String.fromEnvironment('D_CAROL_ID'),
        carolToken = String.fromEnvironment('D_CAROL_TOKEN'),
        dave = String.fromEnvironment('D_DAVE_ID'),
        daveToken = String.fromEnvironment('D_DAVE_TOKEN'),
        library = String.fromEnvironment('D_LIBRARY'),
        libraryName = String.fromEnvironment('D_LIBRARY_NAME'),
        garden = String.fromEnvironment('D_GARDEN'),
        workshop = String.fromEnvironment('D_WORKSHOP'),
        grant = String.fromEnvironment('D_CAROL_GRANT'),
        project = String.fromEnvironment('D_PROJECT');
    if ([
      alice,
      aliceToken,
      bob,
      bobToken,
      carol,
      carolToken,
      dave,
      daveToken,
      library,
      libraryName,
      garden,
      workshop,
      grant,
      project,
    ].any((s) => s.isEmpty)) {
      throw StateError('Prepare local contact UI defines first.');
    }
    SupabaseClient? currentClient;
    ProviderContainer? currentScope;
    var identityEpoch = 0;
    var lost = false;
    var lostCoordination = false;
    final finalConfirmationActions = <String>[];
    final finalRecoveryActions = <String>[];
    Map<String, dynamic>? finalRecoveryReceipt;
    final originalError = FlutterError.onError;
    FlutterErrorDetails? lastError;
    FlutterError.onError = (details) {
      lastError = details;
      originalError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalError);
    Future<ProviderContainer> asPerson(
      String id,
      String token, {
      bool loseSubmit = false,
      bool loseCoordination = false,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      // Unmount before disposing the old actor's timers, subscriptions and
      // lifecycle observers. A later A -> B -> A mount is a fresh identity.
      currentScope?.dispose();
      currentScope = null;
      await currentClient?.dispose();
      currentClient = null;
      final client = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () => Future.value(token),
      );
      currentClient = client;
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          supabaseClientProvider.overrideWithValue(client),
          authGatewayProvider.overrideWithValue(ContactLocalIdentity(id)),
          policyAcceptanceStoreProvider.overrideWithValue(
            ContactTokenPolicyStore(client),
          ),
          initialLanguagePreferenceProvider.overrideWithValue(
            LanguagePreference.english,
          ),
          groupContactGatewayProvider.overrideWithValue(
            GroupContactGateway((name, args) async {
              // Only this actor's final consent/recovery is instrumented. Keep
              // synthetic action UUIDs in memory; never log tokens or payloads.
              if (loseCoordination) {
                if (name == 'confirm_group_coordination_audience') {
                  finalConfirmationActions.add(args['p_action_id'] as String);
                } else if (name == 'recover_group_contact_action') {
                  finalRecoveryActions.add(args['p_action_id'] as String);
                }
              }
              final result = await client.rpc<Object?>(name, params: args);
              if (loseCoordination && name == 'recover_group_contact_action') {
                finalRecoveryReceipt = result as Map<String, dynamic>?;
              }
              if (loseSubmit &&
                  name == 'submit_group_contact_request' &&
                  !lost) {
                lost = true;
                throw const SocketException(
                  'Synthetic lost response after real contact creation.',
                );
              }
              if (loseCoordination &&
                  name == 'confirm_group_coordination_audience' &&
                  !lostCoordination) {
                lostCoordination = true;
                throw const SocketException(
                  'Synthetic lost final coordination response after commit.',
                );
              }
              return result;
            }, signalClient: client),
          ),
        ],
      );
      currentScope = container;
      await container.read(authSessionProvider.notifier).start();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          key: ValueKey(++identityEpoch),
          container: container,
          child: const PlanetsApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await harness.waitUntil(
        tester,
        () =>
            container.read(authSessionProvider).phase == AuthSessionPhase.ready,
      );
      return container;
    }

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      currentScope?.dispose();
      await currentClient?.dispose();
    });

    Future<void> reveal(Finder finder) async {
      // ListView children below the 2x viewport may not be mounted yet. Every
      // expected UI checkpoint must scroll the current route before deciding
      // the content failed to load; a bare finder wait cannot build those rows.
      // Exclude EditableText's inner scrolling, which cannot reveal later rows.
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      ScrollPosition? searched;
      while (DateTime.now().isBefore(deadline)) {
        if (finder.evaluate().isNotEmpty) {
          await tester.ensureVisible(finder.first);
          await tester.pump(const Duration(milliseconds: 200));
          if (finder.hitTestable().evaluate().isNotEmpty) return;
        }
        // Find the current route's live scroll position again after each frame.
        // Start at its top so lazy children above the viewport remain reachable.
        final scrolls = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        );
        final elements = scrolls.evaluate().where(
          (element) =>
              ModalRoute.of(element)?.isCurrent != false &&
              element.findAncestorWidgetOfExactType<EditableText>() == null,
        );
        if (elements.isNotEmpty) {
          final state =
              (elements.last as StatefulElement).state as ScrollableState;
          final position = state.position;
          if (position.hasContentDimensions) {
            if (searched != position) {
              searched = position;
              position.jumpTo(position.minScrollExtent);
            } else {
              position.jumpTo(
                (position.pixels + 180).clamp(
                  position.minScrollExtent,
                  position.maxScrollExtent,
                ),
              );
            }
          }
        }
        await tester.pump(const Duration(milliseconds: 200));
      }
      debugPrint('D native missing visible content: $finder');
      await binding
          .takeScreenshot('d04-missing-visible-content')
          .timeout(const Duration(seconds: 30));
      expect(
        finder.hitTestable(),
        findsWidgets,
        reason: 'Native content must load and become visible.',
      );
    }

    Future<void> tap(String key) => tapContactNativeAction(
      tester,
      key,
      onFailure: (diagnostics) async {
        final scope = currentScope!;
        final path = scope
            .read(appRouterProvider)
            .routerDelegate
            .state
            .uri
            .path
            .replaceAll(RegExp(r'[0-9a-fA-F-]{36}'), ':id');
        debugPrint(
          'D native action failure: path=$path '
          'phase=${scope.read(authSessionProvider).phase.name}; $diagnostics',
        );
        await binding
            .takeScreenshot('d03-missing-$key')
            .timeout(const Duration(seconds: 30));
      },
    );

    Future<void> tapFinder(Finder finder) async {
      await reveal(finder);
      expect(finder.hitTestable(), findsOneWidget);
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> shot(String name) async {
      if (name.contains('keyboard')) {
        await harness.waitUntil(
          tester,
          () =>
              MediaQuery.viewInsetsOf(
                tester.element(find.byType(Scaffold).last),
              ).bottom >
              0,
        );
      }
      await harness.waitUntil(
        tester,
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      );
      await tester.pump(const Duration(milliseconds: 600));
      final exception = tester.takeException();
      if (exception != null) {
        debugPrint('D native render failure: ${exception.runtimeType}');
        debugPrint(lastError?.toString());
        debugPrintStack(stackTrace: lastError?.stack);
        await binding
            .takeScreenshot('d04-render-failure-$name')
            .timeout(const Duration(seconds: 30));
      }
      expect(exception, isNull);
      final context = tester.element(find.byType(Scaffold).last);
      expect(MediaQuery.sizeOf(context).width, closeTo(320, 0.5));
      expect(MediaQuery.textScalerOf(context).scale(10), 20);
      debugPrint('D native checkpoint: $name, actual 320dp, text scale 2x.');
      await binding
          .takeScreenshot('d02-$name')
          .timeout(const Duration(seconds: 30));
    }

    Future<void> hideKeyboard() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<Map<String, dynamic>> coordination(String actor, String id) =>
        currentClient!.rpc<Map<String, dynamic>>(
          'get_own_group_coordination_proposal',
          params: {'p_expected_profile_id': actor, 'p_proposal_id': id},
        );

    Future<void> confirmed(String actor, String id) async {
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      var result = await coordination(actor, id);
      while (result['own_confirmed'] != true &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 200));
        result = await coordination(actor, id);
      }
      expect(
        result['own_confirmed'],
        isTrue,
        reason: 'Do not switch actors before canonical consent commits.',
      );
      expect(
        result['chat_id'],
        isNull,
        reason: 'Partial consent cannot create a conversation.',
      );
    }

    final a = await asPerson(alice, aliceToken, loseSubmit: true);
    expect(
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
      closeTo(320, 1),
      reason: 'Native QA requires an actual 320dp viewport.',
    );
    final startingUnread = await currentClient!.rpc<Map<String, dynamic>>(
      'get_own_message_unread_summary_v2',
      params: {'p_expected_profile_id': alice},
    );
    await binding.convertFlutterSurfaceToImage();
    final aRouter = a.read(appRouterProvider);
    aRouter.go('/proposals/$project');
    await tap('contact-group-entry');
    await reveal(find.text('Propose collaboration'));
    await shot('public-context-en');
    await tapFinder(find.text('Propose collaboration'));
    await reveal(find.text('Fictional Neighbourhood Garden'));
    await tapFinder(find.text('Fictional Neighbourhood Garden'));
    await reveal(find.byKey(const Key('contact-title')));
    await tester.enterText(
      find.byKey(const Key('contact-title')),
      'Fictional shared garden proposal',
    );
    await reveal(find.byKey(const Key('contact-note')));
    await tester.enterText(
      find.byKey(const Key('contact-note')),
      'Private synthetic idea to coordinate local garden tools.',
    );
    await shot('composer-keyboard-en');
    await hideKeyboard();
    await tap('contact-submit');
    await reveal(find.byKey(const Key('contact-recover-submit')));
    await shot('delivery-pending-en');
    await tap('contact-recover-submit');
    await harness.waitUntil(
      tester,
      () => aRouter.routerDelegate.state.uri.path.contains(
        '/requests/group-contact/',
      ),
    );
    final request = aRouter.routerDelegate.state.uri.pathSegments.last;
    await reveal(find.text('Pending'));
    await shot('sent-request-en');
    final b = await asPerson(bob, bobToken);
    b.read(appRouterProvider).go(groupContactRequestRoute(request));
    await reveal(find.byKey(const Key('contact-accept')));
    await shot('creator-triage-en');
    final c = await asPerson(carol, carolToken);
    final cRouter = c.read(appRouterProvider);
    cRouter.go(groupContactRequestRoute(request));
    await tap('contact-accept');
    await tap('contact-confirm-accept');
    await reveal(find.text('Open conversation'));
    final own = await currentClient!.rpc<Map<String, dynamic>>(
      'get_own_group_contact_request',
      params: {'p_expected_profile_id': carol, 'p_request_id': request},
    );
    final chat = own['chat_id'] as String;
    await tapFinder(find.text('Open conversation'));
    await reveal(find.byKey(const Key('contact-message-body')));
    await tester.enterText(
      find.byKey(const Key('contact-message-body')),
      'Fictional human reply from Carol.',
    );
    await hideKeyboard();
    await tap('contact-message-send');
    await reveal(find.text('Fictional human reply from Carol.'));
    await shot('human-and-group-en');
    cRouter.go(groupContactInfoRoute(chat));
    // The app-bar title exists during loading; evidence requires the actual
    // authorized audience, not merely a route that has mounted.
    await reveal(find.text('Block Fictional alice'));
    await reveal(find.text('Fictional shared garden proposal'));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await shot('audience-en');
    final another = await asPerson(bob, bobToken);
    another.read(appRouterProvider).go(groupContactRequestRoute(request));
    await reveal(find.text('Accepted'));
    expect(find.text('Open conversation'), findsNothing);
    expect(
      find.text('Private synthetic idea to coordinate local garden tools.'),
      findsNothing,
    );
    await shot('other-manager-metadata-en');
    Future<String> createCoordination(String subject) async {
      final coordinator = await asPerson(alice, aliceToken);
      final coordinatorRouter = coordinator.read(appRouterProvider);
      coordinatorRouter.go(groupContactInfoRoute(chat));
      await reveal(find.text('Fictional shared garden proposal'));
      await tap('contact-coordinate');
      await tap('coordination-pick');
      await reveal(find.byKey(const Key('coordination-search')));
      await tester.enterText(
        find.byKey(const Key('coordination-search')),
        libraryName,
      );
      await tap('coordination-search-run');
      await hideKeyboard();
      await tap('coordination-group-$library');
      await tap('coordination-use-groups');
      await reveal(find.byKey(const Key('coordination-title')));
      await tester.enterText(
        find.byKey(const Key('coordination-title')),
        subject,
      );
      await reveal(find.byKey(const Key('coordination-note')));
      await tester.enterText(
        find.byKey(const Key('coordination-note')),
        'Only this fresh synthetic invitation is shared with the new audience.',
      );
      await hideKeyboard();
      await shot('coordination-fresh-composer-en');
      await tap('coordination-propose');
      await tap('coordination-confirm-dialog');
      await harness.waitUntil(
        tester,
        () =>
            coordinatorRouter.routerDelegate.state.uri.path.contains(
              '/group-coordination/',
            ) ||
            find.byKey(const Key('coordination-recover')).evaluate().isNotEmpty,
      );
      if (!coordinatorRouter.routerDelegate.state.uri.path.contains(
        '/group-coordination/',
      )) {
        await tap('coordination-recover');
        await harness.waitUntil(
          tester,
          () => coordinatorRouter.routerDelegate.state.uri.path.contains(
            '/group-coordination/',
          ),
        );
      }
      return coordinatorRouter.routerDelegate.state.uri.pathSegments.last;
    }

    final declinedCoordination = await createCoordination(
      'Synthetic coordination decline',
    );
    final coordinationDecliner = await asPerson(dave, daveToken);
    coordinationDecliner
        .read(appRouterProvider)
        .go(coordinationProposalRoute(declinedCoordination));
    await tap('coordination-claim-$library');
    await tap('coordination-confirm-dialog');
    await tap('coordination-decline');
    await tap('coordination-confirm-dialog');
    await reveal(find.text('Declined'));
    final declinedState = await coordination(dave, declinedCoordination);
    expect(declinedState['status'], 'declined');
    expect(declinedState['chat_id'], isNull);
    await shot('coordination-declined-no-chat-en');
    final proposalId = await createCoordination(
      'Fresh fictional three-group coordination',
    );
    final invitee = await asPerson(dave, daveToken);
    final inviteeRouter = invitee.read(appRouterProvider);
    inviteeRouter.go(coordinationProposalRoute(proposalId));
    await tap('coordination-claim-$library');
    await tap('coordination-confirm-dialog');
    await reveal(
      find.text(
        'The original representatives must confirm the complete named audience before it is shared with invitees.',
      ),
    );
    expect(find.text('Fictional human reply from Carol.'), findsNothing);
    expect(find.text('Open original conversation'), findsNothing);
    await shot('coordination-claimed-no-source-en');
    final firstConsent = await asPerson(alice, aliceToken);
    firstConsent
        .read(appRouterProvider)
        .go(coordinationProposalRoute(proposalId));
    await reveal(find.text('Fresh fictional three-group coordination'));
    await tap('coordination-confirm');
    await tap('coordination-confirm-dialog');
    await confirmed(alice, proposalId);
    final earlierAudience = await coordination(alice, proposalId);
    // Re-selecting the same Group deliberately retires its named seat. The
    // existing consent cannot silently transfer to the new selection round.
    await tap('coordination-change');
    await reveal(find.byKey(const Key('coordination-search')));
    await tester.enterText(
      find.byKey(const Key('coordination-search')),
      libraryName,
    );
    await tap('coordination-search-run');
    await hideKeyboard();
    await tap('coordination-group-$library');
    await tap('coordination-use-groups');
    await tap('coordination-confirm-dialog');
    final replacementDeadline = DateTime.now().add(const Duration(seconds: 45));
    var replacedAudience = await coordination(alice, proposalId);
    while (replacedAudience['version'] == earlierAudience['version'] &&
        DateTime.now().isBefore(replacementDeadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      replacedAudience = await coordination(alice, proposalId);
    }
    expect(
      replacedAudience['version'],
      (earlierAudience['version'] as int) + 1,
    );
    expect(replacedAudience['chat_id'], isNull);
    expect(replacedAudience['own_confirmed'], isFalse);
    expect(replacedAudience['all_seats_named'], isFalse);
    expect(replacedAudience['can_confirm'], isFalse);
    expect(
      (replacedAudience['audience'] as List).cast<Map<String, dynamic>>().every(
        (person) => person['confirmed'] == false,
      ),
      isTrue,
    );
    expect(
      (replacedAudience['groups'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((group) => group['group_id'] == library)['is_claimed'],
      isFalse,
    );
    await expectLater(
      currentClient!.rpc(
        'confirm_group_coordination_audience',
        params: {
          'p_expected_profile_id': alice,
          'p_action_id': const Uuid().v4(),
          'p_proposal_id': proposalId,
          'p_expected_version': earlierAudience['version'],
        },
      ),
      throwsA(
        isA<PostgrestException>().having(
          (error) => error.code,
          'code',
          'PT409',
        ),
      ),
    );
    await shot('coordination-changed-consent-reset-en');
    final reclaimed = await asPerson(dave, daveToken);
    reclaimed.read(appRouterProvider).go(coordinationProposalRoute(proposalId));
    await tap('coordination-claim-$library');
    await tap('coordination-confirm-dialog');
    await reveal(
      find.text(
        'The original representatives must confirm the complete named audience before it is shared with invitees.',
      ),
    );
    final renewedConsent = await asPerson(alice, aliceToken);
    renewedConsent
        .read(appRouterProvider)
        .go(coordinationProposalRoute(proposalId));
    await tap('coordination-confirm');
    await tap('coordination-confirm-dialog');
    await confirmed(alice, proposalId);
    final secondConsent = await asPerson(carol, carolToken);
    secondConsent
        .read(appRouterProvider)
        .go(coordinationProposalRoute(proposalId));
    await reveal(find.text('Fresh fictional three-group coordination'));
    await tap('coordination-confirm');
    await tap('coordination-confirm-dialog');
    await confirmed(carol, proposalId);
    final finalConsent = await asPerson(
      dave,
      daveToken,
      loseCoordination: true,
    );
    final finalRouter = finalConsent.read(appRouterProvider);
    finalRouter.go(coordinationProposalRoute(proposalId));
    await tap('coordination-confirm');
    final dialog = find.byType(AlertDialog);
    for (final name in [
      'Fictional alice',
      'Fictional carol',
      'Fictional dave',
      'Fictional Neighbourhood Garden',
      'Fictional Laboratorio di collaborazione del quartiere',
      libraryName,
    ]) {
      expect(
        find.descendant(of: dialog, matching: find.textContaining(name)),
        findsOneWidget,
      );
    }
    await shot('coordination-exact-audience-en');
    await tap('coordination-confirm-dialog');
    await harness.waitUntil(tester, () => lostCoordination);
    expect(finalConfirmationActions, hasLength(1));
    final originalFinalAction = finalConfirmationActions.single;
    expect(finalRecoveryActions, isEmpty);
    await tap('coordination-recover');
    await harness.waitUntil(tester, () => finalRecoveryReceipt != null);
    expect(finalConfirmationActions, [originalFinalAction]);
    expect(finalRecoveryActions, [originalFinalAction]);
    expect(finalRecoveryReceipt!['coordination_id'], proposalId);
    expect(finalRecoveryReceipt!['outcome'], 'active');
    expect(finalRecoveryReceipt!['replayed'], isTrue);
    await tap('coordination-open');
    await reveal(find.byKey(const Key('contact-message-body')));
    final freshChat = finalRouter.routerDelegate.state.uri.pathSegments.last;
    expect(finalRecoveryReceipt!['chat_id'], freshChat);
    final activated = await coordination(dave, proposalId);
    expect(activated['status'], 'active');
    expect(activated['chat_id'], freshChat);
    expect(activated['source_chat_id'], isNull);
    final audience = (activated['audience'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      audience.map((person) => person['profile_id']),
      unorderedEquals([alice, carol, dave]),
    );
    expect(
      audience.map((person) => person['group_id']),
      unorderedEquals([garden, workshop, library]),
    );
    expect(audience.every((person) => person['confirmed'] == true), isTrue);
    await expectLater(
      currentClient!.rpc(
        'get_own_group_contact_feed',
        params: {'p_expected_profile_id': dave, 'p_chat_id': chat},
      ),
      throwsA(
        isA<PostgrestException>().having(
          (error) => error.code,
          'code',
          '42501',
        ),
      ),
    );
    final freshFeed = await currentClient!.rpc<Map<String, dynamic>>(
      'get_own_group_contact_feed',
      params: {'p_expected_profile_id': dave, 'p_chat_id': freshChat},
    );
    expect(freshFeed['items'], isEmpty);
    expect(find.text('Fictional human reply from Carol.'), findsNothing);
    await shot('coordination-fresh-empty-chat-en');
    await tester.enterText(
      find.byKey(const Key('contact-message-body')),
      'A fresh human message from Fictional Dave.',
    );
    await hideKeyboard();
    await tap('contact-message-send');
    await reveal(find.text('A fresh human message from Fictional Dave.'));
    await shot('coordination-new-human-history-en');
    // Compact Italian audience consent uses the same real canonical proposal.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: finalConsent,
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: CoordinationScreen(proposalId: proposalId),
        ),
      ),
    );
    await reveal(find.text('Coordinamento pronto'));
    await reveal(find.textContaining('Fictional dave'));
    await shot('coordination-audience-it-320dp-2x');
    // Separate bilateral decline/withdraw controls never change the activated
    // coordination seats or either group's membership.
    Future<String> anotherRequest(String target, String subject) async {
      final sender = await asPerson(alice, aliceToken);
      final router = sender.read(appRouterProvider);
      router.go(groupContactComposeRoute(target));
      await reveal(find.text('Fictional Neighbourhood Garden'));
      await tapFinder(find.text('Fictional Neighbourhood Garden'));
      await reveal(find.byKey(const Key('contact-title')));
      await tester.enterText(find.byKey(const Key('contact-title')), subject);
      await reveal(find.byKey(const Key('contact-note')));
      await tester.enterText(
        find.byKey(const Key('contact-note')),
        'Independent synthetic request for a finite decision.',
      );
      await hideKeyboard();
      await tap('contact-submit');
      await harness.waitUntil(
        tester,
        () => router.routerDelegate.state.uri.path.contains(
          '/requests/group-contact/',
        ),
      );
      return router.routerDelegate.state.uri.pathSegments.last;
    }

    await anotherRequest(workshop, 'Synthetic withdraw path');
    await tap('contact-withdraw');
    await reveal(find.text('Withdrawn'));
    await shot('safe-withdraw-en');
    final declinedRequest = await anotherRequest(
      library,
      'Synthetic decline path',
    );
    final decliner = await asPerson(dave, daveToken);
    decliner
        .read(appRouterProvider)
        .go(groupContactRequestRoute(declinedRequest));
    await tap('contact-decline');
    await reveal(find.text('Declined'));
    await shot('explicit-decline-en');
    final bClient = SupabaseClient(
      config.supabaseUrl.toString(),
      config.supabasePublishableKey,
      accessToken: () => Future.value(bobToken),
    );
    addTearDown(bClient.dispose);
    final reader = await asPerson(alice, aliceToken);
    final beforeRead = await currentClient!.rpc<Map<String, dynamic>>(
      'get_own_message_unread_summary_v2',
      params: {'p_expected_profile_id': alice},
    );
    expect(
      beforeRead['groups'],
      (startingUnread['groups'] as int) + 2,
      reason: 'Both genuine incoming conversations are unread before opening.',
    );
    reader.read(appRouterProvider).go(groupContactChatRoute(chat));
    await reveal(find.text('Fictional human reply from Carol.'));
    await tester.pump(const Duration(seconds: 2));
    final unread = await currentClient!.rpc<Map<String, dynamic>>(
      'get_own_message_unread_summary_v2',
      params: {'p_expected_profile_id': alice},
    );
    expect(
      unread['groups'],
      (startingUnread['groups'] as int) + 1,
      reason: 'Rendering the bilateral frontier leaves coordination unread.',
    );
    final reportMessage = await currentClient!.rpc<Map<String, dynamic>>(
      'send_group_contact_message',
      params: {
        'p_expected_profile_id': alice,
        'p_action_id': const Uuid().v4(),
        'p_chat_id': freshChat,
        'p_body': 'Earlier synthetic message available for reporting.',
      },
    );
    final former = await asPerson(carol, carolToken);
    former.read(appRouterProvider).go(groupContactChatRoute(freshChat));
    await reveal(
      find.text('Earlier synthetic message available for reporting.'),
    );
    await harness.waitUntil(
      tester,
      () =>
          former.read(messageUnreadProvider).summary != null &&
          !former.read(messageUnreadProvider).disconnected,
    );
    await bClient.rpc(
      'revoke_group_delegate',
      params: {
        'p_expected_profile_id': bob,
        'p_delegate_id': grant,
        'p_client_request_id': const Uuid().v4(),
      },
    );
    // The subscribed own-account access hint must clear the live body; no local
    // forced refresh is used to disguise a missing authorization invalidation.
    await reveal(find.text('Report a previously received message'));
    expect(
      find.text('Earlier synthetic message available for reporting.'),
      findsNothing,
    );
    expect(find.byKey(const Key('contact-message-send')), findsNothing);
    await shot('former-denied-known-report-en');
    await tapFinder(find.text('Report a previously received message'));
    await reveal(find.byKey(const Key('moderation-category')));
    final reportTarget =
        former.read(appRouterProvider).routerDelegate.state.extra
            as ModerationReportTarget;
    expect(reportTarget.kind, ModerationTargetKind.groupContactMessage);
    expect(reportTarget.id, reportMessage['message_id']);
    await tapFinder(find.byKey(const Key('moderation-category')));
    await tester.pump(const Duration(milliseconds: 400));
    await tapFinder(find.text('Harassment or abuse').last);
    await tester.pump(const Duration(milliseconds: 400));
    await reveal(find.byKey(const Key('moderation-explanation')));
    await tester.enterText(
      find.byKey(const Key('moderation-explanation')),
      'Fictional report of a previously received synthetic message.',
    );
    await hideKeyboard();
    await tap('moderation-submit');
    await reveal(find.byKey(const Key('moderation-received')));
    await shot('protected-report-en');
    final reports = await currentClient!.rpc<List<dynamic>>(
      'list_own_moderation_reports_v3',
      params: {'p_expected_reporter_profile_id': carol},
    );
    expect(
      reports.where(
        (row) =>
            row['target_kind'] == 'group_contact_message' &&
            row['explanation'] ==
                'Fictional report of a previously received synthetic message.',
      ),
      hasLength(1),
    );
    // The UI report target is the exact incoming message retained before loss.
    expect(reportMessage['message_id'], isNotNull);
    final invitation = await bClient.rpc<List<dynamic>>(
      'create_group_authority_invitation',
      params: {
        'p_expected_profile_id': bob,
        'p_group_id': workshop,
        'p_client_request_id': const Uuid().v4(),
        'p_role': 'co_organizer',
      },
    );
    await currentClient!.rpc(
      'accept_group_authority_invitation',
      params: {
        'p_expected_profile_id': carol,
        'p_token': invitation.single['invite_token'],
        'p_client_request_id': const Uuid().v4(),
      },
    );
    for (final oldChat in [chat, freshChat]) {
      await expectLater(
        currentClient!.rpc(
          'get_own_group_contact_feed',
          params: {'p_expected_profile_id': carol, 'p_chat_id': oldChat},
        ),
        throwsA(
          isA<PostgrestException>().having(
            (error) => error.code,
            'code',
            '42501',
          ),
        ),
      );
    }
    former.read(appRouterProvider).go(groupContactChatRoute(freshChat));
    await reveal(
      find.text(
        'This conversation is unavailable. Your group membership is unchanged.',
      ),
    );
    expect(
      find.text('A fresh human message from Fictional Dave.'),
      findsNothing,
    );
    await shot('regrant-does-not-revive-coordination-en');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: former,
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: GroupContactChatScreen(chatId: freshChat),
        ),
      ),
    );
    await reveal(
      find.text(
        'Questa conversazione non è disponibile. La partecipazione al gruppo resta invariata.',
      ),
    );
    await shot('denied-it-320dp-2x');
    final leaver = await asPerson(carol, carolToken);
    leaver.read(appRouterProvider).go(groupContactInfoRoute(freshChat));
    await tap('contact-leave');
    await tap('contact-confirm-exit');
    await harness.waitUntil(
      tester,
      () =>
          leaver.read(appRouterProvider).routerDelegate.state.uri.path ==
          '/messages',
    );
    expect(
      await currentClient!.rpc(
        'has_own_group_contact_admission',
        params: {'p_expected_profile_id': carol, 'p_chat_id': freshChat},
      ),
      isFalse,
    );
    await shot('former-safe-leave-en');
    // D did not grant Project participation. Its existing request remains explicit.
    final joiner = await asPerson(alice, aliceToken);
    joiner.read(appRouterProvider).go(groupContactInfoRoute(freshChat));
    await reveal(find.text('Block Fictional carol'));
    await tapFinder(find.text('Block Fictional carol'));
    await tap('blocking-confirm-block');
    await reveal(find.text('Unblock Fictional carol'));
    await shot('block-permitted-history-en');
    joiner.read(appRouterProvider).go(groupContactInfoRoute(freshChat));
    await tap('contact-close');
    await tap('contact-confirm-exit');
    await harness.waitUntil(
      tester,
      () => find.byKey(const Key('contact-close')).evaluate().isEmpty,
    );
    final closed = await currentClient!.rpc<Map<String, dynamic>>(
      'get_own_group_contact_conversation',
      params: {'p_expected_profile_id': alice, 'p_chat_id': freshChat},
    );
    expect(closed['closed_at'], isNotNull);
    expect(closed['is_read_only'], isTrue);
    final retained = await currentClient!.rpc<Map<String, dynamic>>(
      'get_own_group_contact_feed',
      params: {'p_expected_profile_id': alice, 'p_chat_id': freshChat},
    );
    expect(
      (retained['items'] as List).map((row) => row['body']),
      contains('A fresh human message from Fictional Dave.'),
    );
    await shot('coordination-closed-permitted-history-en');
    final noProjectRequest = await currentClient!.rpc<List<dynamic>>(
      'list_own_project_join_requests',
      params: {'p_expected_requester_profile_id': alice},
    );
    expect(
      noProjectRequest.where((row) => row['project_id'] == project),
      isEmpty,
    );
    joiner.read(appRouterProvider).go('/proposals/$project/join');
    await reveal(find.byKey(const Key('participation-message-field')));
    await tester.enterText(
      find.byKey(const Key('participation-message-field')),
      'Independent fictional Project participation request.',
    );
    await hideKeyboard();
    await tap('participation-send-request');
    await harness.waitUntil(
      tester,
      () => !joiner
          .read(appRouterProvider)
          .routerDelegate
          .state
          .uri
          .path
          .endsWith('/join'),
    );
    await shot('independent-project-request-en');
    final projectRequests = await currentClient!.rpc<List<dynamic>>(
      'list_own_project_join_requests',
      params: {'p_expected_requester_profile_id': alice},
    );
    expect(
      projectRequests.where(
        (row) => row['project_id'] == project && row['status'] == 'pending',
      ),
      hasLength(1),
    );
    final memberships = await currentClient!.rpc<List<dynamic>>(
      'list_own_project_memberships',
      params: {'p_expected_participant_profile_id': alice},
    );
    expect(
      memberships.where((row) => row['project_id'] == project),
      isEmpty,
      reason: 'An explicit pending request is still not Project membership.',
    );
    // Native compact Italian render using the same genuine gateway and actor.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: joiner,
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: GroupContactComposeScreen(groupId: workshop),
        ),
      ),
    );
    await reveal(find.text('Fictional Neighbourhood Garden'));
    await shot('composer-it-320dp-2x');
    await reveal(find.byKey(const Key('contact-note')));
    await tester.enterText(
      find.byKey(const Key('contact-note')),
      'Nota sintetica con tastiera italiana.',
    );
    await shot('composer-it-320dp-2x-keyboard');
    await hideKeyboard();
    expect(tester.takeException(), isNull);
  });
}
