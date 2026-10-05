import 'dart:async';
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
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/data/similar_proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/domain/similar_proposal.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'template_workshop_smoke_test.dart' as smoke;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real SIM02: modal/save/return, photo gate, stale Full/cancelled, response-loss retry',
    (tester) async {
      final config = AppConfig.fromCompileTime();
      if (config.environment != AppEnvironment.local ||
          ![
            '127.0.0.1',
            'localhost',
            '::1',
          ].contains(config.supabaseUrl.host)) {
        throw StateError(
          'SIM02 smoke requires an explicitly local loopback backend.',
        );
      }
      const actor = String.fromEnvironment('SIM02_ACTOR_ID');
      const token = String.fromEnvironment('SIM02_ACCESS_TOKEN');
      const creatorId = String.fromEnvironment('SIM02_CREATOR_ID');
      const creatorToken = String.fromEnvironment('SIM02_CREATOR_TOKEN');
      const candidate = String.fromEnvironment('SIM02_CANDIDATE_ID');
      if ([
        actor,
        token,
        creatorId,
        creatorToken,
        candidate,
      ].any((v) => v.isEmpty)) {
        throw StateError('Prepare disposable SIM02 smoke defines first.');
      }
      final client = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () async => token,
      );
      final creator = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () async => creatorToken,
      );
      final gateway = _ResponseLossGateway(client);
      final matching = _ObservedMatching(
        SupabaseSimilarProposalGateway(client),
      );
      final c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          supabaseClientProvider.overrideWithValue(client),
          authGatewayProvider.overrideWithValue(_SmokeIdentity(actor)),
          proposalGatewayProvider.overrideWithValue(gateway),
          similarProposalGatewayProvider.overrideWithValue(matching),
          initialLanguagePreferenceProvider.overrideWithValue(
            LanguagePreference.english,
          ),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(client.dispose);
      addTearDown(creator.dispose);
      await c.read(authSessionProvider.notifier).start();
      expect(c.read(authSessionProvider).phase, AuthSessionPhase.ready);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const PlanetsApp()),
      );
      final router = c.read(appRouterProvider);
      router.go('/proposals/create');
      await smoke.waitFor(tester, find.byKey(const Key('proposal-title')));
      await tester.enterText(find.byKey(const Key('proposal-title')), 'repair');
      await _open(tester);
      expect(find.text('SIM02 synthetic repair laboratory'), findsOneWidget);
      await tester.tap(find.byKey(const Key('similar-sheet-close')));
      await smoke.waitFor(tester, find.byKey(const Key('similar-view')));
      expect(await gateway.listOwnProposals(actor), isEmpty);
      expect(find.text('Draft saved'), findsNothing);
      await _open(tester);
      await _choose(tester, candidate);
      await smoke.waitFor(tester, find.text('Draft saved'));
      final first = (await gateway.listOwnProposals(actor)).single;
      expect(first.title, 'repair');
      // Ordinary detail remains the authority; a ready matching user without a
      // photo can inspect Projects, but normal request-to-join requires the photo.
      await _reveal(
        tester,
        find.byKey(const Key('participation-join-$candidate')),
      );
      await tester.tap(find.byKey(const Key('participation-join-$candidate')));
      final send = find.byKey(const Key('participation-send-request'));
      await smoke.waitUntil(
        tester,
        () =>
            send.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(send).onPressed != null,
        label: 'ordinary join options loaded',
      );
      await Scrollable.ensureVisible(tester.element(send), alignment: .5);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(send);
      await smoke.waitFor(
        tester,
        find.text('Add a profile photo before requesting to join.'),
      );
      await tester.tap(find.byKey(const Key('profile-photo-trust-go-back')));
      await tester.pump(const Duration(milliseconds: 400));
      router.pop();
      await tester.pump(const Duration(milliseconds: 400));
      router.pop();
      await smoke.waitFor(tester, find.byKey(const Key('similar-view')));
      await _reveal(tester, find.byKey(const Key('proposal-title')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('proposal-title')))
            .controller!
            .text,
        'repair',
      );
      expect(matching.exclusions.last, first.id);
      final beforeTab = matching.exclusions.length;
      await tester.tap(find.byKey(const Key('nav-home')));
      await smoke.waitUntil(
        tester,
        () =>
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex ==
            1,
        label: 'Home tab active',
      );
      await tester.pump(const Duration(seconds: 1));
      expect(matching.exclusions, hasLength(beforeTab));
      await tester.tap(find.byKey(const Key('nav-browse')));
      await smoke.waitFor(tester, find.byKey(const Key('similar-view')));
      expect(matching.exclusions, hasLength(beforeTab + 1));
      expect(matching.exclusions.last, first.id);
      final lookupCount = matching.exclusions.length;
      await _open(tester);
      final owner = SupabaseProposalGateway(creator);
      final own = (await owner.getOwnProposal(creatorId, candidate))!;
      await owner.updateOwnProposal(
        creatorId,
        candidate,
        _input(own, countOrganizers: true),
      );
      await _choose(tester, candidate);
      await smoke.waitUntil(
        tester,
        () =>
            c.read(proposalDetailProvider).detail?.summary.capacity.isFull ==
            true,
        label: 'fresh Full detail after settled available preview',
      );
      await _reveal(tester, find.text('No spots available.').last);
      expect(
        find.byKey(const Key('participation-join-$candidate')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(matching.exclusions, hasLength(lookupCount));
      router.pop();
      await _open(tester);
      expect(find.text('Full'), findsOneWidget);
      // Cancellation after lookup cannot grant participation through the preview.
      await owner.cancelProposal(creatorId, candidate);
      await _choose(tester, candidate);
      await smoke.waitFor(
        tester,
        find.text(
          "We couldn't complete that proposal request. Check your connection and try again.",
        ),
      );
      expect(c.read(proposalDetailProvider).detail, isNull);
      expect(
        find.byKey(const Key('participation-join-$candidate')),
        findsNothing,
      );
      router.pop();
      await smoke.waitFor(tester, find.byKey(const Key('proposal-title')));
      // Use a second independent create editor and another published Project for
      // exact create-request recovery after a truly committed, dropped response.
      final replacement = await owner.createDraft(
        creatorId,
        _input(own, countOrganizers: false),
      );
      await owner.publishProposal(creatorId, replacement);
      final priorTitle = tester
          .widget<TextFormField>(find.byKey(const Key('proposal-title')))
          .controller;
      unawaited(router.push('/proposals/create'));
      await smoke.waitUntil(tester, () {
        final fields = find.byKey(const Key('proposal-title'));
        return fields.evaluate().length == 1 &&
            !identical(
              tester.widget<TextFormField>(fields).controller,
              priorTitle,
            );
      }, label: 'second create editor mounted after guarded push');
      gateway.dropNextCreate = true;
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'repair second idea',
      );
      await _open(tester);
      await _choose(tester, replacement);
      await smoke.waitFor(tester, find.text('Keep your draft'));
      await tester.tap(find.text('Keep editing'));
      await smoke.waitFor(tester, find.byKey(const Key('similar-view')));
      expect(await gateway.listOwnProposals(actor), hasLength(2));
      await _open(tester);
      await _choose(tester, replacement);
      await smoke.waitFor(tester, find.text('Draft saved'));
      expect(await gateway.listOwnProposals(actor), hasLength(2));
      expect(gateway.creationRequests, hasLength(3));
      expect(gateway.creationRequests[1], isNotNull);
      expect(gateway.creationRequests[2], gateway.creationRequests[1]);
      expect(gateway.creationRequests.toSet(), hasLength(2));
      router.pop();
      await smoke.waitFor(tester, find.byKey(const Key('proposal-title')));
      await _reveal(tester, find.byKey(const Key('proposal-title')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('proposal-title')))
            .controller!
            .text,
        'repair second idea',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _open(WidgetTester tester) async {
  await smoke.waitFor(tester, find.byKey(const Key('similar-view')));
  await _reveal(tester, find.byKey(const Key('similar-view')));
  await tester.tap(find.byKey(const Key('similar-view')));
  await smoke.waitFor(tester, find.byKey(const Key('similar-sheet')));
}

Future<void> _choose(WidgetTester tester, String candidate) async {
  final action = find.byKey(Key('similar-open-$candidate'));
  await _reveal(tester, action);
  await tester.tap(action);
  await smoke.waitUntil(
    tester,
    () => find.byKey(const Key('similar-sheet')).evaluate().isEmpty,
    label: 'sheet fully dismisses',
  );
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final list = find.byType(ListView).last;
  final scrollable = find
      .descendant(of: list, matching: find.byType(Scrollable))
      .first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 100));
  await smoke.waitFor(tester, scrollable);
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: scrollable,
    maxScrolls: 50,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pump(const Duration(milliseconds: 400));
}

ProposalInput _input(OwnProposal p, {required bool countOrganizers}) =>
    ProposalInput(
      title: p.title!,
      summary: p.summary!,
      description: p.description!,
      startsAt: p.startsAt,
      endsAt: p.endsAt,
      eventTimezone: p.eventTimezone!,
      countryCode: p.countryCode!,
      locality: p.locality!,
      administrativeArea: p.administrativeArea ?? '',
      publicLocationLabel: p.publicLocationLabel!,
      exactMeetingText: p.exactMeetingText!,
      exactLocationVisibility: p.exactLocationVisibility,
      skillImportanceById: {
        for (final skill in p.skills) skill.id: skill.importance,
      },
      registrationCapacity: 1,
      countOrganizersTowardCapacity: countOrganizers,
    );

class _ObservedMatching implements SimilarProposalGateway {
  _ObservedMatching(this.inner);
  final SimilarProposalGateway inner;
  final exclusions = <String?>[];
  @override
  Future<List<SimilarProposal>> lookup(SimilarProposalQuery query) {
    exclusions.add(query.excludedProposalId);
    return inner.lookup(query);
  }
}

class _ResponseLossGateway extends SupabaseProposalGateway {
  _ResponseLossGateway(super.client);
  bool dropNextCreate = false;
  final creationRequests = <String?>[];
  @override
  Future<String> createDraft(
    String actor,
    ProposalInput input, {
    String? clientRequestId,
  }) async {
    creationRequests.add(clientRequestId);
    final id = await super.createDraft(
      actor,
      input,
      clientRequestId: clientRequestId,
    );
    if (dropNextCreate) {
      dropNextCreate = false;
      throw const SocketException(
        'Synthetic local response loss after committed create.',
      );
    }
    return id;
  }
}

class _SmokeIdentity implements AuthGateway {
  const _SmokeIdentity(this.actor);
  final String actor;
  @override
  AuthSnapshot get currentSnapshot =>
      AuthSnapshot(identity: AuthIdentity(id: actor));
  @override
  Stream<AuthSnapshot> get authStateChanges => const Stream.empty();
  @override
  Future<void> requestEmailOtp(String email) =>
      throw UnsupportedError('Prepared local identity only.');
  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) => throw UnsupportedError('Prepared local identity only.');
  @override
  Future<void> signOut() async {}
}
