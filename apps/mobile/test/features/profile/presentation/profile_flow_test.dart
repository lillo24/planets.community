import '../../../support/fake_policy.dart';

import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/theme/app_tokens.dart';
import 'package:planets_mobile/core/widgets/error_state.dart';
import 'package:planets_mobile/core/widgets/loading_state.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/presentation/request_code_screen.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/domain/profile_models.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_profile_photo.dart';

void main() {
  testWidgets(
    'Profile edit input and competence picker stay separated at 360px and 2x text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      addTearDown(auth.close);
      final app = await _pumpApp(
        tester,
        auth,
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
        FakeProfileGateway(),
      );
      app.read(appRouterProvider).go('/profile/edit');
      await tester.pumpAndSettle();
      final picker = find.byKey(const Key('profile-skills-trigger'));
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      final bio = tester.getRect(find.byKey(const Key('profile-bio-field')));
      expect(
        tester.getRect(picker).top - bio.bottom,
        greaterThanOrEqualTo(AppSpacing.large),
      );
      expect(tester.getRect(picker).right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'visibility stays in Edit Profile and the Settings privacy entry',
    (tester) async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      addTearDown(auth.close);
      final anchor = FakeProfileAnchorGateway()
        ..readiness = ProfileAnchorReadiness.complete;
      final profile = FakeProfileGateway(data: _competenceLabelFixture());
      final app = await _pumpApp(tester, auth, anchor, profile);
      final router = app.read(appRouterProvider);
      router.go('/profile');
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byKey(const Key('profile-display-name'))),
      );
      expect(find.text(l10n.profileVisibilityTitle), findsNothing);
      expect(find.text(l10n.profileAudiencePublic), findsNothing);
      expect(find.text(l10n.profileAudiencePrivate), findsNothing);
      final collection = find.byKey(const Key('profile-competence-labels'));
      final edit = find.byKey(const Key('profile-edit-button'));
      expect(
        tester.getTopLeft(edit).dy - tester.getBottomLeft(collection).dy,
        greaterThanOrEqualTo(AppSpacing.large),
      );
      await _tapVisible(tester, edit);
      expect(find.text(l10n.profileVisibilityTitle), findsOneWidget);
      for (final field in ProfileFieldKey.values) {
        expect(
          find.byKey(Key('profile-visibility-${field.wireValue}')),
          findsOneWidget,
        );
      }
      router.go('/settings');
      await tester.pumpAndSettle();
      final privacy = find.byKey(const Key('settings-profile-privacy-row'));
      await tester.scrollUntilVisible(
        privacy,
        250,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await tester.tap(privacy);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/profile/edit');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['returnTo'],
        '/settings',
      );
      expect(find.text(l10n.profileVisibilityTitle), findsOneWidget);
      for (final field in ProfileFieldKey.values) {
        expect(
          tester
              .widget<SegmentedButton<ProfileAudience>>(
                find.byKey(Key('profile-visibility-${field.wireValue}')),
              )
              .selected,
          {profile.data.profile.visibility[field]},
        );
      }
      expect(profile.updateCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.4]) {
    testWidgets(
      'read-only competences are flat, ordered and inert at 320px/$scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final auth = FakeAuthGateway(
          snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
        );
        addTearDown(auth.close);
        final anchor = FakeProfileAnchorGateway()
          ..readiness = ProfileAnchorReadiness.complete;
        final profile = FakeProfileGateway(data: _competenceLabelFixture());
        final app = await _pumpApp(tester, auth, anchor, profile);
        app.read(appRouterProvider).go('/profile');
        await tester.pumpAndSettle();
        final semantics = tester.ensureSemantics();
        try {
          final collection = find.byKey(const Key('profile-competence-labels'));
          expect(collection, findsOneWidget);
          final labels = tester
              .widgetList<Chip>(
                find.descendant(of: collection, matching: find.byType(Chip)),
              )
              .toList();
          expect(labels.map((chip) => (chip.label as Text).data).toList(), [
            'Mural painting',
            'Photography',
            'Musician',
          ]);
          for (final category in profile.data.categories) {
            expect(find.text(category.label), findsNothing);
          }
          expect(find.text('Unselected competence'), findsNothing);
          expect(
            find.descendant(
              of: collection,
              matching: find.byIcon(Icons.cancel),
            ),
            findsNothing,
          );
          expect(
            find.descendant(of: collection, matching: find.byIcon(Icons.close)),
            findsNothing,
          );
          final before = Set<String>.of(profile.data.profile.selectedSkillIds);
          for (final chip in labels) {
            final label = (chip.label as Text).data!;
            expect(find.text(label), findsOneWidget);
            expect(chip.onDeleted, isNull);
            expect(chip.deleteIcon, isNull);
            expect(chip.visualDensity, VisualDensity.compact);
            final finder = find.byKey(chip.key!);
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            final bounds = tester.getRect(finder);
            final wrapBounds = tester.getRect(collection);
            expect(bounds.left, greaterThanOrEqualTo(wrapBounds.left));
            expect(bounds.right, lessThanOrEqualTo(wrapBounds.right));
            final data = tester.getSemantics(finder).getSemanticsData();
            expect(data.flagsCollection.isButton, isFalse);
            expect(data.hasAction(SemanticsAction.tap), isFalse);
            await tester.tap(finder);
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsNothing);
            expect(
              app
                  .read(appRouterProvider)
                  .routeInformationProvider
                  .value
                  .uri
                  .path,
              '/profile',
            );
          }
          expect(profile.updateCount, 0);
          expect(profile.data.profile.selectedSkillIds, before);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'read-only empty competences retain localized copy without an empty Wrap',
    (tester) async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      addTearDown(auth.close);
      final anchor = FakeProfileAnchorGateway()
        ..readiness = ProfileAnchorReadiness.complete;
      final profile = FakeProfileGateway(
        data: _competenceLabelFixture(selected: {}),
      );
      final app = await _pumpApp(tester, auth, anchor, profile);
      app.read(appRouterProvider).go('/profile');
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byKey(const Key('profile-display-name'))),
      );
      expect(find.text(l10n.profileNoSkills), findsOneWidget);
      expect(find.byKey(const Key('profile-competence-labels')), findsNothing);
      expect(find.text('Music'), findsNothing);
      expect(find.text('Art & Creativity'), findsNothing);
      expect(profile.updateCount, 0);
    },
  );

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
    await tester.tap(find.byKey(const Key('nav-profile')));
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

    expect(find.byKey(const Key('nav-profile')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-profile')));
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
    await tester.tap(find.byKey(const Key('nav-profile')));
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
    await tester.tap(find.byKey(const Key('nav-profile')));
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
    await tester.tap(find.byKey(const Key('nav-profile')));
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
    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Casey'), findsOneWidget);

    auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'user-2')));
    await tester.pumpAndSettle();

    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text('Casey'), findsNothing);
    expect(profile.loadCount, 2);
  });
}

ProfileEditorData _competenceLabelFixture({Set<String>? selected}) {
  final base = profileFixture(complete: true);
  return ProfileEditorData(
    profile: OwnProfile(
      id: base.profile.id,
      displayName: base.profile.displayName,
      bio: base.profile.bio,
      updatedAt: base.profile.updatedAt,
      // Selection insertion order deliberately differs from catalog order.
      selectedSkillIds:
          selected ?? {'skill-musician', 'skill-photo', 'skill-mural'},
      visibility: base.profile.visibility,
    ),
    categories: [
      ProfileSkillCategory(
        id: 'category-art',
        slug: 'art-creativity',
        label: 'Art & Creativity',
        sortOrder: 1,
        skills: [
          base.categories.first.skills.first,
          const ProfileSkill(
            id: 'skill-photo',
            categoryId: 'category-art',
            slug: 'photography',
            label: 'Photography',
            sortOrder: 2,
          ),
          const ProfileSkill(
            id: 'skill-other',
            categoryId: 'category-art',
            slug: 'other',
            label: 'Unselected competence',
            sortOrder: 3,
          ),
        ],
      ),
      base.categories.last,
    ],
  );
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
        preacceptedPolicyFixture,
        // Feature fixtures begin after onboarding; startup tests own first-run.
        initialStartupPreferenceProvider.overrideWithValue(
          StartupPreference(completedVersion: productionTutorial.version),
        ),
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
  if (find.byKey(const Key('welcome-explore')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('welcome-explore')));
    await tester.pumpAndSettle();
  }
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
