import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/moderation/application/own_consequence_controller.dart';
import 'package:planets_mobile/features/moderation/data/own_consequence_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/own_consequence_models.dart';
import 'package:planets_mobile/features/moderation/presentation/own_consequences_screen.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/settings/data/language_preference_store.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_notifications.dart';
import '../../../support/fake_own_consequences.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_settings.dart';

void main() {
  final types = {
    'safety_notice': 'Safety notice',
    'interaction_restriction': 'Interaction restriction',
    'content_hide': 'Content hide',
    'account_suspension': 'Account suspension',
  };
  for (final entry in types.entries) {
    for (final active in [true, false]) {
      testWidgets(
        '${entry.key} ${active ? 'active' : 'removed'} has distinct history and verbatim reasons',
        (tester) async {
          final item = ownConsequence(
            1,
            type: entry.key,
            active: active,
            contentKind: entry.key == 'content_hide' ? 'one_time' : null,
          );
          await _body(
            tester,
            OwnConsequenceState(phase: OwnHistoryPhase.ready, items: [item]),
          );
          expect(find.text(entry.value), findsOneWidget);
          expect(find.text(active ? 'Active' : 'Removed'), findsOneWidget);
          await _scroll(
            tester,
            find.byKey(Key('notice-apply-reason-${item.id}')),
            150,
          );
          expect(find.text(item.applyReason), findsOneWidget);
          expect(find.byType(SelectableText), findsWidgets);
          if (!active) {
            await _scroll(
              tester,
              find.byKey(Key('notice-remove-reason-${item.id}')),
              150,
            );
            expect(find.text(item.revokeReason!), findsOneWidget);
            expect(find.textContaining('Removed on'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'loading, genuine empty, malformed failure and retry are separate',
    (tester) async {
      await _body(
        tester,
        const OwnConsequenceState(phase: OwnHistoryPhase.loading),
      );
      expect(find.text('Loading PLANETS notices…'), findsOneWidget);
      expect(find.byKey(const Key('notices-empty')), findsNothing);
      await _body(
        tester,
        const OwnConsequenceState(phase: OwnHistoryPhase.ready),
      );
      expect(find.byKey(const Key('notices-empty')), findsOneWidget);
      var retries = 0;
      await _body(
        tester,
        const OwnConsequenceState(
          phase: OwnHistoryPhase.failure,
          failure: OwnHistoryFailure.malformed,
        ),
        onRefresh: () async {
          retries++;
        },
      );
      expect(find.byKey(const Key('notices-empty')), findsNothing);
      expect(find.textContaining('does not mean'), findsOneWidget);
      await tester.tap(find.byKey(const Key('notices-retry')));
      expect(retries, 1);
    },
  );

  testWidgets(
    'page failure retains rows and offers page retry; refresh is separate',
    (tester) async {
      var more = 0;
      var refresh = 0;
      await _body(
        tester,
        OwnConsequenceState(
          phase: OwnHistoryPhase.ready,
          items: [ownConsequence(1)],
          hasMore: true,
          failure: OwnHistoryFailure.unavailable,
        ),
        onMore: () async {
          more++;
        },
        onRefresh: () async {
          refresh++;
        },
      );
      await _scroll(tester, find.byKey(const Key('notices-retry')), 250);
      expect(find.byKey(Key('notice-${ownConsequence(1).id}')), findsOneWidget);
      expect(find.textContaining('already loaded'), findsOneWidget);
      await tester.tap(find.byKey(const Key('notices-retry')));
      expect(more, 1);
      await tester.tap(find.byKey(const Key('notices-refresh')));
      expect(refresh, 1);
    },
  );

  testWidgets(
    'Italian long plain reasons, narrow layout and large text remain accessible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final row = ownConsequenceRow(
          1,
          type: 'interaction_restriction',
          active: false,
        );
        row['apply_reason'] = List.filled(
          25,
          '<b>Testo sintetico lungo e non tradotto</b> https://example.invalid',
        ).join(' ');
        final item = OwnConsequence.fromJson(row);
        await _body(
          tester,
          OwnConsequenceState(phase: OwnHistoryPhase.ready, items: [item]),
          locale: const Locale('it'),
          scale: 2,
        );
        expect(find.text('Avvisi di PLANETS'), findsOneWidget);
        await _scroll(
          tester,
          find.byKey(Key('notice-apply-reason-${item.id}')),
          250,
        );
        expect(find.text(item.applyReason), findsOneWidget);
        expect(
          tester
              .getSemantics(
                find.descendant(
                  of: find.byKey(Key('notice-apply-reason-${item.id}')),
                  matching: find.byType(EditableText),
                ),
              )
              .value,
          contains('Testo sintetico'),
        );
        await _scroll(
          tester,
          find.byKey(Key('notice-remove-reason-${item.id}')),
          250,
        );
        expect(find.text('Motivo della rimozione'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'pagination loading/end labels are explicit and not episode scores',
    (tester) async {
      await _body(
        tester,
        OwnConsequenceState(
          phase: OwnHistoryPhase.loadingMore,
          items: [ownConsequence(1)],
          hasMore: true,
        ),
      );
      await _scroll(tester, find.text('Loading older notices…'), 250);
      expect(find.text('Loading older notices…'), findsOneWidget);
      expect(find.byKey(const Key('notices-load-more')), findsNothing);
      await _body(
        tester,
        OwnConsequenceState(
          phase: OwnHistoryPhase.ready,
          items: [ownConsequence(1)],
        ),
      );
      await _scroll(tester, find.text('End of the available history'), 250);
      expect(find.text('End of the available history'), findsOneWidget);
      expect(find.textContaining('strike'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Settings entry opens own history and Back returns to Settings', (
    tester,
  ) async {
    final gateway = FakeOwnConsequenceGateway()
      ..page = OwnConsequencePage([ownConsequence(1)], hasMore: false);
    final (container, _) = await _app(tester, gateway);
    final router = container.read(appRouterProvider);
    router.go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-notices-row')));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.state.uri.path, '/settings/notices');
    expect(find.text('Safety notice'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(router.routerDelegate.state.uri.path, '/settings');
  });

  testWidgets(
    'signed-out direct route cannot bypass auth; account entry is absent',
    (tester) async {
      final gateway = FakeOwnConsequenceGateway();
      final (container, _) = await _app(tester, gateway, signedIn: false);
      final router = container.read(appRouterProvider);
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-notices-row')), findsNothing);
      router.go('/settings/notices');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/auth');
      expect(
        router.routerDelegate.state.uri.queryParameters['returnTo'],
        '/settings/notices',
      );
      expect(gateway.identities, isEmpty);
    },
  );

  testWidgets(
    'in-flight suspension routes to existing status screen and rejects late reasons',
    (tester) async {
      final pending = Completer<OwnConsequencePage>();
      final gateway = FakeOwnConsequenceGateway()..pending = pending.future;
      final (container, auth) = await _app(tester, gateway);
      final router = container.read(appRouterProvider);
      router.go('/settings/notices');
      await tester.pump();
      await tester.pump();
      auth.suspension = AccountSuspensionStatus.active(
        consequenceId: ownConsequence(9).id,
        appliedAt: DateTime.utc(2026, 10, 3),
        userReason: 'Synthetic dedicated suspension reason',
      );
      await container.read(authSessionProvider.notifier).refresh();
      pending.complete(OwnConsequencePage([ownConsequence(1)], hasMore: false));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/account/suspended');
      expect(find.byKey(const Key('account-status-check')), findsOneWidget);
      expect(find.byKey(const Key('account-status-sign-out')), findsOneWidget);
      expect(find.text(ownConsequence(1).applyReason), findsNothing);
      expect(find.byKey(const Key('settings-notices-row')), findsNothing);
      gateway.pending = null;
      gateway.page = OwnConsequencePage([
        ownConsequence(9, type: 'account_suspension', active: false),
      ], hasMore: false);
      auth.suspension = const AccountSuspensionStatus.inactive();
      await tester.tap(find.byKey(const Key('account-status-check')));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/settings/notices');
      expect(find.text('Account suspension'), findsOneWidget);
      expect(find.text('Removed'), findsOneWidget);
    },
  );

  testWidgets(
    'account switch clears visible reasons and fetches only new verified identity',
    (tester) async {
      final gateway = FakeOwnConsequenceGateway()
        ..page = OwnConsequencePage([ownConsequence(1)], hasMore: false);
      final (container, auth) = await _app(tester, gateway);
      container.read(appRouterProvider).go('/settings/notices');
      await tester.pumpAndSettle();
      expect(find.text(ownConsequence(1).applyReason), findsOneWidget);
      gateway.page = const OwnConsequencePage([], hasMore: false);
      auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'user-2')));
      await tester.pumpAndSettle();
      expect(find.text(ownConsequence(1).applyReason), findsNothing);
      expect(gateway.identities.last, 'user-2');
      expect(find.byKey(const Key('notices-empty')), findsOneWidget);
    },
  );

  testWidgets(
    'PT403 with inactive fresh status remains an explicit failure without a retry loop',
    (tester) async {
      final gateway = FakeOwnConsequenceGateway()
        ..error = const PostgrestException(
          message: 'Synthetic denial',
          code: 'PT403',
        );
      final (container, _) = await _app(tester, gateway);
      container.read(appRouterProvider).go('/settings/notices');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notices-error')), findsOneWidget);
      expect(find.byKey(const Key('notices-empty')), findsNothing);
      expect(gateway.identities, hasLength(1));
    },
  );
}

Future<void> _body(
  WidgetTester tester,
  OwnConsequenceState state, {
  Locale locale = const Locale('en'),
  double scale = 1,
  Future<void> Function()? onRefresh,
  Future<void> Function()? onMore,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: OwnConsequencesBody(
          state: state,
          onRefresh: onRefresh,
          onMore: onMore,
        ),
      ),
    ),
  );
  await tester
      .pump(); // Do not settle an intentionally pending progress indicator.
}

Future<(ProviderContainer, FakeAuthGateway)> _app(
  WidgetTester tester,
  FakeOwnConsequenceGateway gateway, {
  bool signedIn = true,
}) async {
  final auth = FakeAuthGateway(
    snapshot: signedIn
        ? const AuthSnapshot(identity: AuthIdentity(id: 'user-1'))
        : const AuthSnapshot(),
  );
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'synthetic-key',
          ),
        ),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = ProfileAnchorReadiness.complete,
        ),
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(data: profileFixture(complete: true)),
        ),
        notificationsGatewayProvider.overrideWithValue(
          FakeNotificationsGateway(),
        ),
        languagePreferenceStoreProvider.overrideWithValue(
          FakeLanguagePreferenceStore(),
        ),
        ownConsequenceGatewayProvider.overrideWithValue(gateway),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (
    ProviderScope.containerOf(tester.element(find.byType(PlanetsApp))),
    auth,
  );
}

Future<void> _scroll(WidgetTester tester, Finder target, double delta) =>
    tester.scrollUntilVisible(
      target,
      delta,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
