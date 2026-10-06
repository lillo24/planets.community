import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:planets_mobile/features/moderation/application/moderation_controllers.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_models.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/features/template_workshop/application/template_controllers.dart';
import 'package:planets_mobile/features/template_workshop/data/template_gateway.dart';
import 'package:planets_mobile/features/template_workshop/domain/template_models.dart';
import 'package:planets_mobile/features/template_workshop/presentation/template_workshop_screens.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Opt-in native smoke only. No live credentials, service role, production data
// or persistent session stores. Defines come from the isolated fixture helper.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real TW05 world: preserve form, copy recovery, suggestions, failed save, Full, report/removal',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final config = AppConfig.fromCompileTime();
      if (config.environment != AppEnvironment.local ||
          ![
            '127.0.0.1',
            'localhost',
            '::1',
          ].contains(config.supabaseUrl.host)) {
        throw StateError(
          'Workshop smoke requires an explicitly local loopback backend (adb reverse for Android).',
        );
      }
      const actor = String.fromEnvironment('TW05_ACTOR_ID');
      const token = String.fromEnvironment('TW05_ACCESS_TOKEN');
      const templateId = String.fromEnvironment('TW05_TEMPLATE_ID');
      const staffId = String.fromEnvironment('TW05_REVIEWER_ID');
      const staffToken = String.fromEnvironment('TW05_REVIEWER_TOKEN');
      if ([
        actor,
        token,
        templateId,
        staffId,
        staffToken,
      ].any((value) => value.isEmpty)) {
        throw StateError('Prepare disposable Workshop smoke defines first.');
      }
      final client = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () async => token,
      );
      final staff = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () async => staffToken,
      );
      final gateway = _LostResponseGateway(SupabaseTemplateGateway(client));
      final proposalGateway = _FailOnceUpdateGateway(client);
      const fullId = String.fromEnvironment('TW05_FULL_ID');
      final c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          supabaseClientProvider.overrideWithValue(client),
          authGatewayProvider.overrideWithValue(_SmokeIdentity(actor)),
          templateGatewayProvider.overrideWithValue(gateway),
          proposalGatewayProvider.overrideWithValue(proposalGateway),
          initialLanguagePreferenceProvider.overrideWithValue(
            LanguagePreference.english,
          ),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(client.dispose);
      addTearDown(staff.dispose);
      // Validate the token actually represents this synthetic local identity.
      final identity = await client
          .from('profiles')
          .select('id, display_name')
          .eq('id', actor)
          .single();
      expect(identity, isNotEmpty);
      await c.read(authSessionProvider.notifier).start();
      expect(c.read(authSessionProvider).phase, AuthSessionPhase.ready);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const PlanetsApp()),
      );
      final router = c.read(appRouterProvider);
      router.go('/proposals/create');
      await waitFor(tester, find.byKey(const Key('proposal-title')));
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'TW05 prior sparse draft',
      );
      await tester.tap(find.byKey(const Key('proposal-editor-workshop')));
      await waitFor(tester, find.byKey(const Key('template-query')));
      await waitUntil(
        tester,
        () => c.read(templateCatalogProvider).items.length >= 9,
        label: 'core completed inventory loaded',
      );
      expect(
        c
            .read(templateCatalogProvider)
            .items
            .any((t) => t.title == 'Concerto acustico nel cortile'),
        isFalse,
      );
      if (const bool.fromEnvironment('TW05_CAPTURE_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump(const Duration(milliseconds: 500));
        final en = await binding.takeScreenshot('tw05-workshop-en-large-text');
        await File('${Directory.systemTemp.path}/tw05-workshop-en.png')
            .writeAsBytes(en);
        expect(
          await c
              .read(languagePreferenceProvider.notifier)
              .select(LanguagePreference.italian),
          isTrue,
        );
        await tester.pump(const Duration(milliseconds: 500));
        final it = await binding.takeScreenshot('tw05-workshop-it-large-text');
        await File('${Directory.systemTemp.path}/tw05-workshop-it.png')
            .writeAsBytes(it);
        expect(
          await c
              .read(languagePreferenceProvider.notifier)
              .select(LanguagePreference.english),
          isTrue,
        );
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.enterText(
        find.byKey(const Key('template-query')),
        'Repair Café: prova locale del cambio di versione',
      );
      final card = find.byKey(Key('template-card-$templateId'));
      await waitFor(tester, card);
      await reveal(tester, card);
      await tester.tap(card);
      await waitUntil(
        tester,
        () => c.read(templateDetailProvider(templateId)).blueprints.length == 2,
        label: 'two real demo blueprint needs',
      );
      expect(
        c.read(templateDetailProvider(templateId)).blueprints,
        hasLength(2),
      );
      final preview = c.read(templateDetailProvider(templateId)).detail!;
      expect(preview.durationSeconds, 10800);
      await reveal(tester, find.byKey(const Key('template-report')));
      await tester.tap(find.byKey(const Key('template-report')));
      await waitFor(tester, find.byKey(const Key('moderation-category')));
      tester
          .widget<DropdownButtonFormField<ModerationCategory>>(
            find.byKey(const Key('moderation-category')),
          )
          .onChanged!(ModerationCategory.other);
      await tester.enterText(
        find.byKey(const Key('moderation-explanation')),
        'TW05 synthetic original-Creator report for manual review.',
      );
      await reveal(tester, find.byKey(const Key('moderation-submit')));
      await tester.tap(find.byKey(const Key('moderation-submit')));
      await waitUntil(
        tester,
        () => c.read(moderationSubmissionProvider).receipt != null,
      );
      final report = c.read(moderationSubmissionProvider).receipt!;
      router.pop();
      await waitUntil(
        tester,
        () => c.read(templateDetailProvider(templateId)).canUse,
        label: 'report return revalidation',
      );
      await reveal(tester, find.byKey(const Key('template-use')));
      await tester.tap(find.byKey(const Key('template-use')));
      await waitUntil(
        tester,
        () => c.read(templateApplicationsProvider).failures.isNotEmpty,
      );
      // First RPC truly committed; deliberately drop only its response. Getter
      // recovery must bind that destination instead of creating another copy.
      await reveal(tester, find.byKey(const Key('template-retry-open')));
      await tester.tap(find.byKey(const Key('template-retry-open')));
      await waitFor(tester, find.byType(ProposalEditorScreen));
      await waitFor(tester, find.byKey(const Key('proposal-title')));
      final accepted = c
          .read(templateApplicationsProvider)
          .attempts
          .values
          .single;
      expect(accepted.destinationId, isNotNull);
      expect(gateway.applyCalls, 1);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Repair Café: aggiustiamo piccoli oggetti insieme',
      );
      if (const bool.fromEnvironment('TW05_CAPTURE_SCREENSHOTS')) {
        await tester.pump(const Duration(milliseconds: 500));
        final edit = await binding.takeScreenshot('tw05-editor-large-text');
        await File('${Directory.systemTemp.path}/tw05-editor.png')
            .writeAsBytes(edit);
      }
      await _openSuggestions(tester);
      await _revealLast(tester, find.byKey(Key('similar-open-$fullId')));
      expect(find.text('Full'), findsWidgets);
      if (const bool.fromEnvironment('TW05_CAPTURE_SCREENSHOTS')) {
        final sheet = await binding.takeScreenshot(
          'tw05-full-sheet-large-text',
        );
        await File('${Directory.systemTemp.path}/tw05-full-sheet.png')
            .writeAsBytes(sheet);
      }
      await tester.tap(find.byKey(const Key('similar-sheet-close')));
      await waitFor(tester, find.byKey(const Key('similar-view')));
      expect(
        (await proposalGateway.getOwnProposal(
          actor,
          accepted.destinationId!,
        ))!.title,
        preview.title,
      );
      proposalGateway.failNextUpdate = true;
      await _openSuggestions(tester);
      await _choose(tester, fullId);
      await waitFor(tester, find.text('Keep your draft'));
      await tester.tap(find.text('Keep editing'));
      await waitFor(tester, find.byKey(const Key('similar-view')));
      expect(proposalGateway.failNextUpdate, isFalse);
      expect(
        (await proposalGateway.getOwnProposal(
          actor,
          accepted.destinationId!,
        ))!.title,
        preview.title,
      );
      await _openSuggestions(tester);
      await _choose(tester, fullId);
      await waitFor(tester, find.text('Draft saved'));
      await waitUntil(
        tester,
        () =>
            c.read(proposalDetailProvider).detail?.summary.capacity.isFull ==
            true,
        label: 'ordinary detail reads canonical Full',
      );
      expect(
        (await proposalGateway.getOwnProposal(
          actor,
          accepted.destinationId!,
        ))!.title,
        'Repair Café: aggiustiamo piccoli oggetti insieme',
      );
      expect(find.byKey(Key('participation-join-$fullId')), findsNothing);
      router.pop();
      await waitFor(tester, find.byKey(const Key('proposal-title')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('proposal-title')))
            .controller!
            .text,
        'Repair Café: aggiustiamo piccoli oggetti insieme',
      );
      await staff.rpc(
        'remove_moderation_case_template',
        params: {
          'p_expected_staff_profile_id': staffId,
          'p_case_id': report.caseId,
          'p_template_id': templateId,
          'p_client_request_id': 'd0550000-0000-4000-8000-000000000001',
          'p_reviewed_content_version': preview.token,
          'p_reason': 'TW05 synthetic local reviewed removal.',
        },
      );
      router.pop();
      await waitFor(tester, find.byKey(const Key('template-unavailable')));
      expect(find.byKey(const Key('template-use')), findsNothing);
      expect(find.byKey(const Key('template-report')), findsNothing);
      await reveal(tester, find.byKey(const Key('template-retry-open')));
      await tester.tap(find.byKey(const Key('template-retry-open')));
      await waitFor(tester, find.byKey(const Key('proposal-title')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('proposal-title')))
            .controller!
            .text,
        'Repair Café: aggiustiamo piccoli oggetti insieme',
      );
      expect(gateway.applyCalls, 1);
      router.pop();
      await waitFor(tester, find.byKey(const Key('template-unavailable')));
      router.pop();
      await waitFor(tester, find.byType(TemplateWorkshopScreen));
      router.pop();
      await waitFor(tester, find.byKey(const Key('proposal-title')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('proposal-title')))
            .controller!
            .text,
        'TW05 prior sparse draft',
      );
      // Close any local realtime subscriptions before disposing the app.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> waitUntil(
  WidgetTester tester,
  bool Function() ready, {
  String? label,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), isTrue, reason: label);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> waitFor(WidgetTester tester, Finder finder) => waitUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  label: finder.toString(),
);
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump(const Duration(milliseconds: 300));
}

class _SmokeIdentity implements AuthGateway {
  const _SmokeIdentity(this.actor);
  final String actor;
  // The prepared identity does not bypass canonical account-access checks.
  @override
  Future<AccountSuspensionStatus> suspensionStatusFor(
    String expectedProfileId,
  ) =>
      SupabaseAuthGateway(Supabase.instance.client)
          .suspensionStatusFor(expectedProfileId);
  @override
  AuthSnapshot get currentSnapshot =>
      AuthSnapshot(identity: AuthIdentity(id: actor));
  @override
  Stream<AuthSnapshot> get authStateChanges => const Stream.empty();
  @override
  Future<void> requestEmailOtp(String email) =>
      throw UnsupportedError('Prepared verified local session only.');
  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) => throw UnsupportedError('Prepared verified local session only.');
  @override
  Future<void> signOut() async {}
}

class _LostResponseGateway implements TemplateGateway {
  _LostResponseGateway(this.inner);
  final TemplateGateway inner;
  int applyCalls = 0;
  @override
  Future<List<TemplateCard>> list({
    TemplateCursor? cursor,
    String? query,
    Set<String>? skills,
  }) => inner.list(cursor: cursor, query: query, skills: skills);
  @override
  Future<TemplateDetail?> detail(String id) => inner.detail(id);
  @override
  Future<List<TemplateBlueprint>> blueprints(
    String id,
    String token, {
    String? cursor,
  }) => inner.blueprints(id, token, cursor: cursor);
  @override
  Future<TemplateReceipt?> recover(TemplateAttempt a) => inner.recover(a);
  @override
  Future<TemplateReceipt> apply(TemplateAttempt a) async {
    applyCalls++;
    final receipt = await inner.apply(a);
    if (applyCalls == 1) {
      throw const SocketException(
        'Synthetic local response loss after acceptance.',
      );
    }
    return receipt;
  }
}

Future<void> _openSuggestions(WidgetTester tester) async {
  await waitFor(tester, find.byKey(const Key('similar-view')));
  await _revealLast(tester, find.byKey(const Key('similar-view')));
  await tester.tap(find.byKey(const Key('similar-view')));
  await waitFor(tester, find.byKey(const Key('similar-sheet')));
}

Future<void> _choose(WidgetTester tester, String id) async {
  final action = find.byKey(Key('similar-open-$id'));
  await _revealLast(tester, action);
  await tester.tap(action);
  await waitUntil(
    tester,
    () => find.byKey(const Key('similar-sheet')).evaluate().isEmpty,
  );
}

Future<void> _revealLast(WidgetTester tester, Finder finder) async {
  final list = find.byType(ListView).last;
  final scroll = find
      .descendant(of: list, matching: find.byType(Scrollable))
      .first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: scroll,
    maxScrolls: 50,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pump(const Duration(milliseconds: 400));
}

class _FailOnceUpdateGateway extends SupabaseProposalGateway {
  _FailOnceUpdateGateway(super.client);
  bool failNextUpdate = false;
  @override
  Future<void> updateOwnProposal(
    String actor,
    String id,
    ProposalInput input,
  ) async {
    if (failNextUpdate) {
      failNextUpdate = false;
      throw const SocketException('Controlled TW05 pre-commit save failure.');
    }
    await super.updateOwnProposal(actor, id, input);
  }
}
