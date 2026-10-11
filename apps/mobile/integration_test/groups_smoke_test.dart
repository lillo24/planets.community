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
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/features/groups/domain/group_models.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/policies/application/policy_documents.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'real local groups: directory, lost creation reply, publication, profile and another person report',
    (tester) async {
      final config = AppConfig.fromCompileTime();
      if (config.environment != AppEnvironment.local ||
          ![
            '127.0.0.1',
            'localhost',
            '::1',
          ].contains(config.supabaseUrl.host)) {
        throw StateError('Explicit loopback backend and adb reverse required.');
      }
      const actor = String.fromEnvironment('GRP02_MANAGER_ID'),
          managerToken = String.fromEnvironment('GRP02_MANAGER_TOKEN');
      const reporter = String.fromEnvironment('GRP02_REPORTER_ID'),
          reporterToken = String.fromEnvironment('GRP02_REPORTER_TOKEN');
      const publicId = String.fromEnvironment('GRP02_PUBLIC_GROUP_ID');
      if ([
        actor,
        managerToken,
        reporter,
        reporterToken,
        publicId,
      ].any((v) => v.isEmpty)) {
        throw StateError('Prepare groups smoke defines first.');
      }
      var token = managerToken, creates = 0;
      final client = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () async => token,
      );
      addTearDown(client.dispose);
      final gateway = GroupGateway((name, params) async {
        final result = await client.rpc(name, params: params);
        if (name == 'create_group_draft' && ++creates == 1) {
          throw const SocketException(
            'Synthetic reply loss after database acceptance.',
          );
        }
        return result;
      });
      final before = await gateway.ownPage(actor, null);
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          supabaseClientProvider.overrideWithValue(client),
          authGatewayProvider.overrideWithValue(_LocalIdentity(actor)),
          groupGatewayProvider.overrideWithValue(gateway),
          policyAcceptanceStoreProvider.overrideWithValue(
            _TokenBoundPolicyStore(client),
          ),
          initialLanguagePreferenceProvider.overrideWithValue(
            LanguagePreference.english,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authSessionProvider.notifier).start();
      expect(container.read(authSessionProvider).phase, AuthSessionPhase.ready);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PlanetsApp(),
        ),
      );
      final router = container.read(appRouterProvider);
      router.go('/groups');
      await waitFor(tester, find.byKey(const Key('groups-search')));
      await tester.enterText(
        find.byKey(const Key('groups-search')),
        'GRP02 fictional',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pump(const Duration(milliseconds: 500));
      await reveal(tester, find.byKey(const Key('group-card-$publicId')));
      await waitFor(tester, find.text('GRP02 fictional Riverside collective'));
      await binding.convertFlutterSurfaceToImage();
      await tester.pump(const Duration(milliseconds: 300));
      await binding
          .takeScreenshot('grp02-directory-en')
          .timeout(const Duration(seconds: 20));
      await reveal(tester, find.byKey(const Key('groups-create')));
      await tester.tap(find.byKey(const Key('groups-create')));
      await waitFor(tester, find.byKey(const Key('group-name')));
      expect(creates, 0);
      await tester.enterText(
        find.byKey(const Key('group-name')),
        'GRP02 fictional Green neighbours',
      );
      await tester.enterText(
        find.byKey(const Key('group-description')),
        'Fictional people sharing gardening skills and caring for their neighbourhood together.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pump(const Duration(milliseconds: 500));
      await reveal(tester, find.byKey(const Key('group-locality')));
      await tester.enterText(find.byKey(const Key('group-locality')), 'Trento');
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await waitUntil(
        tester,
        () => container
            .read(policyAcceptanceProvider)
            .allows(actor, policyBundleVersion),
      );
      await reveal(tester, find.byKey(const Key('group-save')));
      await tester.tap(find.byKey(const Key('group-save')));
      await waitUntil(tester, () => creates == 1);
      await reveal(tester, find.text('Retry same command'));
      await waitFor(tester, find.text('Retry same command'));
      await tester.tap(find.text('Retry same command'));
      await waitFor(tester, find.text('Draft'));
      await reveal(tester, find.byKey(const Key('group-publish')));
      await waitFor(tester, find.byKey(const Key('group-publish')));
      expect(creates, 1);
      final after = await gateway.ownPage(actor, null);
      expect(after.length, before.length + 1);
      final created = after.singleWhere(
        (g) => !before.any((existing) => existing.id == g.id),
      );
      expect(created.publication, GroupPublication.draft);
      await tester.tap(find.byKey(const Key('group-publish')));
      await waitFor(tester, find.text('Unpublish'));
      expect(
        (await gateway.ownDetail(actor, created.id)).publication,
        GroupPublication.published,
      );
      final public = await gateway.publicDetail(created.id);
      expect(public?.content.locality, 'Trento');
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pump(const Duration(milliseconds: 300));
      await binding.takeScreenshot('grp02-editor-en');
      await reveal(tester, find.byKey(const Key('group-public-profile')));
      await tester.tap(find.byKey(const Key('group-public-profile')));
      await waitFor(tester, find.byKey(const Key('group-report')));
      await binding.takeScreenshot('grp02-profile-en');
      token = reporterToken;
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: reporter));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('group-report')));
      await waitFor(tester, find.byKey(const Key('moderation-category')));
      expect(
        find.textContaining('reviewed manually by PLANETS staff'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('moderation-category')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Other').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.byKey(const Key('moderation-explanation')),
        'Fictional report submitted for manual local staff review.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await reveal(tester, find.byKey(const Key('moderation-submit')));
      await tester.tap(find.byKey(const Key('moderation-submit')));
      await waitFor(tester, find.byKey(const Key('moderation-received')));
      final reports = await client.rpc(
        'list_own_moderation_reports',
        params: {'p_expected_reporter_profile_id': reporter},
      );
      expect((reports as List).any((r) => r['target_kind'] == 'group'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

// Fixtures use real verified OTP JWTs without a persistent GoTrue session.
// Read the actual server acknowledgement through that same token-bound client.
class _TokenBoundPolicyStore implements PolicyAcceptanceStore {
  const _TokenBoundPolicyStore(this.client);
  final SupabaseClient client;
  Future<DateTime?> call(
    String operation,
    String account,
    String version,
  ) async {
    final rows = await client.rpc(
      operation,
      params: {'p_expected_account_id': account, 'p_bundle_version': version},
    );
    if (rows is! List || rows.length > 1) {
      throw const FormatException('Invalid fixture policy response.');
    }
    if (rows.isEmpty) return null;
    final row = rows.single;
    if (row is! Map ||
        row['account_id'] != account ||
        row['bundle_version'] != version ||
        row['accepted_at'] is! String) {
      throw const FormatException('Mismatched fixture policy response.');
    }
    final accepted = DateTime.tryParse(row['accepted_at'] as String);
    if (accepted == null || !accepted.isUtc) {
      throw const FormatException('Invalid fixture acknowledgement timestamp.');
    }
    return accepted;
  }

  @override
  Future<DateTime?> read(String account, String version) =>
      call('get_policy_acceptance', account, version);
  @override
  Future<DateTime> write(String account, String version) async {
    final accepted = await call('accept_policy_bundle', account, version);
    if (accepted == null) throw StateError('Acknowledgement not confirmed.');
    return accepted;
  }
}

Future<void> waitUntil(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), isTrue);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> waitFor(WidgetTester tester, Finder finder) =>
    waitUntil(tester, () => finder.evaluate().isNotEmpty);
Future<void> reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  // A long directory can dispose the header above the viewport. Start from a
  // known edge before scrolling toward either an earlier or later lazy child.
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.scrollUntilVisible(finder, 250, scrollable: scrollable);
  await tester.pump(const Duration(milliseconds: 300));
}

class _LocalIdentity implements AuthGateway {
  const _LocalIdentity(this.id);
  final String id;
  @override
  AuthSnapshot get currentSnapshot =>
      AuthSnapshot(identity: AuthIdentity(id: id));
  @override
  Stream<AuthSnapshot> get authStateChanges => const Stream.empty();
  @override
  Future<void> requestEmailOtp(String email) =>
      throw UnsupportedError('Use prepared local OTP fixture.');
  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) => throw UnsupportedError('Use prepared local OTP fixture.');
  @override
  Future<void> signOut() async {}
}
