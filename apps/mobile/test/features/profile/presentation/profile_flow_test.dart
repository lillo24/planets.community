import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/domain/profile_models.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_profile_photo.dart';

void main() {
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
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('profile-skill-mural-painting')),
          )
          .value,
      isTrue,
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

    expect(find.text('Art & Creativity'), findsOneWidget);
    expect(
      find.byKey(const Key('profile-save-button')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Music'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      '  Casey  ',
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('profile-skill-mural-painting')),
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
    final musician = find.byKey(const Key('profile-skill-musician'));
    expect(tester.widget<CheckboxListTile>(musician).value, isTrue);
    await _tapVisible(
      tester,
      find.descendant(of: musician, matching: find.byType(Checkbox)),
    );
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(musician).value, isFalse);
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

Future<void> _pumpApp(
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
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(SingleChildScrollView),
    const Offset(0, -400),
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
  await tester.pumpAndSettle();
}
