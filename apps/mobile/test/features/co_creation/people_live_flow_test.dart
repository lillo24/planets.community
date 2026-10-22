import 'package:planets_mobile/features/co_creation/data/co_creation_sources_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/co_creation/application/people_signals.dart';
import 'package:planets_mobile/features/co_creation/data/people_posts_gateway.dart';
import 'package:planets_mobile/features/co_creation/data/people_private_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_browse_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_manage_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_message_items.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_contact_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_exit_screens.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/policies/application/policy_documents.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/rendered_evidence.dart';

const author = 'cb020000-0000-4000-8000-000000000001';
const requester = 'cb020000-0000-4000-8000-000000000002';
const post = 'cb020000-0000-4000-8000-000000000003';
const interest = 'cb020000-0000-4000-8000-000000000004';
const contact = 'cb020000-0000-4000-8000-000000000005';

class Session extends AuthSessionController {
  @override
  AuthSessionState build() => const AuthSessionState.signedOut();
  void change(String id) =>
      state = AuthSessionState.ready(AuthIdentity(id: id));
}

class Policy extends PolicyAcceptanceController {
  void requirePolicy() => state = PolicyAcceptanceState(
    state.account,
    state.version,
    PolicyAcceptancePhase.required,
  );
  @override
  PolicyAcceptanceState build() => PolicyAcceptanceState(
    ref.watch(authSessionProvider).identity?.id,
    policyBundleVersion,
    PolicyAcceptancePhase.accepted,
  );
}

class Fixture {
  bool enabled = true,
      failRead = false,
      loseCreate = false,
      requested = false,
      accepted = false;
  String note = '';
  final commands = <Map<String, dynamic>>[];
  Map<String, Object?> publicPost() => {
    'post_id': post,
    'title': 'Synthetic football',
    'body': 'A deliberately public fictional post.',
    'locality': 'Trento',
    'topic_id': null,
    'created_at': '2026-10-22T10:00:00Z',
    'expires_at': '2026-11-21T10:00:00Z',
  };
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    if (failRead) throw StateError('Offline');
    switch (name) {
      case 'get_cocreate_contact_group':
        return {
          'profile_id': args['p_expected_profile_id'],
          'contact_id': args['p_contact_id'],
          'link': null,
        };
      case 'list_cocreate_group_projects':
        return [];
      case 'get_cocreate_availability':
        return {'enabled': enabled};
      case 'list_cocreate_topics':
        return [];
      case 'list_cocreate_posts':
        return [publicPost()];
      case 'get_cocreate_post':
        return publicPost();
      case 'list_own_cocreate_posts':
        return [
          {
            ...publicPost(),
            'state': 'draft',
            'version': 1,
            'suppressed': false,
          },
        ];
      case 'mutate_cocreate_post':
        commands.add(args);
        if (loseCreate && commands.length == 1) {
          throw StateError('Lost response');
        }
        return {'post_id': post, 'version': 1, 'state': 'draft'};
      case 'mutate_cocreate_interest':
        commands.add(args);
        if (args['p_operation'] == 'request') {
          requested = true;
          note = args['p_note'] as String;
        }
        if (args['p_operation'] == 'accept') accepted = true;
        return {
          'interest_id': interest,
          'state': accepted ? 'accepted' : 'pending',
          'contact_id': accepted ? contact : null,
        };
      case 'list_own_cocreate_interests_v2':
        return requested
            ? [
                {
                  'interest_id': interest,
                  'post_id': post,
                  'post_title': 'Synthetic football',
                  'requester_id': requester,
                  'note': note,
                  'state': accepted ? 'accepted' : 'pending',
                  'created_at': '2026-10-22T10:00:00Z',
                  'contact_id': accepted ? contact : null,
                },
              ]
            : [];
      case 'get_cocreate_contact_page':
        return {
          'profile_id': args['p_expected_profile_id'],
          'contact_id': contact,
          'closed': false,
          'messages': [],
          'read_token': null,
        };
      case 'mutate_cocreate_contact':
        commands.add(args);
        return {
          'contact_id': contact,
          'message_id': null,
          'operation': 'close',
        };
      default:
        throw StateError('Unexpected fixture RPC: $name');
    }
  }
}

Future<(ProviderContainer, GoRouter)> pump(
  WidgetTester tester,
  Fixture fixture, {
  String language = 'en',
  String path = '/people',
  bool large = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(Session.new),
      policyAcceptanceProvider.overrideWith(Policy.new),
      coCreationSourcesGatewayProvider.overrideWithValue(
        CoCreationSourcesGateway(fixture.rpc),
      ),
      peoplePostsGatewayProvider.overrideWithValue(
        PeoplePostsGateway(fixture.rpc),
      ),
      peoplePrivateGatewayProvider.overrideWithValue(
        PeoplePrivateGateway(fixture.rpc),
      ),
      peopleSignalsProvider.overrideWith((ref) => const Stream.empty()),
    ],
  );
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(path: '/people', builder: (_, _) => const PeopleBrowseScreen()),
      GoRoute(
        path: '/people/compose',
        builder: (_, _) => const PeopleComposerScreen(),
      ),
      GoRoute(
        path: '/people/mine',
        builder: (_, _) => const PeopleOwnPostsScreen(),
      ),
      GoRoute(
        path: '/people/posts/:id',
        builder: (_, s) =>
            PeoplePostScreen(postId: PostId.parse(s.pathParameters['id'])),
      ),
      GoRoute(
        path: '/messages/cocreate/requests',
        builder: (_, _) => const PeopleRequestsScreen(),
      ),
      GoRoute(
        path: '/messages/cocreate/contacts/:id',
        builder: (_, _) => const PeopleContactScreen(contactId: contact),
      ),
      GoRoute(
        path: '/messages/cocreate/contacts/:id/close',
        builder: (_, _) => const PeopleContactCloseScreen(contactId: contact),
      ),
      GoRoute(
        path: '/messages',
        builder: (_, _) => const Scaffold(body: Text('Native Messages')),
      ),
      GoRoute(
        path: '/people/demo',
        builder: (_, _) => const Scaffold(body: Text('Explicit Demo')),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, _) => const Scaffold(body: Text('Auth continuation')),
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
      child: RenderedEvidence.wrap(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, router);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('own-exit exception is exact and never authorizes a transcript or send route', () {
    expect(
      isPeopleOwnExitPath('/messages/cocreate/contacts/$contact/close'),
      isTrue,
    );
    expect(
      isPeopleOwnExitPath(
        '/messages/cocreate/posts/$post/interests/$interest/withdraw',
      ),
      isTrue,
    );
    for (final path in [
      '/messages/cocreate/contacts/$contact',
      '/messages/cocreate/contacts/demo/close',
      '/people/posts/$post/close',
      '/messages/cocreate/contacts/$contact/close/send',
      '/messages/cocreate/contacts/$contact/close/',
    ]) {
      expect(isPeopleOwnExitPath(path), isFalse);
    }
  });
  testWidgets(
    'own close remains identity-only with gate OFF and policy required',
    (tester) async {
      final f = Fixture()..enabled = false;
      final (app, router) = await pump(
        tester,
        f,
        path: '/messages/cocreate/contacts/$contact/close',
      );
      (app.read(authSessionProvider.notifier) as Session).change(requester);
      await tester.pumpAndSettle();
      (app.read(policyAcceptanceProvider.notifier) as Policy).requirePolicy();
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(FilledButton, 'Close'));
      expect(f.commands.single['p_operation'], 'close');
      expect(router.routeInformationProvider.value.uri.path, '/messages');
      expect(find.text('Native Messages'), findsOneWidget);
    },
  );
  setUpAll(() => RenderedEvidence.loadFonts(force: true));
  for (final language in ['en', 'it']) {
    testWidgets('backend browse/detail at 320dp 2x $language has no overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = Fixture();
      await pump(tester, fixture, language: language, large: true);
      await tap(tester, find.text('Synthetic football'));
      expect(
        find.text('A deliberately public fictional post.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await RenderedEvidence.capture(
        tester,
        'people-live-detail-$language-320-2x',
      );
    });
  }
  testWidgets(
    'disabled/error never substitute fixtures and Demo requires a deliberate action',
    (tester) async {
      final f = Fixture()..enabled = false;
      final (_, router) = await pump(tester, f);
      expect(find.text('Synthetic football'), findsNothing);
      expect(
        find.text('The co-creation experiment is unavailable.'),
        findsOneWidget,
      );
      await tap(tester, find.text('Open fictional Demo'));
      expect(find.text('Explicit Demo'), findsOneWidget);
      f.failRead = true;
      router.go('/people');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Refresh'));
      expect(find.text('Synthetic football'), findsNothing);
      expect(find.text('Explicit Demo'), findsNothing);
      expect(find.textContaining('Could not load'), findsWidgets);
    },
  );
  testWidgets(
    'composer preserves auth input without submission then retries exact frozen intent',
    (tester) async {
      final f = Fixture()..loseCreate = true;
      final (app, router) = await pump(tester, f, path: '/people/compose');
      await tester.enterText(find.byType(TextField).at(0), 'Keep this title');
      await tap(
        tester,
        find.text('Sign in or complete your profile to continue'),
      );
      expect(f.commands, isEmpty);
      (app.read(authSessionProvider.notifier) as Session).change(author);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Keep this title'), findsOneWidget);
      expect(f.commands, isEmpty);
      await tap(tester, find.text('Save draft'));
      expect(find.textContaining('Delivery uncertain'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      await tap(tester, find.text('Retry'));
      expect(f.commands.length, 2);
      expect(f.commands[0], f.commands[1]);
      expect(router.routeInformationProvider.value.uri.path, '/people/mine');
    },
  );
  testWidgets(
    'requester consent, author acceptance and accepted contact route remain distinct',
    (tester) async {
      final f = Fixture();
      final (app, router) = await pump(tester, f, path: '/people/posts/$post');
      (app.read(authSessionProvider.notifier) as Session).change(requester);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'A private fictional note',
      );
      await tap(tester, find.text('Interested'));
      expect(f.requested, isTrue);
      expect(f.accepted, isFalse);
      expect(find.text('Withdraw'), findsOneWidget);
      (app.read(authSessionProvider.notifier) as Session).change(author);
      await tester.pumpAndSettle();
      expect(find.text('Withdraw'), findsNothing);
      await tap(tester, find.text('Accept and open conversation'));
      expect(f.accepted, isTrue);
      await tap(tester, find.text('Accepted contact'));
      expect(find.byType(PeopleContactScreen), findsOneWidget);
      expect(find.text('A private fictional note'), findsNothing);
      expect(find.text('Message'), findsOneWidget);
    },
  );
  testWidgets('switching accounts clears a private composer and pending note', (
    tester,
  ) async {
    final (app, _) = await pump(tester, Fixture(), path: '/people/compose');
    (app.read(authSessionProvider.notifier) as Session).change(author);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Private unfinished input',
    );
    (app.read(authSessionProvider.notifier) as Session).change(requester);
    await tester.pumpAndSettle();
    expect(find.text('Private unfinished input'), findsNothing);
  });
}
