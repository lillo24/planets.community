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
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/group_contact/data/group_contact_gateway.dart';
import 'package:planets_mobile/features/group_contact/presentation/group_contact_routes.dart';
import 'package:planets_mobile/features/group_contact/presentation/group_contact_compose_screen.dart';
import 'package:planets_mobile/features/group_coordination/presentation/coordination_routes.dart';
import 'package:planets_mobile/features/group_coordination/presentation/coordination_screen.dart';
import 'package:planets_mobile/features/messages/application/message_unread_controller.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'contact_local_identity.dart';
import 'groups_smoke_test.dart' as harness show waitUntil, waitFor, reveal;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'real D submit, triage, accept, read, safety and independent Project join',
    (tester) async {
      final config = AppConfig.fromCompileTime();
      if (config.environment != AppEnvironment.local ||
          ![
            '127.0.0.1',
            'localhost',
            '::1',
          ].contains(config.supabaseUrl.host)) {
        throw StateError(
          'Explicit disposable loopback configuration and adb reverse required.',
        );
      }
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
      final containers = <ProviderContainer>[];
      final clients = <SupabaseClient>[];
      var lost = false;
      var lostCoordination = false;
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
        final client = SupabaseClient(
          config.supabaseUrl.toString(),
          config.supabasePublishableKey,
          accessToken: () => Future.value(token),
        );
        currentClient = client;
        clients.add(client);
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
                final result = await client.rpc<Object?>(name, params: args);
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
        containers.add(container);
        await container.read(authSessionProvider.notifier).start();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            key: ValueKey(containers.length),
            container: container,
            child: const PlanetsApp(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        return container;
      }

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        for (final container in containers) {
          container.dispose();
        }
        for (final client in clients) {
          await client.dispose();
        }
      });
      Future<void> tap(String key) async {
        final finder = find.byKey(Key(key));
        if (key.startsWith('contact-confirm-') ||
            key == 'coordination-confirm-dialog' ||
            key.startsWith('blocking-confirm-')) {
          await harness.waitFor(tester, finder);
        }
        // Route/auth/access refreshes can replace a lazy ListView while waiting.
        // Re-find its scrollable after each frame rather than retaining a finder
        // for a disposed previous route. Missing widgets still fail explicitly.
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (finder.hitTestable().evaluate().isEmpty &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
          if (finder.evaluate().isNotEmpty) {
            await tester.ensureVisible(finder);
          } else {
            final scrolls = find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            );
            if (scrolls.evaluate().isNotEmpty) {
              await tester.drag(scrolls.first, const Offset(0, -200));
            }
          }
        }
        expect(
          finder.hitTestable(),
          findsOneWidget,
          reason: 'Native action $key must become visible.',
        );
        await harness.waitUntil(
          tester,
          () =>
              finder.hitTestable().evaluate().isNotEmpty &&
              (finder.evaluate().single.widget is! ButtonStyleButton ||
                  (finder.evaluate().single.widget as ButtonStyleButton)
                          .onPressed !=
                      null),
        );
        await tester.tap(finder);
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> shot(String name) async {
        await tester.pump(const Duration(milliseconds: 600));
        final exception = tester.takeException();
        if (exception != null) {
          debugPrint('D native render failure: ${exception.runtimeType}');
          debugPrintStack(stackTrace: lastError?.stack);
        }
        expect(exception, isNull);
        await binding
            .takeScreenshot('d02-$name')
            .timeout(const Duration(seconds: 30));
      }

      Future<void> hideKeyboard() async {
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await tester.pump(const Duration(milliseconds: 400));
      }

      final a = await asPerson(alice, aliceToken, loseSubmit: true);
      final startingUnread = await currentClient!.rpc<Map<String, dynamic>>(
        'get_own_message_unread_summary_v2',
        params: {'p_expected_profile_id': alice},
      );
      await binding.convertFlutterSurfaceToImage();
      final aRouter = a.read(appRouterProvider);
      aRouter.go('/proposals/$project');
      await tap('contact-group-entry');
      await harness.waitFor(tester, find.text('Propose collaboration'));
      await shot('public-context-en');
      await tester.tap(find.text('Propose collaboration'));
      await harness.waitFor(
        tester,
        find.text('Fictional Neighbourhood Garden'),
      );
      await tester.tap(find.text('Fictional Neighbourhood Garden'));
      await harness.reveal(tester, find.byKey(const Key('contact-title')));
      await tester.enterText(
        find.byKey(const Key('contact-title')),
        'Fictional shared garden proposal',
      );
      await harness.reveal(tester, find.byKey(const Key('contact-note')));
      await tester.enterText(
        find.byKey(const Key('contact-note')),
        'Private synthetic idea to coordinate local garden tools.',
      );
      await shot('composer-keyboard-en');
      await hideKeyboard();
      await tap('contact-submit');
      await harness.waitFor(
        tester,
        find.byKey(const Key('contact-recover-submit')),
      );
      await shot('delivery-pending-en');
      await tap('contact-recover-submit');
      await harness.waitUntil(
        tester,
        () => aRouter.routerDelegate.state.uri.path.contains(
          '/requests/group-contact/',
        ),
      );
      final request = aRouter.routerDelegate.state.uri.pathSegments.last;
      await harness.waitFor(tester, find.text('Pending'));
      await shot('sent-request-en');
      final b = await asPerson(bob, bobToken);
      b.read(appRouterProvider).go(groupContactRequestRoute(request));
      await harness.waitFor(tester, find.byKey(const Key('contact-accept')));
      await shot('creator-triage-en');
      final c = await asPerson(carol, carolToken);
      final cRouter = c.read(appRouterProvider);
      cRouter.go(groupContactRequestRoute(request));
      await tap('contact-accept');
      await tap('contact-confirm-accept');
      await harness.waitFor(tester, find.text('Open conversation'));
      final own = await currentClient!.rpc<Map<String, dynamic>>(
        'get_own_group_contact_request',
        params: {'p_expected_profile_id': carol, 'p_request_id': request},
      );
      final chat = own['chat_id'] as String;
      await tester.tap(find.text('Open conversation'));
      await harness.waitFor(
        tester,
        find.byKey(const Key('contact-message-body')),
      );
      await tester.enterText(
        find.byKey(const Key('contact-message-body')),
        'Fictional human reply from Carol.',
      );
      await hideKeyboard();
      await tap('contact-message-send');
      await harness.waitFor(
        tester,
        find.text('Fictional human reply from Carol.'),
      );
      await shot('human-and-group-en');
      cRouter.go(groupContactInfoRoute(chat));
      await harness.waitFor(tester, find.text('Conversation audience'));
      await shot('audience-en');
      final another = await asPerson(bob, bobToken);
      another.read(appRouterProvider).go(groupContactRequestRoute(request));
      await harness.waitFor(tester, find.text('Accepted'));
      expect(find.text('Open conversation'), findsNothing);
      expect(
        find.text('Private synthetic idea to coordinate local garden tools.'),
        findsNothing,
      );
      await shot('other-manager-metadata-en');
      final coordinator = await asPerson(alice, aliceToken);
      final coordinatorRouter = coordinator.read(appRouterProvider);
      coordinatorRouter.go(groupContactInfoRoute(chat));
      await tap('contact-coordinate');
      await tap('coordination-pick');
      await harness.waitFor(
        tester,
        find.byKey(const Key('coordination-search')),
      );
      await tester.enterText(
        find.byKey(const Key('coordination-search')),
        libraryName,
      );
      await tap('coordination-search-run');
      await hideKeyboard();
      await tap('coordination-group-$library');
      await tap('coordination-use-groups');
      await harness.reveal(tester, find.byKey(const Key('coordination-title')));
      await tester.enterText(
        find.byKey(const Key('coordination-title')),
        'Fresh fictional three-group coordination',
      );
      await harness.reveal(tester, find.byKey(const Key('coordination-note')));
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
        () => coordinatorRouter.routerDelegate.state.uri.path.contains(
          '/group-coordination/',
        ),
      );
      final proposalId =
          coordinatorRouter.routerDelegate.state.uri.pathSegments.last;
      final invitee = await asPerson(dave, daveToken);
      final inviteeRouter = invitee.read(appRouterProvider);
      inviteeRouter.go(coordinationProposalRoute(proposalId));
      await tap('coordination-claim-$library');
      await tap('coordination-confirm-dialog');
      await harness.waitFor(
        tester,
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
      await tap('coordination-confirm');
      await tap('coordination-confirm-dialog');
      final secondConsent = await asPerson(carol, carolToken);
      secondConsent
          .read(appRouterProvider)
          .go(coordinationProposalRoute(proposalId));
      await tap('coordination-confirm');
      await tap('coordination-confirm-dialog');
      final finalConsent = await asPerson(
        dave,
        daveToken,
        loseCoordination: true,
      );
      final finalRouter = finalConsent.read(appRouterProvider);
      finalRouter.go(coordinationProposalRoute(proposalId));
      await tap('coordination-confirm');
      await shot('coordination-exact-audience-en');
      await tap('coordination-confirm-dialog');
      await tap('coordination-recover');
      await tap('coordination-open');
      await harness.waitFor(
        tester,
        find.byKey(const Key('contact-message-body')),
      );
      final freshChat = finalRouter.routerDelegate.state.uri.pathSegments.last;
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
      await harness.waitFor(
        tester,
        find.text('A fresh human message from Fictional Dave.'),
      );
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
      await harness.waitFor(tester, find.text('Coordinamento pronto'));
      await harness.reveal(tester, find.textContaining('Fictional dave'));
      await shot('coordination-audience-it-320dp-2x');
      // Separate bilateral decline/withdraw controls never change the activated
      // coordination seats or either group's membership.
      Future<String> anotherRequest(String target, String subject) async {
        final sender = await asPerson(alice, aliceToken);
        final router = sender.read(appRouterProvider);
        router.go(groupContactComposeRoute(target));
        await harness.waitFor(
          tester,
          find.text('Fictional Neighbourhood Garden'),
        );
        await tester.tap(find.text('Fictional Neighbourhood Garden'));
        await harness.reveal(tester, find.byKey(const Key('contact-title')));
        await tester.enterText(find.byKey(const Key('contact-title')), subject);
        await harness.reveal(tester, find.byKey(const Key('contact-note')));
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
      await harness.waitFor(tester, find.text('Withdrawn'));
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
      await harness.waitFor(tester, find.text('Declined'));
      await shot('explicit-decline-en');
      final bClient = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () => Future.value(bobToken),
      );
      addTearDown(bClient.dispose);
      final reader = await asPerson(alice, aliceToken);
      reader.read(appRouterProvider).go(groupContactChatRoute(chat));
      await harness.waitFor(
        tester,
        find.text('Fictional human reply from Carol.'),
      );
      await tester.pump(const Duration(seconds: 2));
      final unread = await currentClient!.rpc<Map<String, dynamic>>(
        'get_own_message_unread_summary_v2',
        params: {'p_expected_profile_id': alice},
      );
      expect(unread['groups'], startingUnread['groups']);
      await currentClient!.rpc(
        'send_group_contact_message',
        params: {
          'p_expected_profile_id': alice,
          'p_action_id': const Uuid().v4(),
          'p_chat_id': chat,
          'p_body': 'Earlier synthetic message available for reporting.',
        },
      );
      final former = await asPerson(carol, carolToken);
      former.read(appRouterProvider).go(groupContactChatRoute(chat));
      await harness.waitFor(
        tester,
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
      await harness.waitFor(
        tester,
        find.text('Report a previously received message'),
      );
      expect(
        find.text('Earlier synthetic message available for reporting.'),
        findsNothing,
      );
      expect(find.byKey(const Key('contact-message-send')), findsNothing);
      await shot('former-denied-known-report-en');
      await tester.tap(find.text('Report a previously received message'));
      await harness.waitFor(
        tester,
        find.byKey(const Key('moderation-category')),
      );
      await tester.tap(find.byKey(const Key('moderation-category')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Harassment or abuse').last);
      await tester.pump(const Duration(milliseconds: 400));
      await harness.reveal(
        tester,
        find.byKey(const Key('moderation-explanation')),
      );
      await tester.enterText(
        find.byKey(const Key('moderation-explanation')),
        'Fictional report of a previously received synthetic message.',
      );
      await hideKeyboard();
      await tap('moderation-submit');
      await harness.waitFor(
        tester,
        find.byKey(const Key('moderation-received')),
      );
      await shot('protected-report-en');
      // D did not grant Project participation. Its existing request remains explicit.
      final joiner = await asPerson(alice, aliceToken);
      joiner.read(appRouterProvider).go(groupContactInfoRoute(chat));
      await harness.waitFor(tester, find.text('Block Fictional carol'));
      await tester.tap(find.text('Block Fictional carol'));
      await tap('blocking-confirm-block');
      await harness.waitFor(tester, find.text('Unblock Fictional carol'));
      await shot('block-permitted-history-en');
      joiner.read(appRouterProvider).go('/proposals/$project/join');
      await harness.waitFor(
        tester,
        find.byKey(const Key('participation-message-field')),
      );
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
      await harness.reveal(tester, find.text('Fictional Neighbourhood Garden'));
      await shot('composer-it-320dp-2x');
      await harness.reveal(tester, find.byKey(const Key('contact-note')));
      await tester.enterText(
        find.byKey(const Key('contact-note')),
        'Nota sintetica con tastiera italiana.',
      );
      await shot('composer-it-320dp-2x-keyboard');
      await hideKeyboard();
      expect(tester.takeException(), isNull);
    },
  );
}
