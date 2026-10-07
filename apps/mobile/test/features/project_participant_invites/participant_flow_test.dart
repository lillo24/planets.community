import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/application/auth_command_controller.dart';
import 'package:planets_mobile/features/auth/application/return_destination.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/presentation/request_code_screen.dart';
import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/presentation/profile_edit_screen.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/project_delegates/application/project_invite_sharing.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/project_participant_invites/application/participant_admission_refresh.dart';
import 'package:planets_mobile/features/project_participant_invites/data/participant_invitation_gateway.dart';
import 'package:planets_mobile/features/project_participant_invites/domain/participant_invitation_models.dart';
import 'package:planets_mobile/features/project_participant_invites/presentation/participant_invitation_routes.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/data/similar_proposal_gateway.dart';
import 'package:planets_mobile/features/cover_media/application/project_cover_reconciler.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_blocking.dart';
import '../../support/fake_participation.dart';
import '../../support/fake_participant_invitation.dart';
import '../../support/fake_profile.dart';
import '../../support/fake_profile_photo.dart';
import '../../support/fake_project_delegates.dart';
import '../../support/fake_project_resource_needs.dart';
import '../../support/fake_proposal.dart';
import '../../support/fake_similar_proposal.dart';
import '../../support/fake_cover_media.dart';
import '../../support/fake_recurring_activity.dart';

void main() {
  final token = 'A' * 43;
  const publicId = 'fb040000-0000-4000-8000-000000000002';
  final nativeInvite = 'https://planets.community/join/project/$token';
  for (final operation in ['go', 'replace', 'pushReplacement', 'pop']) {
    testWidgets('ordinary $operation keeps the integrated editor guard', (
      tester,
    ) async {
      final drafts = FakeProposalGateway();
      final h = await _pump(tester, '/link-unavailable', drafts: drafts);
      h.router.push('/proposals/create/scratch');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Internal departure',
      );
      switch (operation) {
        case 'go':
          h.router.go('/link-unavailable');
        case 'replace':
          h.router.replace<void>('/link-unavailable');
        case 'pushReplacement':
          h.router.pushReplacement<void>('/link-unavailable');
        case 'pop':
          h.router.pop();
      }
      await tester.pumpAndSettle();
      expect(drafts.ownItems, hasLength(1));
      expect(drafts.calls.where((c) => c == 'create'), hasLength(1));
      expect(h.router.state.uri.path, '/link-unavailable');
      expect(h.gateway.admissions, isEmpty);
    });
  }
  for (final destination in ['/link-unavailable', nativeInvite]) {
    testWidgets('integrated router saves dirty editor before $destination', (
      tester,
    ) async {
      final drafts = FakeProposalGateway();
      final h = await _pump(
        tester,
        '/proposals/create/scratch',
        drafts: drafts,
      );
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Saved departure',
      );
      if (destination.startsWith('https')) {
        await _deliver(tester, destination);
      } else {
        h.router.push(destination);
        await tester.pumpAndSettle();
      }
      expect(drafts.calls.where((c) => c == 'create'), hasLength(1));
      expect(h.router.state.uri.path, Uri.parse(destination).path);
      expect(h.gateway.admissions, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'native departure save failure stays in editor and retry saves once',
    (tester) async {
      final drafts = FakeProposalGateway()
        ..mutationError = StateError('save unavailable');
      final h = await _pump(
        tester,
        '/proposals/create/scratch',
        drafts: drafts,
      );
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Recoverable',
      );
      await _deliver(tester, nativeInvite);
      expect(h.router.state.uri.path, '/proposals/create/scratch');
      expect(h.gateway.admissions, isEmpty);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      drafts.mutationError = null;
      await _deliver(tester, nativeInvite);
      expect(h.router.state.uri.path, '/join/project/$token');
      expect(drafts.lastInput!.title, 'Recoverable');
      expect(drafts.ownItems, hasLength(1));
    },
  );
  testWidgets(
    'competing internal route preserves the first native guarded replay',
    (tester) async {
      final pending = Completer<void>();
      final drafts = FakeProposalGateway()..mutationDelay = pending.future;
      final h = await _pump(
        tester,
        '/proposals/create/scratch',
        drafts: drafts,
      );
      await tester.enterText(find.byKey(const Key('proposal-title')), 'Replay');
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('pushRouteInformation', {'location': nativeInvite}),
        ),
        (_) {},
      );
      await tester.pump();
      final competing = h.router.push<void>(
        '/link-unavailable',
        extra: 'retained',
      );
      await tester.pump();
      pending.complete();
      await tester.pumpAndSettle();
      await competing;
      expect(h.router.state.uri.path, '/join/project/$token');
      expect(drafts.ownItems, hasLength(1));
      expect(drafts.calls.where((c) => c == 'create'), hasLength(1));
      expect(h.gateway.admissions, isEmpty);
    },
  );
  testWidgets(
    'account switch during delayed native departure cancels delivery',
    (tester) async {
      final pending = Completer<void>();
      final drafts = FakeProposalGateway()..mutationDelay = pending.future;
      final h = await _pump(
        tester,
        '/proposals/create/scratch',
        drafts: drafts,
      );
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Old actor',
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('pushRouteInformation', {'location': nativeInvite}),
        ),
        (_) {},
      );
      await tester.pump();
      h.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      pending.complete();
      await tester.pumpAndSettle();
      expect(h.router.state.uri.path, isNot('/join/project/$token'));
      expect(h.gateway.admissions, isEmpty);
      expect(find.text('Draft saved'), findsNothing);
    },
  );
  testWidgets('native cold start tolerates Auth restoration during entry', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      nativeInvite,
      platformColdStart: true,
      startAuthInApp: true,
    );
    expect(h.router.state.uri.path, '/join/project/$token');
    expect(find.text('Community mural'), findsOneWidget);
    expect(h.gateway.admissions, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('platform cold start previews; warm duplicates never Join', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      nativeInvite,
      platformColdStart: true,
      signedOut: true,
    );
    expect(h.router.state.uri.toString(), '/join/project/$token');
    expect(find.text('Community mural'), findsOneWidget);
    expect(find.textContaining('project-1'), findsNothing);
    expect(h.gateway.admissions, isEmpty);
    await _deliver(tester, nativeInvite);
    expect(h.gateway.admissions, isEmpty);
    await tester.tap(find.byKey(const Key('participant-invite-sign-in')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'synthetic@planets.invalid',
    );
    await _deliver(tester, nativeInvite);
    expect(h.router.state.uri.path, '/auth');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('auth-email-field')))
          .controller!
          .text,
      'synthetic@planets.invalid',
    );
    expect(
      h.router.state.uri.queryParameters['returnTo'],
      '/join/project/$token',
    );
    await tester.tap(find.byKey(const Key('auth-request-button')));
    await tester.pumpAndSettle();
    await _deliver(tester, nativeInvite);
    expect(h.router.state.uri.path, '/auth/verify');
    expect(
      h.container.read(pendingEmailOtpProvider)?.returnTo,
      '/join/project/$token',
    );
    await _deliver(
      tester,
      'https://planets.community/join/project/${'B' * 43}',
    );
    expect(h.router.state.uri.path, '/join/project/${'B' * 43}');
    expect(h.container.read(pendingEmailOtpProvider), isNull);
    expect(h.gateway.admissions, isEmpty);
  });
  testWidgets('platform new link cancels an in-flight OTP request', (
    tester,
  ) async {
    final pending = Completer<void>();
    final h = await _pump(
      tester,
      nativeInvite,
      platformColdStart: true,
      signedOut: true,
    );
    final auth = h.container.read(authGatewayProvider) as FakeAuthGateway;
    auth.requestDelay = pending.future;
    await tester.tap(find.byKey(const Key('participant-invite-sign-in')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'synthetic@planets.invalid',
    );
    await tester.tap(find.byKey(const Key('auth-request-button')));
    await tester.pump();
    await _deliver(
      tester,
      'https://planets.community/join/project/${'B' * 43}',
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(h.router.state.uri.path, '/join/project/${'B' * 43}');
    expect(h.container.read(pendingEmailOtpProvider), isNull);
    expect(h.gateway.admissions, isEmpty);
  });
  testWidgets(
    'platform duplicate keeps profile return; new link cancels old OTP',
    (tester) async {
      final h = await _pump(
        tester,
        nativeInvite,
        incomplete: true,
        platformColdStart: true,
      );
      await tester.tap(find.byKey(const Key('participant-invite-profile')));
      await tester.pumpAndSettle();
      await _deliver(tester, nativeInvite);
      expect(h.router.state.uri.path, '/profile/edit');
      expect(
        h.router.state.uri.queryParameters['returnTo'],
        '/join/project/$token',
      );
      h.container
          .read(pendingEmailOtpProvider.notifier)
          .set(
            PendingEmailOtp(
              email: 'synthetic@planets.invalid',
              returnTo: '/join/project/$token',
            ),
          );
      final other = 'B' * 43;
      await _deliver(tester, 'https://planets.community/join/project/$other');
      expect(h.router.state.uri.toString(), '/join/project/$other');
      expect(h.container.read(pendingEmailOtpProvider), isNull);
      expect(h.gateway.admissions, isEmpty);
      expect(h.photo.uploadPaths, isEmpty);
    },
  );
  testWidgets('platform new Project ignores an old pending admission result', (
    tester,
  ) async {
    final pending = Completer<void>();
    final gateway = FakeParticipantInvitationGateway()
      ..acceptDelay = pending.future;
    final h = await _pump(
      tester,
      nativeInvite,
      gateway: gateway,
      platformColdStart: true,
    );
    await tester.tap(find.byKey(const Key('participant-invite-join')));
    await tester.pump();
    expect(gateway.admissions, hasLength(1));
    gateway.previewValue = const ParticipantInvitePreview(
      available: true,
      projectId: 'project-2',
      kind: ProjectKind.recurring,
      title: 'Another Project',
    );
    await _deliver(
      tester,
      'https://planets.community/join/project/${'B' * 43}',
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Another Project'), findsOneWidget);
    expect(h.router.state.uri.path, '/join/project/${'B' * 43}');
    expect(gateway.admissions, hasLength(1));
    h.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    await tester.pumpAndSettle();
    await _deliver(
      tester,
      'https://planets.community/join/project/${'B' * 43}',
    );
    expect(gateway.admissions, hasLength(1));
  });
  for (final family in ['proposals', 'tavoli']) {
    testWidgets(
      'platform $family ordinary query and token-free delivery stay read-only',
      (tester) async {
        final path = '/$family/$publicId';
        final h = await _pump(
          tester,
          'https://planets.community$path?intent=join',
          platformColdStart: true,
          signedOut: true,
          publicProjectId: publicId,
        );
        expect(h.router.state.uri.toString(), '$path?intent=join');
        expect(
          find.byKey(const Key('ordinary-share-intent-close')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('ordinary-share-intent-close')));
        await tester.pumpAndSettle();
        expect(h.router.state.uri.toString(), path);
        await _deliver(
          tester,
          'https://planets.community$path?intent=join&intent=join',
        );
        expect(
          find.byKey(const Key('ordinary-share-intent-close')),
          findsNothing,
        );
        await _deliver(tester, 'https://planets.community$path');
        expect(h.router.state.uri.toString(), path);
        expect(h.gateway.admissions, isEmpty);
        expect(
          h.participation.calls.where((s) => s.startsWith('request:')),
          isEmpty,
        );
      },
    );
  }
  testWidgets('platform authority delivery keeps separate explicit flow', (
    tester,
  ) async {
    final delegates = FakeProjectDelegateGateway()
      ..preview = const ProjectDelegateInvitePreview(
        isAvailable: true,
        projectId: 'project-1',
        projectKind: ProjectKind.oneTime,
        projectTitle: 'Authority Project',
        requestedAuthorityRole: ProjectDelegatedAuthorityRole.coOrganizer,
      );
    final h = await _pump(
      tester,
      'https://planets.community/invite/project/$token',
      platformColdStart: true,
      signedOut: true,
      delegateGateway: delegates,
    );
    expect(h.router.state.uri.path, '/invite/project/$token');
    expect(find.text('Authority Project'), findsOneWidget);
    expect(find.textContaining('Co-organizer'), findsWidgets);
    expect(delegates.calls.where((c) => c.startsWith('accept:')), isEmpty);
    expect(h.gateway.calls, isEmpty);
    expect(h.gateway.admissions, isEmpty);
  });
  testWidgets('platform unsafe origins and descendants show generic failure', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      nativeInvite,
      platformColdStart: true,
      signedOut: true,
    );
    for (final url in [
      'https://attacker.example/join/project/$token',
      'https://planets.community/proposals/$publicId/edit',
      'https://planets.community/join/project/${'A' * 42}%2F',
      'https://planets.community/auth?returnTo=/join/project/$token',
    ]) {
      final before = h.gateway.calls.length;
      await _deliver(tester, url);
      expect(h.router.state.uri.path, '/link-unavailable');
      expect(find.text('This page is not available.'), findsOneWidget);
      expect(h.gateway.calls.length, before);
      expect(h.gateway.admissions, isEmpty);
    }
  });
  for (final kind in ProjectKind.values) {
    final detail = kind == ProjectKind.oneTime
        ? '/proposals/project-1'
        : '/tavoli/project-1';
    testWidgets(
      'signed-out $kind copies public link and dismisses ordinary intent',
      (tester) async {
        final h = await _pump(tester, '$detail?intent=join', signedOut: true);
        expect(
          find.byKey(const Key('ordinary-share-intent-close')),
          findsOneWidget,
        );
        expect(h.gateway.admissions, isEmpty);
        expect(
          h.participation.calls.where((s) => s.startsWith('request:')),
          isEmpty,
        );
        await tester.tap(find.byKey(const Key('ordinary-share-intent-close')));
        await tester.pumpAndSettle();
        expect(h.router.state.uri.toString(), detail);
        await tester.tap(find.byKey(const Key('project-share-action')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('project-share-special')), findsNothing);
        expect(
          tester
              .widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>))
              .groupValue,
          isFalse,
        );
        await tester.tap(find.byKey(const Key('project-share-copy')));
        await tester.pumpAndSettle();
        expect(
          h.sharing.copied,
          'https://planets.community$detail?intent=join',
        );
        await tester.tap(find.byKey(const Key('project-share-native')));
        await tester.pumpAndSettle();
        expect(h.sharing.shared, h.sharing.copied);
      },
    );
    testWidgets(
      'ordinary $kind request retains public cancellation destination',
      (tester) async {
        final h = await _pump(tester, '$detail?intent=join', signedOut: true);
        await tester.tap(
          find.byKey(const Key('participation-join-project-1')).hitTestable(),
        );
        await tester.pumpAndSettle();
        expect(h.router.state.uri.path, '/auth');
        expect(
          tester
              .widget<RequestCodeScreen>(find.byType(RequestCodeScreen))
              .returnTo,
          '$detail/join',
        );
        expect(
          find.byKey(const Key('ordinary-share-intent-close')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('auth-close-button')));
        await tester.pumpAndSettle();
        expect(h.router.state.uri.path, detail);
        expect(h.gateway.admissions, isEmpty);
      },
    );
  }
  for (final role in [
    ProjectManagementRole.creator,
    ProjectManagementRole.coCreator,
    ProjectManagementRole.coOrganizer,
  ]) {
    testWidgets(
      '$role special sharing reuses link and defaults ordinary on reopening',
      (tester) async {
        final h = await _pump(tester, '/proposals/project-1', role: role);
        await tester.tap(find.byKey(const Key('project-share-action')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('project-share-special')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('project-share-copy')));
        await tester.pumpAndSettle();
        expect(
          h.sharing.copied,
          'https://planets.community/join/project/$token',
        );
        expect(
          h.gateway.calls.where((s) => s.startsWith('regenerate')),
          isEmpty,
        );
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('project-share-action')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>))
              .groupValue,
          isFalse,
        );
      },
    );
  }
  testWidgets('nonmanager shares ordinary link with no special control', (
    tester,
  ) async {
    final h = await _pump(tester, '/proposals/project-1');
    await tester.tap(find.byKey(const Key('project-share-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project-share-special')), findsNothing);
    await tester.tap(find.byKey(const Key('project-share-copy')));
    await tester.pumpAndSettle();
    expect(
      h.sharing.copied,
      'https://planets.community/proposals/project-1?intent=join',
    );
  });
  testWidgets(
    'account or Project switch closes sharing overlay and ignores pending secret',
    (tester) async {
      final h = await _pump(
        tester,
        '/proposals/project-1',
        role: ProjectManagementRole.creator,
      );
      await tester.tap(find.byKey(const Key('project-share-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('project-share-special')));
      await tester.pumpAndSettle();
      final delay = Completer<void>();
      h.gateway.readDelay = delay.future;
      await tester.tap(find.byKey(const Key('project-share-copy')));
      await tester.pump();
      h.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      await tester.pump();
      delay.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(h.sharing.copied, isNull);
      h.gateway.readDelay = null;
      await tester.tap(find.byKey(const Key('project-share-action')));
      await tester.pumpAndSettle();
      h.router.go('/tavoli/project-1');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets(
    'management copy survives canonical read; confirmed revoke uses displayed id',
    (tester) async {
      final h = await _pump(
        tester,
        '/proposals/project-1/participant-links',
        role: ProjectManagementRole.coOrganizer,
      );
      await tester.tap(find.byKey(const Key('project-share-copy')));
      await tester.pumpAndSettle();
      expect(h.sharing.copied, 'https://planets.community/join/project/$token');
      await tester.tap(find.byKey(const Key('participant-link-revoke')));
      await tester.pumpAndSettle();
      expect(h.gateway.calls.where((s) => s.startsWith('revoke')), isEmpty);
      await tester.tap(find.byKey(const Key('participant-link-confirm')));
      await tester.pumpAndSettle();
      expect(h.gateway.calls, contains('revoke:user-1:project-1:link-1'));
      expect(find.byKey(const Key('participant-link-revoke')), findsNothing);
    },
  );
  testWidgets(
    'signed-out special preview, OTP return and cancel never accept',
    (tester) async {
      final h = await _pump(tester, '/join/project/$token', signedOut: true);
      expect(find.text('Community mural'), findsOneWidget);
      expect(h.gateway.admissions, isEmpty);
      await tester.tap(find.byKey(const Key('participant-invite-sign-in')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RequestCodeScreen>(find.byType(RequestCodeScreen))
            .returnTo,
        '/join/project/$token',
      );
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        'synthetic@planets.invalid',
      );
      await tester.tap(find.byKey(const Key('auth-request-button')));
      await tester.pumpAndSettle();
      expect(h.router.state.uri.path, '/auth/verify');
      await tester.tap(find.byKey(const Key('auth-verify-close-button')));
      await tester.pumpAndSettle();
      expect(h.router.state.uri.path, '/join/project/$token');
      expect(h.gateway.admissions, isEmpty);
    },
  );
  testWidgets(
    'non-photo profile setup returns to special invite without joining',
    (tester) async {
      final h = await _pump(tester, '/join/project/$token', incomplete: true);
      await tester.tap(find.byKey(const Key('participant-invite-profile')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProfileEditScreen>(find.byType(ProfileEditScreen))
            .returnTo,
        '/join/project/$token',
      );
      await tester.tap(find.byKey(const Key('profile-cancel-button')));
      await tester.pumpAndSettle();
      expect(h.router.state.uri.path, '/join/project/$token');
      expect(h.gateway.admissions, isEmpty);
    },
  );
  testWidgets(
    'photo-free explicit join and chat failure retries only chat read',
    (tester) async {
      final h = await _pump(tester, '/join/project/$token');
      final handle = tester.ensureSemantics();

      expect(find.byKey(const Key('participant-invite-join')), findsOneWidget);
      expect(h.gateway.admissions, isEmpty);
      await tester.tap(find.byKey(const Key('participant-invite-join')));
      await tester.pumpAndSettle();
      expect(h.gateway.admissions.length, 1);
      expect(
        find.byKey(const Key('participant-invite-current')),
        findsOneWidget,
      );
      expect(h.photo.loadIds, isEmpty);
      expect(
        h.participation.calls.where((s) => s.startsWith('request:')),
        isEmpty,
      );
      h.gateway.chatError = StateError('offline');
      await tester.tap(find.byKey(const Key('participant-invite-open-chat')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('participant-invite-chat-error')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('participant-invite-open-chat')));
      await tester.pumpAndSettle();
      expect(h.gateway.admissions.length, 1);
      expect(h.gateway.calls.where((s) => s.startsWith('chat:')).length, 2);
      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );
  testWidgets(
    'ended receipt shows new explicit re-entry; newer membership shows current instead',
    (tester) async {
      final gateway = FakeParticipantInvitationGateway()
        ..receipt = const ParticipantAdmissionResult(
          projectId: 'project-1',
          membershipId: 'old-member',
          outcome: ParticipantAdmissionOutcome.joined,
          status: MembershipStatus.removed,
          replayed: true,
        );
      final h = await _pump(
        tester,
        '/join/project/$token',
        gateway: gateway,
        current: false,
      );
      await tester.tap(find.byKey(const Key('participant-invite-join')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('participant-invite-ended')), findsOneWidget);
      expect(
        find.byKey(const Key('participant-invite-rejoin')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('participant-invite-current')), findsNothing);
      expect(h.gateway.admissions.length, 1);
      await tester.tap(find.byKey(const Key('participant-invite-rejoin')));
      await tester.pumpAndSettle();
      expect(
        h.gateway.admissions.last.action,
        isNot(h.gateway.admissions.first.action),
      );
    },
  );
  testWidgets(
    'Italian unavailable and network preview copy stay distinct and hide token',
    (tester) async {
      final gateway = FakeParticipantInvitationGateway()
        ..previewValue = const ParticipantInvitePreview(available: false);
      final h = await _pump(
        tester,
        '/join/project/$token',
        gateway: gateway,
        locale: const Locale('it'),
      );
      expect(
        find.byKey(const Key('participant-invite-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining(token), findsNothing);
      gateway.previewError = StateError('private error');
      h.router.go('/join/project/${'B' * 43}');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('participant-invite-error')), findsOneWidget);
      expect(
        find.byKey(const Key('participant-invite-unavailable')),
        findsNothing,
      );
      expect(find.textContaining('private error'), findsNothing);
    },
  );
  for (final incomplete in [false, true]) {
    testWidgets(
      'OTP preserves exact invitation through ${incomplete ? 'profile completion' : 'ready session'} without automatic admission',
      (tester) async {
        final h = await _pump(
          tester,
          '/join/project/$token',
          signedOut: true,
          incomplete: incomplete,
        );
        await tester.tap(find.byKey(const Key('participant-invite-sign-in')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('auth-email-field')),
          'synthetic@planets.invalid',
        );
        await tester.tap(find.byKey(const Key('auth-request-button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('auth-code-field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('auth-verify-button')));
        await tester.pumpAndSettle();
        if (incomplete) {
          expect(find.byType(ProfileEditScreen), findsOneWidget);
          expect(
            tester
                .widget<ProfileEditScreen>(find.byType(ProfileEditScreen))
                .returnTo,
            '/join/project/$token',
          );
          await tester.enterText(
            find.byKey(const Key('profile-display-name-field')),
            'Synthetic person',
          );
          await tester.tap(find.byKey(const Key('profile-save-button')));
          await tester.pumpAndSettle();
        }
        expect(h.router.state.uri.path, '/join/project/$token');
        expect(
          find.byKey(const Key('participant-invite-join')),
          findsOneWidget,
        );
        expect(h.gateway.admissions, isEmpty);
      },
    );
  }
  testWidgets(
    'ordinary intent uses existing composer and still requires a photo at submit',
    (tester) async {
      final h = await _pump(tester, '/proposals/project-1?intent=join');
      await tester.tap(
        find.byKey(const Key('participation-join-project-1')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(h.router.state.uri.path, '/proposals/project-1/join');
      await tester.enterText(
        find.byKey(const Key('participation-message-field')),
        'I can paint.',
      );
      await tester.ensureVisible(
        find.byKey(const Key('participation-send-request')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('participation-send-request')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-photo-trust-gate')), findsOneWidget);
      expect(
        h.participation.calls.where((s) => s.startsWith('request:')),
        isEmpty,
      );
      expect(h.gateway.admissions, isEmpty);
    },
  );
  test('safe routes and intent validation preserve authority routes and exact returns', () {
    expect(ParticipantInvitationRoutes.invite(token), '/join/project/$token');
    expect(
      () => ParticipantInvitationRoutes.invite('invalid/path'),
      throwsFormatException,
    );
    expect(
      ParticipantInvitationRoutes.isInvitePath('/invite/project/$token'),
      isFalse,
    );
    expect(
      ParticipantInvitationRoutes.isInvitePath(
        'https://attacker/join/project/$token',
      ),
      isFalse,
    );
    expect(
      sanitizeReturnDestination('/join/project/$token'),
      '/join/project/$token',
    );
    expect(
      profileEditCancelDestination('/join/project/$token'),
      '/join/project/$token',
    );
    expect(
      profileEditCancelDestination('/proposals/project-1/join'),
      '/proposals/project-1',
    );
    expect(
      ParticipantInvitationRoutes.hasOrdinaryIntent(
        Uri.parse('/tavoli/id?intent=join'),
      ),
      isTrue,
    );
    expect(
      ParticipantInvitationRoutes.hasOrdinaryIntent(
        Uri.parse('/tavoli/id?intent=join&intent=join'),
      ),
      isFalse,
    );
    expect(
      ParticipantInvitationRoutes.hasOrdinaryIntent(
        Uri.parse('/tavoli/id?intent=Join'),
      ),
      isFalse,
    );
  });
}

Future<
  ({
    ProviderContainer container,
    GoRouter router,
    FakeParticipantInvitationGateway gateway,
    FakeProjectInviteSharing sharing,
    FakeParticipationGateway participation,
    FakeProfilePhotoGateway photo,
  })
>
_pump(
  WidgetTester tester,
  String location, {
  bool signedOut = false,
  bool incomplete = false,
  ProjectManagementRole role = ProjectManagementRole.none,
  FakeParticipantInvitationGateway? gateway,
  bool current = true,
  Locale locale = const Locale('en'),
  bool platformColdStart = false,
  String publicProjectId = 'project-1',
  FakeProjectDelegateGateway? delegateGateway,
  bool startAuthInApp = false,
  FakeProposalGateway? drafts,
}) async {
  if (platformColdStart) {
    tester.platformDispatcher.defaultRouteNameTestValue = location;
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  }
  final auth = FakeAuthGateway(
    snapshot: signedOut
        ? const AuthSnapshot()
        : const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final anchor = FakeProfileAnchorGateway()
    ..readiness = incomplete
        ? ProfileAnchorReadiness.incomplete
        : ProfileAnchorReadiness.complete;
  final sharing = FakeProjectInviteSharing();
  final participation = FakeParticipationGateway();
  final photo = FakeProfilePhotoGateway();
  final invitations = gateway ?? FakeParticipantInvitationGateway();
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
      profileAnchorGatewayProvider.overrideWithValue(anchor),
      profileGatewayProvider.overrideWithValue(
        FakeProfileGateway(
          data: profileFixture(complete: !incomplete, id: 'user-1'),
        ),
      ),
      profilePhotoGatewayProvider.overrideWithValue(photo),
      blockingGatewayProvider.overrideWithValue(FakeBlockingGateway()),
      participantInvitationGatewayProvider.overrideWithValue(invitations),
      participantAdmissionRefreshProvider.overrideWithValue(
        (account, project, kind) async =>
            ParticipantParticipationRead(loaded: true, current: current),
      ),
      projectDelegateGatewayProvider.overrideWithValue(
        delegateGateway ?? (FakeProjectDelegateGateway()..role = role),
      ),
      projectInviteSharingProvider.overrideWithValue(sharing),
      participationGatewayProvider.overrideWithValue(participation),
      proposalGatewayProvider.overrideWithValue(
        drafts ??
            (FakeProposalGateway()
              ..publicDetail = proposalDetailFixture(
                id: publicProjectId,
                creatorProfileId: 'organizer',
              )),
      ),
      similarProposalGatewayProvider.overrideWithValue(
        FakeSimilarProposalGateway(),
      ),
      projectCoverReconcilerProvider.overrideWithValue(
        FakeProjectCoverReconciler(),
      ),
      recurringActivityGatewayProvider.overrideWithValue(
        FakeRecurringActivityGateway()
          ..publicDetail = publicRecurringDetailFixture(
            id: publicProjectId,
            creatorProfileId: 'organizer',
          ),
      ),
      projectResourceNeedsGatewayProvider.overrideWithValue(
        FakeProjectResourceNeedsGateway(),
      ),
    ],
  );
  if (!startAuthInApp) {
    await container.read(authSessionProvider.notifier).start();
  }
  final router = container.read(appRouterProvider);
  if (!platformColdStart) router.go(location);
  addTearDown(() {
    container.dispose();
    auth.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: startAuthInApp
          ? const PlanetsApp()
          : MaterialApp.router(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    container: container,
    router: router,
    gateway: invitations,
    sharing: sharing,
    participation: participation,
    photo: photo,
  );
}

Future<void> _deliver(WidgetTester tester, String url) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', {'location': url}),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}
