import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/group_discussions/application/discussion_project_handoff.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/group_projects/data/group_project_gateway.dart';
import 'package:planets_mobile/features/group_projects/domain/group_project_models.dart';
import 'package:planets_mobile/features/group_projects/domain/group_project_creation_return.dart';
import 'package:planets_mobile/features/locations/data/item_location_gateway.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_creation_choice.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/recurring_activity_editor_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../support/fake_auth.dart';
import '../../support/fake_location.dart';
import '../../support/fake_proposal.dart';
import '../../support/fake_recurring_activity.dart';
import 'discussion_test_support.dart';

class StartGateway extends Gateway {
  Future<DiscussionRoom>? held;
  @override
  Future<DiscussionRoom> room(String a, String r) => held ?? super.room(a, r);
}

class Groups extends GroupProjectGateway {
  Groups() : super(() => throw StateError('No network in widget test.'));
  @override
  Future<String?> publicName(String g) async => 'Garden';
  @override
  Future<List<PublishableGroup>> eligible(
    String a, {
    PublishableGroup? after,
  }) async => [
    PublishableGroup(groupId, 'Garden', 'informal', DateTime.utc(2026, 10, 14)),
  ];
  @override
  Future<ProjectGroupBinding> own(String a, String p) async =>
      const ProjectGroupBinding(groupId: groupId, name: 'Garden', version: 1);
}

void main() {
  for (final lang in ['en', 'it']) {
    testWidgets(
      '$lang acknowledged Tavolo save returns to the retained discussion',
      (tester) async {
        final auth = FakeAuthGateway(
              snapshot: const AuthSnapshot(
                identity: AuthIdentity(id: 'user-1'),
              ),
            ),
            recurring = FakeRecurringActivityGateway();
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.fromValues(
                appEnvironment: 'local',
                supabaseUrl: 'http://127.0.0.1:54321',
                supabasePublishableKey: 'test-key',
              ),
            ),
            authGatewayProvider.overrideWithValue(auth),
            recurringActivityGatewayProvider.overrideWithValue(recurring),
            groupProjectGatewayProvider.overrideWithValue(Groups()),
            itemLocationGatewayProvider.overrideWithValue(
              FakeItemLocationGateway(),
            ),
            profileAnchorGatewayProvider.overrideWithValue(
              FakeProfileAnchorGateway()
                ..readiness = ProfileAnchorReadiness.complete,
            ),
          ],
        );
        container
            .read(authSessionProvider.notifier)
            .markProfileReady(const AuthIdentity(id: 'user-1'));
        final router = GoRouter(
          initialLocation: '/origin',
          routes: [
            GoRoute(
              path: '/origin',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push<Object?>(
                    '/proposals/create?group=$groupId',
                    extra: const GroupProjectCreationReturn('user-1'),
                  ),
                  child: const Text('Retained room'),
                ),
              ),
            ),
            GoRoute(
              path: '/proposals/create',
              builder: (_, s) => ProposalCreationChoice(
                groupId: s.uri.queryParameters['group'],
              ),
            ),
            GoRoute(
              path: '/tavoli/create',
              builder: (_, s) => RecurringActivityEditorScreen(
                initialGroupId: s.uri.queryParameters['group'],
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        addTearDown(container.dispose);
        addTearDown(auth.close);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              locale: Locale(lang),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.tap(find.text('Retained room'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('group-create-tavolo')));
        await tester.pumpAndSettle();
        expect(recurring.calls, isNot(contains('create')));
        await tester.enterText(
          find.byKey(const Key('tavoli-title-field')),
          'Deliberately supplied Tavolo',
        );
        final save = find.byKey(const Key('tavoli-save-draft'));
        await reveal(tester, save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(router.routerDelegate.state.uri.path, '/origin');
        expect(recurring.calls, contains('create'));
        expect(recurring.lastInput?.title, 'Deliberately supplied Tavolo');
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('source entry requires same current admission and publisher role after refresh', () async {
    final g = StartGateway();
    addTearDown(g.hints.close);
    final source = DiscussionRoom(roomRow());
    expect(
      (await checkDiscussionProjectHandoff(
        g,
        actor,
        source,
        () => true,
      )).groupId,
      groupId,
    );
    for (final fields in [
      {'can_publish': false},
      {'admission_id': id(8)},
      {'group_id': id(8)},
      {'archived': true, 'can_manage': false, 'can_publish': false},
    ]) {
      g.context = DiscussionRoom({...roomRow(), ...fields});
      await expectLater(
        checkDiscussionProjectHandoff(g, actor, source, () => true),
        throwsA(isA<PostgrestException>()),
      );
    }
  });
  test(
    'actor/route disposal while source read waits rejects the late handoff',
    () async {
      final g = StartGateway(), held = Completer<DiscussionRoom>();
      var current = true;
      addTearDown(g.hints.close);
      g.held = held.future;
      final pending = checkDiscussionProjectHandoff(
        g,
        actor,
        DiscussionRoom(roomRow()),
        () => current,
      );
      final rejected = expectLater(pending, throwsA(isA<PostgrestException>()));
      current = false;
      held.complete(DiscussionRoom(roomRow()));
      await rejected;
    },
  );
  for (final lang in ['en', 'it']) {
    testWidgets(
      '$lang scratch open/cancel creates nothing; lost save reply returns to retained origin',
      (tester) async {
        final auth = FakeAuthGateway(
              snapshot: const AuthSnapshot(
                identity: AuthIdentity(id: 'user-1'),
              ),
            ),
            proposals = FakeProposalGateway(),
            groups = Groups();
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.fromValues(
                appEnvironment: 'local',
                supabaseUrl: 'http://127.0.0.1:54321',
                supabasePublishableKey: 'test-key',
              ),
            ),
            authGatewayProvider.overrideWithValue(auth),
            proposalGatewayProvider.overrideWithValue(proposals),
            groupProjectGatewayProvider.overrideWithValue(groups),
            itemLocationGatewayProvider.overrideWithValue(
              FakeItemLocationGateway(),
            ),
            profileAnchorGatewayProvider.overrideWithValue(
              FakeProfileAnchorGateway()
                ..readiness = ProfileAnchorReadiness.complete,
            ),
          ],
        );
        container
            .read(authSessionProvider.notifier)
            .markProfileReady(const AuthIdentity(id: 'user-1'));
        final router = GoRouter(
          initialLocation: '/origin',
          routes: [
            GoRoute(
              path: '/origin',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push<Object?>(
                    '/proposals/create?group=$groupId',
                    extra: const GroupProjectCreationReturn('user-1'),
                  ),
                  child: const Text('Retained room'),
                ),
              ),
            ),
            GoRoute(
              path: '/proposals/create',
              pageBuilder: (_, s) => MaterialPage<void>(
                key: s.pageKey,
                child: ProposalCreationChoice(
                  groupId: s.uri.queryParameters['group'],
                ),
              ),
            ),
            GoRoute(
              path: '/proposals/create/scratch',
              pageBuilder: (_, s) => MaterialPage<void>(
                key: s.pageKey,
                child: ProposalEditorScreen(
                  initialGroupId: s.uri.queryParameters['group'],
                ),
              ),
            ),
            GoRoute(
              path: '/proposals/mine',
              builder: (_, _) =>
                  const Scaffold(body: Text('Ordinary personal fallback')),
            ),
          ],
        );
        addTearDown(router.dispose);
        addTearDown(container.dispose);
        addTearDown(auth.close);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              locale: Locale(lang),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.tap(find.text('Retained room'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('proposal-start-scratch')));
        await tester.pumpAndSettle();
        expect(proposals.calls.where((c) => c == 'create'), isEmpty);
        expect(find.text('Garden'), findsWidgets);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('proposal-start-scratch')), findsOneWidget);
        await tester.tap(find.byKey(const Key('proposal-start-scratch')));
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const Key('proposal-title')));
        await tester.enterText(
          find.byKey(const Key('proposal-title')),
          'User supplied idea',
        );
        await reveal(tester, find.byKey(const Key('proposal-summary')));
        await tester.enterText(
          find.byKey(const Key('proposal-summary')),
          'Only deliberately supplied planning content.',
        );
        final mode = find.byKey(const Key('proposal-mode-idea'));
        await reveal(tester, mode);
        await tester.tap(mode);
        await tester.pumpAndSettle();
        final save = find.byKey(const Key('proposal-save-draft'));
        await reveal(tester, save);
        proposals.createResponseError = const SocketException(
          'Lost committed creation response',
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        if (find
            .byKey(const Key('proposal-save-draft'))
            .evaluate()
            .isNotEmpty) {
          await reveal(tester, save);
          await tester.tap(save);
          await tester.pumpAndSettle();
        }
        expect(router.routerDelegate.state.uri.path, '/origin');
        expect(proposals.ownItems.length, 1);
        expect(proposals.lastInput!.title, 'User supplied idea');
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    target,
    160,
    scrollable: scrollable,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
}
