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
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/member_contact/data/member_contact_gateway.dart';
import 'package:planets_mobile/features/member_contact/presentation/member_contact_routes.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_models.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'contact_local_identity.dart';
import 'groups_smoke_test.dart' as harness show waitUntil;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('real member consent, Private chat, safety and origin lifetime', (
    tester,
  ) async {
    final config = AppConfig.fromCompileTime();
    if (config.environment != AppEnvironment.local ||
        !['localhost', '127.0.0.1', '::1'].contains(config.supabaseUrl.host)) {
      throw StateError(
        'Disposable loopback configuration and adb reverse required.',
      );
    }
    const alice = String.fromEnvironment('M_ALICE_ID'),
        aliceToken = String.fromEnvironment('M_ALICE_TOKEN'),
        bob = String.fromEnvironment('M_BOB_ID'),
        bobToken = String.fromEnvironment('M_BOB_TOKEN'),
        owner = String.fromEnvironment('M_OWNER_ID'),
        ownerToken = String.fromEnvironment('M_OWNER_TOKEN'),
        closeGroup = String.fromEnvironment('M_CLOSE_GROUP'),
        leaveGroup = String.fromEnvironment('M_LEAVE_GROUP'),
        contextGroup = String.fromEnvironment('M_CONTEXT_GROUP');
    if ([
      alice,
      aliceToken,
      bob,
      bobToken,
      owner,
      ownerToken,
      closeGroup,
      leaveGroup,
      contextGroup,
    ].any((s) => s.isEmpty)) {
      throw StateError('Prepare fresh local member contact defines first.');
    }
    // The owner configures the real device width. Do not fake a smaller surface
    // and mislabel physical frames; only the explicit accessibility scale is
    // injected in the test platform dispatcher, as in widget accessibility QA.
    expect(
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
      closeTo(320, 0.5),
      reason: 'Configure the owned emulator to actual 320dp.',
    );
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SupabaseClient makeClient(String token) => SupabaseClient(
      config.supabaseUrl.toString(),
      config.supabasePublishableKey,
      accessToken: () => Future.value(token),
    );
    final ownerClient = makeClient(ownerToken);
    final aliceClient = makeClient(aliceToken);
    final bobClient = makeClient(bobToken);
    SupabaseClient? currentClient;
    ProviderContainer? currentScope;
    var identityEpoch = 0, submits = 0;
    var dropped = false;
    String? submittedRequest;
    Future<ProviderContainer> asPerson(
      String id,
      String token, {
      bool loseSubmit = false,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      currentScope?.dispose();
      currentScope = null;
      await currentClient?.dispose();
      currentClient = null;
      final client = makeClient(token);
      currentClient = client;
      final scope = ProviderContainer(
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
          memberContactGatewayProvider.overrideWithValue(
            MemberContactGateway((name, args) async {
              final result = await client.rpc<Object?>(name, params: args);
              if (name == 'submit_member_contact_request') {
                submits++;
                submittedRequest = (result as Map)['request_id'] as String;
                if (loseSubmit && !dropped) {
                  dropped = true;
                  throw const SocketException(
                    'Synthetic lost response after real member request commit.',
                  );
                }
              }
              return result;
            }, signalClient: client),
          ),
        ],
      );
      currentScope = scope;
      await scope.read(authSessionProvider.notifier).start();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          key: ValueKey(++identityEpoch),
          container: scope,
          child: const PlanetsApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await harness.waitUntil(
        tester,
        () => scope.read(authSessionProvider).phase == AuthSessionPhase.ready,
      );
      return scope;
    }

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      currentScope?.dispose();
      await currentClient?.dispose();
      await ownerClient.dispose();
      await aliceClient.dispose();
      await bobClient.dispose();
    });
    AppLocalizations strings() =>
        AppLocalizations.of(tester.element(find.byType(Scaffold).last));
    Future<void> reveal(Finder finder) async {
      // Build below-fold lazy rows through the route's scroll view. EditableText
      // owns another Scrollable that cannot reveal an action after the field.
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      ScrollPosition? searched;
      while (DateTime.now().isBefore(deadline)) {
        if (finder.evaluate().isNotEmpty) {
          await tester.ensureVisible(finder.first);
          await tester.pump(const Duration(milliseconds: 200));
          if (finder.hitTestable().evaluate().isNotEmpty) return;
        }
        final elements = find
            .byType(Scrollable)
            .evaluate()
            .where(
              (element) =>
                  ModalRoute.of(element)?.isCurrent != false &&
                  element.findAncestorWidgetOfExactType<EditableText>() == null,
            );
        if (elements.isNotEmpty) {
          final position =
              ((elements.last as StatefulElement).state as ScrollableState)
                  .position;
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
      debugPrint('M native missing visible content: $finder');
      await binding
          .takeScreenshot('m02-missing-visible-content')
          .timeout(const Duration(seconds: 30));
      expect(
        finder.hitTestable(),
        findsWidgets,
        reason: 'Real native content must load and become visible.',
      );
    }

    Future<void> tapFinder(Finder finder) async {
      await reveal(finder);
      expect(finder.hitTestable(), findsOneWidget);
      await harness.waitUntil(tester, () {
        final matches = finder.evaluate();
        if (matches.isEmpty) return false;
        final widget = matches.first.widget;
        return widget is! ButtonStyleButton || widget.onPressed != null;
      });
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> tap(String key) => tapFinder(find.byKey(Key(key)));
    Future<void> hideKeyboard() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> loaded() => harness.waitUntil(
      tester,
      () =>
          find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty,
    );
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
      await loaded();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: 'Native layout $name');
      final context = tester.element(find.byType(Scaffold).last);
      expect(MediaQuery.sizeOf(context).width, closeTo(320, 0.5));
      expect(MediaQuery.textScalerOf(context).scale(10), 20);
      debugPrint('M native checkpoint: $name, actual 320dp, text scale 2x.');
      await binding
          .takeScreenshot('m02-$name-320-2x')
          .timeout(const Duration(seconds: 30));
    }

    Future<void> language(LanguagePreference value) async {
      expect(
        await currentScope!
            .read(languagePreferenceProvider.notifier)
            .select(value),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> shotPair(String name) async {
      await shot('$name-en');
      await language(LanguagePreference.italian);
      await shot('$name-it');
      await language(LanguagePreference.english);
    }

    // Confirmation builders deliberately capture the copy shown when opened.
    // Reopen after changing language so the IT evidence is an actual IT dialog.
    Future<void> dialogPair(String name, Future<void> Function() open) async {
      Future<void> cancel() => tapFinder(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        ),
      );
      await shot('$name-en');
      await cancel();
      await language(LanguagePreference.italian);
      await open();
      await shot('$name-it');
      await cancel();
      await language(LanguagePreference.english);
      await open();
    }

    Future<Map<String, dynamic>> conversation(
      SupabaseClient client,
      String actor,
      String chat,
    ) => client.rpc<Map<String, dynamic>>(
      'get_own_member_contact_conversation',
      params: {'p_expected_profile_id': actor, 'p_chat_id': chat},
    );
    Future<void> untilRpc(
      Future<bool> Function() predicate,
      String reason,
    ) async {
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (DateTime.now().isBefore(deadline)) {
        if (await predicate()) return;
        await tester.pump(const Duration(milliseconds: 250));
      }
      fail(reason);
    }

    Future<void> deniedSend(
      SupabaseClient client,
      String actor,
      String chat,
      String episode,
    ) async {
      await expectLater(
        client.rpc(
          'send_member_contact_message',
          params: {
            'p_expected_profile_id': actor,
            'p_action_id': const Uuid().v4(),
            'p_chat_id': chat,
            'p_episode_id': episode,
            'p_body': 'Must never be delivered.',
          },
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.code,
            'code',
            anyOf('42501', 'PT409'),
          ),
        ),
      );
    }

    Future<void> confirmDialog() => tapFinder(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    Future<void> send(String body) async {
      await reveal(find.byKey(const Key('contact-message-body')));
      await tester.enterText(
        find.byKey(const Key('contact-message-body')),
        body,
      );
      await hideKeyboard();
      await tap('contact-message-send');
      await reveal(find.text(body));
    }

    // All three episodes begin through canonical private People and explicit
    // named consent. No request, episode or message rows are inserted by SQL.
    Future<({String chat, String episode, String request})> consent(
      String group,
      String label, {
      bool loseSubmit = false,
      bool evidence = false,
    }) async {
      final sender = await asPerson(alice, aliceToken, loseSubmit: loseSubmit);
      final router = sender.read(appRouterProvider);
      router.go('/groups/$group');
      await tap('group-people');
      await tapFinder(find.text('Fictional Bob'));
      await reveal(find.text(strings().memberContactAction));
      if (evidence) await shotPair('people-sheet');
      await tapFinder(find.text(strings().memberContactAction));
      await reveal(find.byKey(const Key('member-contact-note')));
      final before = submits;
      await tester.enterText(
        find.byKey(const Key('member-contact-note')),
        'Synthetic $label introduction for Fictional Bob.',
      );
      expect(submits, before, reason: 'Opening/editing never sends a request.');
      if (evidence) await shotPair('request-keyboard');
      await hideKeyboard();
      await tap('member-contact-submit');
      if (loseSubmit) {
        await reveal(find.text(strings().contactDeliveryPending));
        if (evidence) await shotPair('request-ambiguous');
        await tapFinder(find.text(strings().contactRecover));
      }
      await harness.waitUntil(
        tester,
        () => router.routerDelegate.state.uri.path.contains(
          '/requests/member-contact/',
        ),
      );
      final request = router.routerDelegate.state.uri.pathSegments.last;
      expect(request, submittedRequest);
      expect(
        submits,
        before + 1,
        reason: 'Recovery reads the original committed receipt.',
      );
      await reveal(find.text(strings().contactPending));
      if (evidence) await shotPair('outgoing-request');
      final recipient = await asPerson(bob, bobToken);
      final receiverRouter = recipient.read(appRouterProvider);
      receiverRouter.go('/messages');
      await tap('messages-requests-action');
      await reveal(find.byKey(Key('member-contact-request-$request')));
      if (evidence) await shotPair('requests-inbox');
      await tapFinder(
        find.descendant(
          of: find.byKey(Key('member-contact-request-$request')),
          matching: find.byType(ListTile),
        ),
      );
      await reveal(find.byKey(const Key('contact-accept')));
      expect(
        (await bobClient.rpc<Map<String, dynamic>>(
          'get_own_member_contact_request',
          params: {'p_expected_profile_id': bob, 'p_request_id': request},
        ))['status'],
        'pending',
      );
      if (evidence) await shotPair('incoming-request');
      await tap('contact-accept');
      if (evidence) {
        await dialogPair('explicit-accept', () => tap('contact-accept'));
      }
      // Even opening the informed confirmation has not accepted the request.
      expect(
        (await bobClient.rpc<Map<String, dynamic>>(
          'get_own_member_contact_request',
          params: {'p_expected_profile_id': bob, 'p_request_id': request},
        ))['status'],
        'pending',
      );
      await tap('contact-confirm-accept');
      await reveal(find.text(strings().contactOpen));
      final accepted = await bobClient.rpc<Map<String, dynamic>>(
        'get_own_member_contact_request',
        params: {'p_expected_profile_id': bob, 'p_request_id': request},
      );
      expect(accepted['status'], 'accepted');
      await tapFinder(find.text(strings().contactOpen));
      await send('Synthetic $label reply from Fictional Bob.');
      if (evidence) await shotPair('accepted-human-message');
      return (
        chat: accepted['chat_id'] as String,
        episode: accepted['episode_id'] as String,
        request: request,
      );
    }

    await asPerson(alice, aliceToken);
    await binding.convertFlutterSurfaceToImage();
    final primary = await consent(
      closeGroup,
      'close',
      loseSubmit: true,
      evidence: true,
    );
    await expectLater(
      ownerClient.rpc(
        'get_own_member_contact_conversation',
        params: {'p_expected_profile_id': owner, 'p_chat_id': primary.chat},
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    await expectLater(
      ownerClient.rpc(
        'get_own_member_contact_request',
        params: {
          'p_expected_profile_id': owner,
          'p_request_id': primary.request,
        },
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    final reader = await asPerson(alice, aliceToken);
    final readerRouter = reader.read(appRouterProvider);
    expect(
      (await conversation(aliceClient, alice, primary.chat))['unread_count'],
      1,
    );
    readerRouter.go(memberContactInfoRoute(primary.chat));
    await reveal(find.byKey(const Key('member-contact-mute')));
    await tap('member-contact-mute');
    await untilRpc(
      () async =>
          (await conversation(aliceClient, alice, primary.chat))['muted'] ==
          true,
      'Mute must persist canonically.',
    );
    expect(
      (await conversation(aliceClient, alice, primary.chat))['unread_count'],
      1,
      reason: 'Settings and mute do not acknowledge an unseen message.',
    );
    await shotPair('muted-settings');
    readerRouter.go('/messages');
    await tap('message-chat-scope-private');
    await reveal(find.byKey(Key('member-contact-chat-${primary.chat}')));
    expect(
      (await conversation(aliceClient, alice, primary.chat))['unread_count'],
      1,
      reason: 'A Private list preview is not a rendered conversation frontier.',
    );
    await shotPair('private-unread');
    await tap('message-chat-scope-groups');
    await loaded();
    expect(
      find.byKey(Key('member-contact-chat-${primary.chat}')),
      findsNothing,
    );
    await tap('message-chat-scope-private');
    await tapFinder(
      find.descendant(
        of: find.byKey(Key('member-contact-chat-${primary.chat}')),
        matching: find.byType(ListTile),
      ),
    );
    await reveal(find.text('Synthetic close reply from Fictional Bob.'));
    await untilRpc(
      () async =>
          (await conversation(
            aliceClient,
            alice,
            primary.chat,
          ))['unread_count'] ==
          0,
      'Visible foreground feed must acknowledge its bounded frontier.',
    );
    await send('Synthetic reply from Fictional Alice.');
    await shotPair('private-human-chat');
    await tap('contact-chat-info');
    await tapFinder(find.text(strings().blockingBlockGenericAction));
    await dialogPair(
      'block-confirmation',
      () => tapFinder(find.text(strings().blockingBlockGenericAction)),
    );
    await tap('blocking-confirm-block');
    await reveal(find.text(strings().blockingUnblockGenericAction));
    expect(
      (await conversation(aliceClient, alice, primary.chat))['is_read_only'],
      true,
    );
    await deniedSend(bobClient, bob, primary.chat, primary.episode);
    readerRouter.go(memberContactChatRoute(primary.chat));
    await reveal(find.text(strings().memberContactReadOnly));
    expect(find.byKey(const Key('contact-message-send')), findsNothing);
    await shotPair('blocked-retained-history');
    readerRouter.go(memberContactInfoRoute(primary.chat));
    await tapFinder(find.text(strings().blockingUnblockGenericAction));
    await tap('blocking-confirm-unblock');
    await reveal(find.text(strings().blockingBlockGenericAction));
    await tap('member-contact-close');
    await dialogPair('close-confirmation', () => tap('member-contact-close'));
    await confirmDialog();
    await reveal(find.text(strings().memberContactReadOnly));
    final closed = await conversation(aliceClient, alice, primary.chat);
    expect(closed['ended_reason'], 'closed');
    expect(closed['current_episode_id'], isNull);
    await deniedSend(bobClient, bob, primary.chat, primary.episode);
    readerRouter.go(memberContactChatRoute(primary.chat));
    await reveal(find.text(strings().memberContactReadOnly));
    await shotPair('closed-history');

    final leave = await consent(leaveGroup, 'leave');
    final context = await consent(contextGroup, 'context');
    expect(
      {primary.chat, leave.chat, context.chat},
      hasLength(3),
      reason: 'The same pair has distinct origin-Group anchors.',
    );
    currentScope!
        .read(appRouterProvider)
        .go(memberContactInfoRoute(leave.chat));
    await tap('member-contact-leave');
    await dialogPair('leave-confirmation', () => tap('member-contact-leave'));
    await confirmDialog();
    await reveal(find.text(strings().memberContactReadOnly));
    expect(
      (await conversation(bobClient, bob, leave.chat))['ended_reason'],
      'left',
    );
    expect(
      (await conversation(bobClient, bob, context.chat))['is_read_only'],
      false,
      reason: 'Leaving one origin does not end another accepted origin.',
    );
    currentScope!
        .read(appRouterProvider)
        .go(memberContactChatRoute(leave.chat));
    await reveal(find.text(strings().memberContactReadOnly));
    await shotPair('left-history');

    // End the last ordinary relationship through the actual Group Leave UI.
    // No delegated role survives in this fixture.
    currentScope!.read(appRouterProvider).go('/groups/$contextGroup');
    await tap('group-leave');
    await confirmDialog();
    await untilRpc(
      () async =>
          (await conversation(bobClient, bob, context.chat))['is_read_only'] ==
          true,
      'Last origin relationship loss must end its accepted episode.',
    );
    final ended = await conversation(bobClient, bob, context.chat);
    expect(ended['ended_reason'], 'context_ended');
    expect(ended['current_episode_id'], isNull);
    await deniedSend(bobClient, bob, context.chat, context.episode);
    currentScope!
        .read(appRouterProvider)
        .go(memberContactChatRoute(context.chat));
    await reveal(find.text(strings().memberContactReadOnly));
    await shotPair('context-ended-history');
    final invitations = await ownerClient.rpc<List<dynamic>>(
      'create_group_participant_invitation',
      params: {
        'p_expected_profile_id': owner,
        'p_group_id': contextGroup,
        'p_client_request_id': const Uuid().v4(),
      },
    );
    await bobClient.rpc(
      'accept_group_participant_invitation',
      params: {
        'p_expected_profile_id': bob,
        'p_token': invitations.single['invite_token'],
        'p_client_request_id': const Uuid().v4(),
      },
    );
    final rejoined = await asPerson(bob, bobToken);
    rejoined.read(appRouterProvider).go('/groups/$contextGroup');
    await tap('group-people');
    await reveal(find.text('Fictional Alice'));
    expect(
      (await conversation(bobClient, bob, context.chat))['is_read_only'],
      true,
    );
    await deniedSend(bobClient, bob, context.chat, context.episode);
    rejoined.read(appRouterProvider).go(memberContactChatRoute(context.chat));
    await reveal(find.text(strings().memberContactReadOnly));
    expect(find.byKey(const Key('contact-message-send')), findsNothing);
    await shotPair('rejoined-no-revival');

    // Exact historical incoming evidence remains reportable after origin loss.
    final reporter = await asPerson(alice, aliceToken);
    reporter.read(appRouterProvider).go(memberContactChatRoute(context.chat));
    await reveal(find.text('Synthetic context reply from Fictional Bob.'));
    final feed = await aliceClient.rpc<Map<String, dynamic>>(
      'get_own_member_contact_feed',
      params: {'p_expected_profile_id': alice, 'p_chat_id': context.chat},
    );
    final message = (feed['items'] as List).single as Map;
    await tapFinder(find.text(strings().contactMessageReport));
    await reveal(find.byKey(const Key('moderation-category')));
    final target =
        reporter.read(appRouterProvider).routerDelegate.state.extra
            as ModerationReportTarget;
    expect(target.kind, ModerationTargetKind.memberContactMessage);
    expect(target.id, message['id']);
    await tap('moderation-category');
    await tapFinder(find.text('Harassment or abuse').last);
    await reveal(find.byKey(const Key('moderation-explanation')));
    await tester.enterText(
      find.byKey(const Key('moderation-explanation')),
      'Fictional report of known historical member message.',
    );
    await hideKeyboard();
    await tap('moderation-submit');
    await reveal(find.byKey(const Key('moderation-received')));
    await shotPair('historical-message-report');
    final reports = await aliceClient.rpc<List<dynamic>>(
      'list_own_moderation_reports_v4',
      params: {'p_expected_reporter_profile_id': alice},
    );
    expect(
      reports.where(
        (row) =>
            row['target_kind'] == 'member_contact_message' &&
            row['explanation'] ==
                'Fictional report of known historical member message.',
      ),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });
}
