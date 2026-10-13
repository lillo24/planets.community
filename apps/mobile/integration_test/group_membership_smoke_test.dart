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
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/features/group_membership/data/group_relationship_gateway.dart';
import 'package:planets_mobile/features/group_membership/application/group_relationship_controller.dart';
import 'package:planets_mobile/features/group_membership/domain/group_relationships.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/policies/application/policy_documents.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/domain/profile_photo_models.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'groups_smoke_test.dart' as harness show waitUntil, waitFor, reveal;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'real OTP/PostgREST group requests, review, People, reusable admission, roles and restore',
    (tester) async {
      final config = AppConfig.fromCompileTime();
      if (config.environment != AppEnvironment.local ||
          ![
            '127.0.0.1',
            'localhost',
            '::1',
          ].contains(config.supabaseUrl.host)) {
        throw StateError(
          'Explicit disposable loopback config and adb reverse required.',
        );
      }
      const creator = String.fromEnvironment('GRP03B_CREATOR_ID'),
          creatorToken = String.fromEnvironment('GRP03B_CREATOR_TOKEN'),
          requester = String.fromEnvironment('GRP03B_REQUESTER_ID'),
          requesterToken = String.fromEnvironment('GRP03B_REQUESTER_TOKEN'),
          delegate = String.fromEnvironment('GRP03B_DELEGATE_ID'),
          delegateToken = String.fromEnvironment('GRP03B_DELEGATE_TOKEN'),
          group = String.fromEnvironment('GRP03B_GROUP'),
          link = String.fromEnvironment('GRP03B_LINK'),
          invitation = String.fromEnvironment('GRP03B_AUTHORITY');
      if ([
        creator,
        creatorToken,
        requester,
        requesterToken,
        delegate,
        delegateToken,
        group,
        link,
        invitation,
      ].any((v) => v.isEmpty)) {
        throw StateError('Prepare group membership smoke defines first.');
      }
      var token = requesterToken, admissions = 0, authorityAdmissions = 0;
      final client = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () => Future.value(token),
      );
      addTearDown(client.dispose);
      final gateway = GroupGateway((operation, params) async {
        final result = await client.rpc(operation, params: params);
        if (operation == 'accept_group_participant_invitation' &&
            ++admissions == 1) {
          throw const SocketException(
            'Synthetic response loss after acceptance.',
          );
        }
        if (operation == 'accept_group_authority_invitation' &&
            ++authorityAdmissions == 1) {
          throw const SocketException('Synthetic authority response loss.');
        }
        return result;
      });
      final relations = GroupRelationshipGateway(gateway);
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          supabaseClientProvider.overrideWithValue(client),
          authGatewayProvider.overrideWithValue(_LocalIdentity(requester)),
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
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PlanetsApp(),
        ),
      );
      final originalErrorHandler = FlutterError.onError!;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('RenderFlex')) {
          debugPrint(details.toString());
        }
        originalErrorHandler(details);
      };
      addTearDown(() => FlutterError.onError = originalErrorHandler);
      final router = container.read(appRouterProvider);
      Future<void> actor(String id, String jwt) async {
        token = jwt;
        container
            .read(authSessionProvider.notifier)
            .markProfileReady(AuthIdentity(id: id));
        await tester.pump(const Duration(milliseconds: 300));
        await harness.waitUntil(
          tester,
          () => container
              .read(policyAcceptanceProvider)
              .allows(id, policyBundleVersion),
        );
      }

      Future<void> tapKey(String key) async {
        await harness.reveal(tester, find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> confirm() async {
        await harness.waitFor(tester, find.byType(AlertDialog));
        await tester.tap(find.text('Confirm').last);
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> shot(String name) async {
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot('grp03b-$name');
      }

      Future<void> canonicalWait(Future<bool> Function() check) async {
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (DateTime.now().isBefore(deadline)) {
          if (await check()) return;
          await tester.pump(const Duration(milliseconds: 100));
        }
        fail('Canonical relationship transition did not complete.');
      }

      await binding.convertFlutterSurfaceToImage();
      await actor(requester, requesterToken);
      router.go('/proposals');
      await harness.waitFor(tester, find.byKey(const Key('browse-groups')));
      await shot('browse-toolbar-en');
      await container
          .read(languagePreferenceProvider.notifier)
          .select(LanguagePreference.italian);
      router.go('/tavoli');
      await harness.waitFor(tester, find.byKey(const Key('browse-groups')));
      await shot('browse-toolbar-it');
      await container
          .read(languagePreferenceProvider.notifier)
          .select(LanguagePreference.english);
      router.go('/groups/$group');
      await tester.pump(const Duration(seconds: 1));
      await harness.reveal(tester, find.byKey(const Key('group-request-note')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('group-request-note')),
      );
      await tester.enterText(
        find.byKey(const Key('group-request-note')),
        'I can help on Saturdays.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tapKey('group-submit-request');
      await harness.waitFor(
        tester,
        find.byKey(const Key('profile-photo-trust-gate')),
      );
      expect((await relations.self(requester, group)).pendingRequestId, isNull);
      await tester.tap(find.byKey(const Key('profile-photo-trust-add')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('profile-display-name-field')),
      );
      // Commit a fictional tiny WebP through real Storage and canonical photo RPC.
      // The native gallery/crop picker itself is outside this group journey.
      final photo = container.read(profilePhotoGatewayProvider),
          path = '$requester/${const Uuid().v4()}.webp';
      await photo.uploadNewPhoto(
        path,
        base64Decode(
          'UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA',
        ),
      );
      await photo.commitOwnPhoto(
        requester,
        path,
        ProfilePhotoAudience.interactions,
      );
      await tester.tap(find.byKey(const Key('profile-cancel-button')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('group-request-note')),
      );
      await harness.reveal(tester, find.byKey(const Key('group-request-note')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('group-request-note')))
            .controller!
            .text,
        'I can help on Saturdays.',
      );
      await shot('request-retained-after-photo-en');
      expect((await relations.self(requester, group)).pendingRequestId, isNull);
      await tapKey('group-submit-request');
      await harness.waitFor(tester, find.byKey(const Key('group-withdraw')));
      final request = (await relations.self(
        requester,
        group,
      )).pendingRequestId!;
      await actor(creator, creatorToken);
      router.go('/groups/$group/requests');
      await harness.waitFor(tester, find.text('I can help on Saturdays.'));
      await harness.reveal(tester, find.text('Accept'));
      await tester.tap(find.text('Accept'));
      await confirm();
      await harness.waitUntil(
        tester,
        () => find.text('Accepted').evaluate().isNotEmpty,
      );
      expect(
        (await relations.history(
          creator,
          GroupHistoryKind.requests,
          group: group,
        )).singleWhere((r) => r.id == request).status,
        'accepted',
      );
      router.go('/groups/$group/people');
      await harness.waitFor(tester, find.text('Fictional requester'));
      await shot('people-creator-en');
      await actor(requester, requesterToken);
      router.go('/groups/$group');
      await harness.waitFor(tester, find.byKey(const Key('group-leave')));
      await tapKey('group-leave');
      await confirm();
      await harness.waitFor(
        tester,
        find.byKey(const Key('group-submit-request')),
      );
      expect((await relations.self(requester, group)).membershipId, isNull);
      router.go('/join/group/$link');
      await harness.waitFor(
        tester,
        find.byKey(const Key('group-invite-accept')),
      );
      await tapKey('group-invite-accept');
      await harness.waitUntil(tester, () => admissions == 1);
      await harness.waitUntil(
        tester,
        () => !container.read(groupInvitationControllerProvider).busy,
      );
      await shot('participant-lost-response-en');
      await tapKey('group-invite-accept');
      await harness.waitUntil(
        tester,
        () => container.read(groupInvitationControllerProvider).confirmed,
      );
      await harness.reveal(tester, find.text('You are part of this group'));
      expect(admissions, 1);
      await shot('participant-confirmed-en');

      // Tokenless offers target the current membership episode. Declining does
      // not end participation; Leave and Step down remain independent exits.
      Future<void> offer() async {
        await actor(creator, creatorToken);
        router.go('/groups/$group/people');
        await harness.waitFor(tester, find.text('Fictional requester'));
        await harness.reveal(tester, find.text('Offer an organizer role'));
        await tester.tap(find.text('Offer an organizer role'));
        await harness.waitFor(tester, find.byType(SimpleDialog));
        await tester.tap(find.text('Co-organizer').last);
        await confirm(); // deliberate offer confirmation
        await canonicalWait(
          () async => (await relations.history(
            creator,
            GroupHistoryKind.offers,
            group: group,
          )).any((r) => r.status == 'pending' && r.personId == requester),
        );
        await actor(requester, requesterToken);
        router.go('/groups/mine/offers');
        await harness.waitFor(tester, find.text('Pending'));
      }

      await offer();
      await harness.reveal(tester, find.text('Decline'));
      await tester.tap(find.text('Decline'));
      await confirm();
      await harness.waitFor(tester, find.text('Declined'));
      expect((await relations.self(requester, group)).membershipId, isNotNull);
      expect((await relations.self(requester, group)).authority, isNull);
      await offer();
      await harness.reveal(tester, find.text('Accept'));
      await tester.tap(find.text('Accept'));
      await confirm();
      await canonicalWait(
        () async =>
            (await relations.self(requester, group)).authority ==
            GroupAuthority.coOrganizer,
      );
      expect(
        (await relations.self(requester, group)).authority,
        GroupAuthority.coOrganizer,
      );
      await harness.reveal(tester, find.text('Accepted'));
      await shot('own-offer-accepted-en');
      router.go('/groups/$group');
      await tester.pump(const Duration(seconds: 1));
      await tapKey('group-leave');
      await confirm();
      await canonicalWait(
        () async =>
            (await relations.self(requester, group)).membershipId == null,
      );
      final organizerOnly = await relations.self(requester, group);
      expect(organizerOnly.membershipId, isNull);
      expect(organizerOnly.authority, GroupAuthority.coOrganizer);
      await tapKey('group-step-down');
      await confirm();
      await canonicalWait(
        () async => (await relations.self(requester, group)).authority == null,
      );
      expect((await relations.self(requester, group)).authority, isNull);
      await actor(delegate, delegateToken);
      router.go('/invite/group/$invitation');
      await harness.waitUntil(
        tester,
        () => !container.read(groupInvitationControllerProvider).loading,
      );
      await harness.reveal(
        tester,
        find.byKey(const Key('group-invite-accept')),
      );
      await shot('authority-preview-en');
      await tapKey('group-invite-accept');
      await confirm();
      await harness.waitUntil(
        tester,
        () =>
            authorityAdmissions == 1 &&
            !container.read(groupInvitationControllerProvider).busy,
      );
      await tapKey('group-invite-preview-retry');
      await harness.waitUntil(
        tester,
        () => !container.read(groupInvitationControllerProvider).loading,
      );
      expect(
        container.read(groupInvitationControllerProvider).preview?.available,
        false,
      );
      await tapKey('group-invite-accept');
      await confirm();
      await harness.waitUntil(
        tester,
        () => container.read(groupInvitationControllerProvider).confirmed,
      );
      expect(authorityAdmissions, 1);
      expect(
        (await relations.self(delegate, group)).authority,
        GroupAuthority.coCreator,
      );
      router.go('/groups/$group/team');
      await harness.waitFor(tester, find.text('Fictional delegate'));
      await shot('team-co-creator-en');
      await container
          .read(languagePreferenceProvider.notifier)
          .select(LanguagePreference.italian);
      await tester.pump(const Duration(milliseconds: 500));
      await shot('team-co-creator-it');
      await container
          .read(languagePreferenceProvider.notifier)
          .select(LanguagePreference.english);
      router.go('/groups/$group/structural-edit');
      await harness.waitFor(tester, find.byKey(const Key('group-name')));
      await tapKey('group-archive');
      await confirm();
      await harness.waitFor(tester, find.byKey(const Key('group-restore')));
      await tapKey('group-restore');
      await confirm();
      await harness.waitUntil(
        tester,
        () =>
            router.routerDelegate.state.uri.path !=
            '/groups/$group/structural-edit',
      );
      expect(await gateway.publicDetail(group), isNull);
      router.go('/groups/$group');
      await harness.waitFor(tester, find.byKey(const Key('group-step-down')));
      await tapKey('group-step-down');
      await confirm();
      await harness.waitUntil(
        tester,
        () => find.byKey(const Key('group-step-down')).evaluate().isEmpty,
      );
      expect((await relations.self(delegate, group)).authority, isNull);
      // Creator alone can still read the restored private draft.
      await actor(creator, creatorToken);
      expect(
        (await gateway.ownDetail(creator, group)).publication.name,
        'draft',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

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
