import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/widgets/error_state.dart';
import 'package:planets_mobile/core/widgets/loading_state.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/presentation/request_code_screen.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/domain/profile_models.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_profile_photo.dart';

void main() {
  testWidgets('Profile idle and loading render loading without a fake error', (
    tester,
  ) async {
    final pending = Completer<ProfileEditorData>();
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final anchor = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.complete;
    final profile = FakeProfileGateway()..loadResult = (_) => pending.future;
    addTearDown(auth.close);
    final app = await _pumpApp(tester, auth, anchor, profile);

    app.read(appRouterProvider).go('/profile');
    // Complete awaitable route entry before asserting the pending data load.
    await tester.pump();
    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    pending.complete(profileFixture(complete: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-display-name')), findsOneWidget);
  });

  testWidgets('Profile setup idle and loading render loading', (tester) async {
    final pending = Completer<ProfileEditorData>();
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final anchor = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.incomplete;
    final profile = FakeProfileGateway()..loadResult = (_) => pending.future;
    addTearDown(auth.close);
    final app = await _pumpApp(tester, auth, anchor, profile);

    app.read(appRouterProvider).go('/profile/edit');
    // Complete awaitable route entry before asserting the pending data load.
    await tester.pump();
    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    pending.complete(profileFixture());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-display-name-field')), findsOneWidget);
  });

  testWidgets('a genuine Profile load failure remains retryable', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final anchor = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.complete;
    final profile = FakeProfileGateway()
      ..loadError = StateError('private Profile diagnostic');
    addTearDown(auth.close);
    final app = await _pumpApp(tester, auth, anchor, profile);

    app.read(appRouterProvider).go('/profile');
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('private Profile diagnostic'), findsNothing);
  });

  testWidgets('signed-out Profile is a static example with explicit Auth CTA', (
    tester,
  ) async {
    final auth = FakeAuthGateway(snapshot: const AuthSnapshot());
    final anchor = FakeProfileAnchorGateway();
    final profile = FakeProfileGateway();
    addTearDown(auth.close);
    await _pumpApp(tester, auth, anchor, profile);

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-email-field')), findsNothing);
    expect(find.byKey(const Key('profile-example-label')), findsOneWidget);
    expect(find.text('Example profile'), findsOneWidget);
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('Community activity — example'), findsOneWidget);
    expect(find.text('Example community badge'), findsOneWidget);
    expect(profile.loadCount, 0);

    await _tapVisible(
      tester,
      find.byKey(const Key('profile-example-sign-in-button')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<RequestCodeScreen>(find.byType(RequestCodeScreen)).returnTo,
      '/profile',
    );
  });

  testWidgets('demo sample fills controlled profile fields without saving', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final anchor = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.incomplete;
    final profile = FakeProfileGateway();
    addTearDown(auth.close);
    await _pumpApp(tester, auth, anchor, profile);
    await tester.tap(find.text('Complete profile'));
    await tester.pumpAndSettle();

    final fill = find.byKey(const Key('profile-fill-sample'));
    expect(fill, findsOneWidget);
    await tester.tap(fill);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('profile-display-name-field')),
          )
          .controller
          ?.text,
      'Casey Rivers',
    );
    expect(
      find.byKey(const Key('profile-skills-selected-mural-painting')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<SegmentedButton<ProfileAudience>>(
            find.byKey(const Key('profile-visibility-bio')),
          )
          .selected,
      {ProfileAudience.private},
    );
    expect(profile.updateCount, 0);
  });

  testWidgets('incomplete owner selects categorized skills and visibility', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final anchor = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.incomplete;
    final profile = FakeProfileGateway();
    addTearDown(auth.close);
    await _pumpApp(tester, auth, anchor, profile);

    expect(find.text('Complete profile'), findsOneWidget);
    await tester.tap(find.text('Complete profile'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsNothing);
    final skillsTrigger = find.byKey(const Key('profile-skills-trigger'));
    expect(skillsTrigger, findsOneWidget);
    expect(
      find.descendant(of: skillsTrigger, matching: find.text('Select skills')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: skillsTrigger, matching: find.text('Skills')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('profile-save-button')).hitTestable(),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      '  Casey  ',
    );
    await _tapVisible(tester, skillsTrigger);
    expect(find.text('Art & Creativity'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    await _tapVisible(
      tester,
      find.byKey(const Key('profile-skills-option-mural-painting')),
    );
    expect(profile.updateCount, 0, reason: 'selection stays local until Save');
    await _tapVisible(tester, find.byKey(const Key('profile-skills-apply')));
    expect(
      find.descendant(of: skillsTrigger, matching: find.text('Select skills')),
      findsNothing,
    );
    expect(
      find.descendant(of: skillsTrigger, matching: find.text('Skills')),
      findsOneWidget,
    );
    final bioVisibility = find.byKey(const Key('profile-visibility-bio'));
    await _tapVisible(
      tester,
      find.descendant(of: bioVisibility, matching: find.text('Private')),
    );
    await _tapVisible(tester, find.byKey(const Key('profile-save-button')));
    await tester.pumpAndSettle();

    expect(profile.updateCount, 1);
    expect(profile.lastUpdate?.displayName, 'Casey');
    expect(profile.lastUpdate?.selectedSkillIds, contains('skill-mural'));
    expect(
      profile.lastUpdate?.visibility[ProfileFieldKey.bio],
      ProfileAudience.private,
    );
    expect(find.byKey(const Key('profile-display-name')), findsOneWidget);
    expect(find.text('Casey'), findsOneWidget);
    expect(find.text('Mural painting'), findsOneWidget);
    expect(
      find.byKey(const Key('profile-blocked-users-button')),
      findsOneWidget,
    );
  });

  testWidgets('invalid display name and oversized bio stay in the form', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final anchor = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.incomplete;
    final profile = FakeProfileGateway();
    addTearDown(auth.close);
    await _pumpApp(tester, auth, anchor, profile);
    await tester.tap(find.text('Complete profile'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      'X',
    );
    await tester.enterText(
      find.byKey(const Key('profile-bio-field')),
      List.filled(501, 'b').join(),
    );
    await _scrollToBottom(tester);
    await _tapVisible(tester, find.byKey(const Key('profile-save-button')));
    await tester.pump();

    expect(find.textContaining('2 to 60 characters'), findsOneWidget);
    expect(find.textContaining('500 characters or fewer'), findsOneWidget);
    expect(profile.updateCount, 0);
  });

  testWidgets('raw save failures are hidden and retry remains available', (
    tester,
  ) async {
    const rawFailure = 'private profile backend stack';
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final anchor = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.incomplete;
    final profile = FakeProfileGateway()..updateError = StateError(rawFailure);
    addTearDown(auth.close);
    await _pumpApp(tester, auth, anchor, profile);
    await tester.tap(find.text('Complete profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      'Casey',
    );
    await _scrollToBottom(tester);
    await _tapVisible(tester, find.byKey(const Key('profile-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-safe-error')), findsOneWidget);
    expect(
      find.byKey(const Key('profile-safe-error')).hitTestable(),
      findsOneWidget,
    );
    expect(find.textContaining(rawFailure), findsNothing);
    expect(find.byKey(const Key('profile-save-button')), findsOneWidget);
  });

  testWidgets('saved skill state restores and can be deselected', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final anchor = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.complete;
    final profile = FakeProfileGateway(data: profileFixture(complete: true));
    addTearDown(auth.close);
    await _pumpApp(tester, auth, anchor, profile);
    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    expect(find.text('Musician'), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('profile-edit-button')));
    await tester.pumpAndSettle();
    final musician = find.byKey(const Key('profile-skills-selected-musician'));
    expect(musician, findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    await _tapVisible(
      tester,
      find.descendant(of: musician, matching: find.byIcon(Icons.cancel)),
    );
    await tester.pump();
    expect(musician, findsNothing);
    await _tapVisible(tester, find.byKey(const Key('profile-save-button')));
    await tester.pumpAndSettle();

    expect(profile.lastUpdate?.selectedSkillIds, isEmpty);
    expect(find.text('No skills selected yet.'), findsOneWidget);
  });

  testWidgets('a later account never renders the prior owner profile', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final anchor = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.complete;
    final profile = FakeProfileGateway()
      ..loadData = (userId) => profileFixture(
        complete: true,
        id: userId,
        displayName: userId == 'user-1' ? 'Casey' : 'Jordan',
      );
    addTearDown(auth.close);
    await _pumpApp(tester, auth, anchor, profile);
    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    expect(find.text('Casey'), findsOneWidget);

    auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'user-2')));
    await tester.pumpAndSettle();

    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text('Casey'), findsNothing);
    expect(profile.loadCount, 2);
  });
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  FakeAuthGateway auth,
  FakeProfileAnchorGateway anchor,
  FakeProfileGateway profile, {
  String enableDemoTools = '',
  FakeProfilePhotoGateway? profilePhoto,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'test-key',
            enableDemoTools: enableDemoTools,
          ),
        ),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(anchor),
        profileGatewayProvider.overrideWithValue(profile),
        profilePhotoGatewayProvider.overrideWithValue(
          profilePhoto ?? FakeProfilePhotoGateway(),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(SingleChildScrollView),
    const Offset(0, -400),
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
  await tester.pumpAndSettle();
}
