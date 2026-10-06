import 'dart:convert';
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
import 'package:planets_mobile/features/auth/application/auth_command_controller.dart';
import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/project_chat/presentation/project_chat_screen.dart';
import 'package:planets_mobile/features/project_participant_invites/application/participant_admission_controller.dart';
import 'package:planets_mobile/features/project_participant_invites/domain/participant_invitation_models.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'template_workshop_smoke_test.dart' show waitFor, waitUntil;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'integrated native OTP, duplicate continuation, photo-free admission and guarded departure',
    (tester) async {
      final config = AppConfig.fromCompileTime();
      const proposal = String.fromEnvironment('STACK_PROPOSAL_TOKEN');
      const tavolo = String.fromEnvironment('STACK_TAVOLO_TOKEN');
      const full = String.fromEnvironment('STACK_FULL_TOKEN');
      const owner = String.fromEnvironment('STACK_OWNER_ID');
      const mailpit = String.fromEnvironment('STACK_MAILPIT_URL');
      if (config.environment != AppEnvironment.local ||
          config.supabaseUrl.toString() != 'http://127.0.0.1:54921' ||
          mailpit != 'http://127.0.0.1:54924' ||
          [proposal, tavolo, full, owner].any((v) => v.isEmpty)) {
        throw StateError(
          'Prepare the owned TW-STACK01 loopback fixture first.',
        );
      }
      // Normal native Auth initialization also initializes its session storage.
      // A bare stateless data client is insufficient for a real OTP journey.
      await initializeSupabase(config);
      final client = Supabase.instance.client;
      await client.auth.signOut(scope: SignOutScope.local);
      final drafts = _FailOnceUpdate(client);
      final c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          supabaseClientProvider.overrideWithValue(client),
          proposalGatewayProvider.overrideWithValue(drafts),
          initialLanguagePreferenceProvider.overrideWithValue(
            LanguagePreference.english,
          ),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(Supabase.instance.dispose);
      await c.read(authSessionProvider.notifier).start();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const PlanetsApp()),
      );
      final router = c.read(appRouterProvider);
      String link(String token) =>
          'https://planets.community/join/project/$token';
      Future<void> deliver(String uri) async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/navigation',
          const JSONMethodCodec().encodeMethodCall(
            MethodCall('pushRouteInformation', {'location': uri}),
          ),
          (_) {},
        );
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> tap(String key) async {
        final finder = find.byKey(Key(key));
        await waitFor(tester, finder);
        await tester.ensureVisible(finder);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(finder);
      }

      await deliver(link(proposal));
      await tap('participant-invite-sign-in');
      await waitFor(tester, find.byKey(const Key('auth-email-field')));
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        'tw-stack01-native@planets.invalid',
      );
      await tap('auth-request-button');
      await waitUntil(tester, () => !c.read(authCommandProvider).isBusy);
      expect(
        c.read(authCommandProvider).failure,
        isNull,
        reason: 'Real local OTP request succeeds.',
      );
      await waitFor(tester, find.byKey(const Key('auth-code-field')));
      final otp = await _localOtp(mailpit);
      await tester.enterText(find.byKey(const Key('auth-code-field')), otp);
      await deliver(link(proposal));
      expect(
        tester
                .widget<TextField>(find.byKey(const Key('auth-code-field')))
                .controller!
                .text ==
            otp,
        isTrue,
      );
      await tap('auth-verify-button');
      // Real OTP automatically opens setup with the bound invitation returnTo.
      await waitFor(
        tester,
        find.byKey(const Key('profile-display-name-field')),
      );
      await tester.enterText(
        find.byKey(const Key('profile-display-name-field')),
        'TW-STACK01 native',
      );
      await deliver(link(proposal));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('profile-display-name-field')),
            )
            .controller!
            .text,
        'TW-STACK01 native',
      );
      await tap('profile-save-button');
      await waitFor(tester, find.byKey(const Key('participant-invite-join')));
      final actor = c.read(authSessionProvider).identity!.id;
      final photos = c.read(profilePhotoGatewayProvider);
      final participation = c.read(participationGatewayProvider);
      expect(await photos.loadOwnPhoto(actor), isNull);
      expect(await participation.listOwnMemberships(actor), isEmpty);
      for (final token in [proposal, tavolo]) {
        if (token != proposal) await deliver(link(token));
        await tap('participant-invite-join');
        await waitFor(
          tester,
          find.byKey(const Key('participant-invite-current')),
        );
        final membership = c
            .read(participantAdmissionProvider)
            .result!
            .membershipId;
        await deliver(link(token));
        expect(
          c.read(participantAdmissionProvider).result!.membershipId,
          membership,
        );
        await tap('participant-invite-open-chat');
        await waitFor(tester, find.byType(ProjectChatScreen));
        router.pop();
        await waitFor(
          tester,
          find.byKey(const Key('participant-invite-current')),
        );
      }
      final memberships = await participation.listOwnMemberships(actor);
      expect(memberships, hasLength(2));
      expect(memberships.every((m) => m.originatingRequestId == null), isTrue);
      expect(await photos.loadOwnPhoto(actor), isNull);
      await deliver(link(full));
      await tap('participant-invite-join');
      await waitUntil(
        tester,
        () =>
            c.read(participantAdmissionProvider).failure ==
            ParticipantInviteFailure.full,
        label: 'canonical Full rejection',
      );
      final blocks = SupabaseBlockingGateway(client);
      await blocks.block(
        expectedBlockerProfileId: actor,
        targetProfileId: owner,
      );
      // Preview is public; an explicit admission enforces the new block episode.
      await deliver(link(tavolo));
      await deliver(link(full));
      await tap('participant-invite-join');
      await waitUntil(
        tester,
        () =>
            c.read(participantAdmissionProvider).failure ==
            ParticipantInviteFailure.unavailable,
        label: 'canonical blocked admission denial',
      );
      await blocks.unblock(
        expectedBlockerProfileId: actor,
        targetProfileId: owner,
      );
      router.go('/proposals/create');
      await waitFor(tester, find.byKey(const Key('proposal-title')));
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'TW-STACK01 guarded native draft',
      );
      await deliver(link(tavolo));
      await waitFor(
        tester,
        find.byKey(const Key('participant-invite-current')),
      );
      final own = (await drafts.listOwnProposals(actor))
          .singleWhere((p) => p.title == 'TW-STACK01 guarded native draft');
      router.go('/proposals/${own.id}/edit');
      await waitFor(tester, find.byKey(const Key('proposal-title')));
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'TW-STACK01 failed departure then retry',
      );
      drafts.failNext = true;
      await deliver(link(proposal));
      await waitFor(tester, find.text('Keep editing'));
      await tester.tap(find.text('Keep editing'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('proposal-title')), findsOneWidget);
      await deliver(link(proposal));
      await waitFor(
        tester,
        find.byKey(const Key('participant-invite-current')),
      );
      expect(
        (await drafts.getOwnProposal(actor, own.id))!.title,
        'TW-STACK01 failed departure then retry',
      );
      router.go('/proposals/${own.id}/edit');
      await waitFor(tester, find.byKey(const Key('proposal-title')));
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'TW-STACK01 invalid link saved safely',
      );
      await deliver('https://untrusted.invalid/join/project/unavailable');
      await waitUntil(
        tester,
        () =>
            router.routeInformationProvider.value.uri.path ==
            '/link-unavailable',
      );
      expect(
        (await drafts.getOwnProposal(actor, own.id))!.title,
        'TW-STACK01 invalid link saved safely',
      );
      router.go('/proposals/${own.id}/edit');
      await waitFor(tester, find.byKey(const Key('proposal-title')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('proposal-title')))
            .controller!
            .text,
        'TW-STACK01 invalid link saved safely',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

// Local synthetic mailbox only; OTP never leaves memory or enters test logs.
Future<String> _localOtp(String origin) async {
  final http = HttpClient();
  Future<Map<String, dynamic>> get(String path) async {
    final response = await (await http.getUrl(Uri.parse('$origin$path')))
        .close();
    if (response.statusCode != 200) {
      throw StateError('Local mailbox read failed.');
    }
    return jsonDecode(await response.transform(utf8.decoder).join())
        as Map<String, dynamic>;
  }

  try {
    final box = await get(
      '/api/v1/search?query=to%3Atw-stack01-native%40planets.invalid&limit=1',
    );
    final message = await get(
      '/api/v1/message/${(box['messages'] as List).single['ID']}',
    );
    final code = RegExp(r'(?:^|\D)(\d{6})(?:\D|$)')
        .firstMatch('${message['Text']} ${message['HTML']}')
        ?.group(1);
    if (code == null) throw StateError('Local synthetic OTP absent.');
    return code;
  } finally {
    http.close();
  }
}

class _FailOnceUpdate extends SupabaseProposalGateway {
  _FailOnceUpdate(super.client);
  bool failNext = false;
  @override
  Future<void> updateOwnProposal(
    String actor,
    String id,
    ProposalInput input,
  ) async {
    if (failNext) {
      failNext = false;
      throw const SocketException('Controlled pre-commit departure failure.');
    }
    await super.updateOwnProposal(actor, id, input);
  }
}
