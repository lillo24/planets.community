import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/application/return_destination.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/features/moderation/data/moderation_gateway.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_proposal.dart';
import '../../support/fake_recurring_activity.dart';

import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';

import '../../support/fake_policy.dart';
import '../../support/fake_profile.dart';
import '../../support/fake_moderation.dart';
import 'group_contract_test.dart' show actor, id, row;

Future<ProviderContainer> pumpGroups(
  WidgetTester tester, {
  required GroupGateway gateway,
  FakeAuthGateway? auth,
  bool ready = false,
  String path = '/groups',
  FakePolicyAcceptanceStore? policy,
  FakeModerationGateway? moderation,
}) async {
  final identity =
      auth ??
      FakeAuthGateway(
        snapshot: ready
            ? const AuthSnapshot(identity: AuthIdentity(id: actor))
            : const AuthSnapshot(),
      );
  final anchor = FakeProfileAnchorGateway()
    ..readiness = ProfileAnchorReadiness.complete;
  addTearDown(identity.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'test-key',
          ),
        ),
        authGatewayProvider.overrideWithValue(identity),
        profileAnchorGatewayProvider.overrideWithValue(anchor),
        profileGatewayProvider.overrideWithValue(FakeProfileGateway()),
        policyAcceptanceStoreProvider.overrideWithValue(
          policy ?? FakePolicyAcceptanceStore(preaccepted: true),
        ),
        groupGatewayProvider.overrideWithValue(gateway),
        proposalGatewayProvider.overrideWithValue(FakeProposalGateway()),
        recurringActivityGatewayProvider.overrideWithValue(
          FakeRecurringActivityGateway(),
        ),
        moderationGatewayProvider.overrideWithValue(
          moderation ?? FakeModerationGateway(),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PlanetsApp)),
  );
  container.read(appRouterProvider).go(path);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final publication in ['draft', 'published']) {
    for (final saveChanges in [false, true]) {
      testWidgets(
        'OA1 $publication departure labels preserve cancel/discard/save ($saveChanges)',
        (tester) async {
          var writes = 0;
          var version = 1;
          var title = 'Fictional garden';
          final c = await pumpGroups(
            tester,
            ready: true,
            path: '/groups/$id/edit',
            gateway: GroupGateway((name, args) async {
              if (name == 'get_own_group') {
                return [row(state: publication, version: version, name: title)];
              }
              if (name == 'recover_group_command') return [];
              if (name == 'update_group') {
                expect(args.containsKey('p_publication_state'), isFalse);
                writes++;
                title = (args['p_content'] as Map)['name'] as String;
                return ++version;
              }
              if (name == 'get_public_group' || name == 'list_public_groups') {
                return [];
              }
              throw StateError(name);
            }),
          );
          await tester.enterText(
            find.byKey(const Key('group-name')),
            'Changed fictional group',
          );
          await tester.tap(find.byKey(const Key('page-close')));
          await tester.pumpAndSettle();
          final label = publication == 'published'
              ? 'Save live changes'
              : 'Save draft';
          expect(find.widgetWithText(FilledButton, label).last, findsOneWidget);
          await tester.tap(find.text('Keep editing'));
          await tester.pumpAndSettle();
          expect(writes, 0);
          expect(
            c.read(appRouterProvider).routerDelegate.state.uri.path,
            '/groups/$id/edit',
          );
          await tester.tap(find.byKey(const Key('page-close')));
          await tester.pumpAndSettle();
          if (saveChanges) {
            await tester.tap(find.widgetWithText(FilledButton, label).last);
          } else {
            await tester.tap(find.text('Discard changes'));
          }
          await tester.pumpAndSettle();
          expect(writes, saveChanges ? 1 : 0);
          expect(
            title,
            saveChanges ? 'Changed fictional group' : 'Fictional garden',
          );
        },
      );
    }
  }

  test('group cancel destinations are public and cannot repeat protected continuations', () {
    for (final path in ['/groups/create', '/groups/mine']) {
      expect(authCancelDestination(path), '/groups');
      expect(profileEditCancelDestination(path), '/groups');
    }
    expect(authCancelDestination('/groups/$id/report'), '/groups/$id');
    expect(profileEditCancelDestination('/groups/$id/edit'), '/groups/$id');
  });
  testWidgets(
    'guest directory does not drain short pages or lose filters on detail pop',
    (tester) async {
      var calls = 0;
      final gateway = GroupGateway((name, args) async {
        if (name == 'list_public_groups') {
          calls++;
          return [row()];
        }
        if (name == 'get_public_group') return [row()];
        throw StateError(name);
      });
      final c = await pumpGroups(tester, gateway: gateway);
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 1);
      await tester.enterText(find.byKey(const Key('groups-search')), 'garden');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.ensureVisible(find.byKey(const Key('group-card-$id')));
      await tester.tap(find.byKey(const Key('group-card-$id')));
      await tester.pumpAndSettle();
      expect(
        c.read(appRouterProvider).routerDelegate.state.uri.path,
        '/groups/$id',
      );
      expect(find.byKey(const Key('group-manage')), findsNothing);
      await tester.tap(find.byKey(const Key('page-close')));
      await tester.pumpAndSettle();
      expect(find.text('garden'), findsOneWidget);
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unavailable and API errors stay distinct', (tester) async {
    Object? response = [];
    final c = await pumpGroups(
      tester,
      path: '/groups/$id',
      gateway: GroupGateway((_, _) async => response),
    );
    expect(find.text('This group is unavailable.'), findsOneWidget);
    response = {};
    c.read(appRouterProvider).go('/groups');
    await tester.pumpAndSettle();
    c.read(appRouterProvider).go('/groups/$id');
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.text('This group is unavailable.'), findsNothing);
  });
  testWidgets(
    'guest report OTP return preserves genuine target; cancellation returns public detail',
    (tester) async {
      final auth = FakeAuthGateway()
        ..verifiedIdentity = const AuthIdentity(id: actor);
      final moderation = FakeModerationGateway();
      final c = await pumpGroups(
        tester,
        auth: auth,
        moderation: moderation,
        policy: FakePolicyAcceptanceStore()
          ..readError = StateError("policy unavailable"),
        path: '/groups/$id',
        gateway: GroupGateway((name, args) async => [row()]),
      );
      await tester.tap(find.byKey(const Key('group-report')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
      await tester.tap(find.byKey(const Key('auth-close-button')));
      await tester.pumpAndSettle();
      expect(
        c.read(appRouterProvider).routerDelegate.state.uri.path,
        '/groups/$id',
      );
      await tester.tap(find.byKey(const Key('group-report')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        'fictional@planets.invalid',
      );
      await tester.tap(find.byKey(const Key('auth-request-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-code-field')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('auth-verify-button')));
      await tester.pumpAndSettle();
      expect(
        c.read(appRouterProvider).routerDelegate.state.uri.path,
        '/groups/$id/report',
      );
      expect(find.byKey(const Key('moderation-target-label')), findsOneWidget);
      await reveal(
        tester,
        find.textContaining('reviewed manually by PLANETS staff'),
      );
      expect(
        find.textContaining('reviewed manually by PLANETS staff'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('moderation-group-disclosure')),
        findsNothing,
      );
      expect(moderation.submitCount, 0);
      await tester.tap(find.byKey(const Key('moderation-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('moderation-explanation')),
        'A fictional report for manual staff review.',
      );
      await tester.ensureVisible(find.byKey(const Key('moderation-submit')));
      await tester.tap(find.byKey(const Key('moderation-submit')));
      await tester.pumpAndSettle();
      expect(moderation.target?.kind.wireValue, 'group');
      expect(moderation.target?.id, id);
      expect(moderation.target?.contextId, isNull);
      expect(find.byKey(const Key('moderation-received')), findsOneWidget);
    },
  );
  for (final locale in ['en', 'it']) {
    testWidgets(
      '320dp large text keyboard editor, policy failure and account clearing $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.localesTestValue = [Locale(locale)];
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        var writes = 0;
        final auth = FakeAuthGateway(
          snapshot: const AuthSnapshot(identity: AuthIdentity(id: actor)),
        );
        final policy = FakePolicyAcceptanceStore()
          ..readError = StateError('acknowledgement unavailable');
        final c = await pumpGroups(
          tester,
          auth: auth,
          path: '/groups/create',
          policy: policy,
          gateway: GroupGateway((name, args) async {
            if (name == 'create_group_draft' ||
                name == 'update_group' ||
                name == 'set_group_publication_state') {
              writes++;
            }
            if (name == 'list_public_groups') return [];
            throw StateError(name);
          }),
        );
        expect(
          c.read(appRouterProvider).routerDelegate.state.uri.path,
          '/groups/create',
        );
        await tester.enterText(
          find.byKey(const Key('group-name')),
          'Private input',
        );
        await tester.enterText(
          find.byKey(const Key('group-description')),
          'A fictional description for this group.',
        );
        await reveal(tester, find.byKey(const Key('group-save')));
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('group-save')))
              .onPressed,
          isNull,
        );
        expect(writes, 0);
        expect(tester.takeException(), isNull);
        c.read(authSessionProvider.notifier).markSignedOut();
        await tester.pumpAndSettle();
        expect(find.text('Private input'), findsNothing);
        expect(writes, 0);
      },
    );
  }
  testWidgets(
    'unsaved Close stays, discards, or saves only after confirmed backend response',
    (tester) async {
      var writes = 0;
      final c = await pumpGroups(
        tester,
        ready: true,
        path: '/groups/create',
        gateway: GroupGateway((name, args) async {
          if (name == 'recover_group_command') return [];
          if (name == 'create_group_draft') {
            writes++;
            return id;
          }
          if (name == 'get_own_group') return [row()];
          if (name == 'list_public_groups') return [];
          throw StateError(name);
        }),
      );
      expect(writes, 0);
      await tester.enterText(
        find.byKey(const Key('group-name')),
        'Fictional garden',
      );
      await tester.tap(find.byKey(const Key('page-close')));
      await tester.pumpAndSettle();
      expect(
        find.text('Save your group changes before leaving?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        c.read(appRouterProvider).routerDelegate.state.uri.path,
        '/groups/create',
      );
      await tester.tap(find.byKey(const Key('page-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save draft').last);
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(
        c.read(appRouterProvider).routerDelegate.state.uri.path,
        '/groups',
      );
    },
  );
  testWidgets('system Back and route changes share discard/stay protection', (
    tester,
  ) async {
    final c = await pumpGroups(
      tester,
      ready: true,
      path: '/groups/create',
      gateway: GroupGateway((name, args) async => []),
    );
    await tester.enterText(
      find.byKey(const Key('group-name')),
      'Unsaved fictional group',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text('Save your group changes before leaving?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    c.read(appRouterProvider).go('/groups');
    await tester.pumpAndSettle();
    expect(
      find.text('Save your group changes before leaving?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(c.read(appRouterProvider).routerDelegate.state.uri.path, '/groups');
  });
  testWidgets(
    'incomplete profile management cancellation returns to directory',
    (tester) async {
      final c = await pumpGroups(
        tester,
        ready: true,
        path: '/groups',
        gateway: GroupGateway((name, args) async => []),
      );
      c
          .read(authSessionProvider.notifier)
          .markProfileSetupRequired(
            const AuthIdentity(id: actor),
            hasProfileAnchor: true,
          );
      c.read(appRouterProvider).go('/groups/create');
      await tester.pumpAndSettle();
      expect(
        c.read(appRouterProvider).routerDelegate.state.uri.path,
        '/profile/edit',
      );
      expect(
        c
            .read(appRouterProvider)
            .routerDelegate
            .state
            .uri
            .queryParameters['returnTo'],
        '/groups/create',
      );
      await tester.tap(find.byKey(const Key('profile-cancel-button')));
      await tester.pumpAndSettle();
      expect(
        c.read(appRouterProvider).routerDelegate.state.uri.path,
        '/groups',
      );
    },
  );
  for (final locale in ['en', 'it']) {
    testWidgets(
      'public directory and profile fit 320dp at 2x text in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.localesTestValue = [Locale(locale)];
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        final c = await pumpGroups(
          tester,
          gateway: GroupGateway((name, args) async => [row()]),
        );
        await reveal(tester, find.byKey(const Key('group-card-$id')));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('group-card-$id')));
        await tester.pumpAndSettle();
        expect(
          c.read(appRouterProvider).routerDelegate.state.uri.path,
          '/groups/$id',
        );
        await reveal(tester, find.byKey(const Key('group-report')));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'policy review retains group input through cancellation, write failure and acceptance',
    (tester) async {
      final policy = FakePolicyAcceptanceStore()
        ..writeError = StateError('acknowledgement failed');
      var writes = 0;
      await pumpGroups(
        tester,
        ready: true,
        path: '/groups/create',
        policy: policy,
        gateway: GroupGateway((name, args) async {
          if (name == 'create_group_draft' ||
              name == 'update_group' ||
              name == 'set_group_publication_state') {
            writes++;
          }
          return [];
        }),
      );
      await tester.enterText(
        find.byKey(const Key('group-name')),
        'Retained group input',
      );
      await reveal(tester, find.text('Review Terms and Rules'));
      await tester.tap(find.text('Review Terms and Rules'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('policy-acceptance-checkbox')));
      await tester.tap(find.byKey(const Key('policy-acceptance-checkbox')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('policy-acceptance-continue')));
      await tester.tap(find.byKey(const Key('policy-acceptance-continue')));
      await tester.pumpAndSettle();
      expect(policy.writes, 1);
      expect(writes, 0);
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      expect(find.text('Retained group input'), findsOneWidget);
      policy.writeError = null;
      await reveal(tester, find.text('Review Terms and Rules'));
      await tester.tap(find.text('Review Terms and Rules'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('policy-acceptance-checkbox')));
      await tester.tap(find.byKey(const Key('policy-acceptance-checkbox')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('policy-acceptance-continue')));
      await tester.tap(find.byKey(const Key('policy-acceptance-continue')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('group-name')));
      expect(find.text('Retained group input'), findsOneWidget);
      await reveal(tester, find.byKey(const Key('group-save')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('group-save')))
            .onPressed,
        isNotNull,
      );
      expect(writes, 0);
    },
  );
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}
