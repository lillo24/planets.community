import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';
import 'package:planets_mobile/features/profile/presentation/profile_edit_screen.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_profile_photo.dart';

void main() {
  testWidgets(
    'publish without photo opens trust gate and preserves the draft on return',
    (tester) async {
      final gateway = await _pumpEditor(tester, null, hasPhoto: false);
      await tester.tap(find.byKey(const Key('proposal-fill-sample')));
      await tester.pumpAndSettle();

      await _tap(tester, find.byKey(const Key('proposal-publish')));
      expect(find.byKey(const Key('profile-photo-trust-gate')), findsOneWidget);
      expect(gateway.calls, isNot(contains('create')));

      await tester.tap(find.byKey(const Key('profile-photo-trust-add')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(ProfileEditScreen))).pop();
      await tester.pumpAndSettle();
      expect(
        find.byType(ProposalEditorScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('proposal-publish'), skipOffstage: false),
        findsOneWidget,
      );
      for (var attempt = 0; attempt < 4; attempt++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, 600));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('proposal-title')))
            .controller!
            .text,
        'Community garden build day',
      );
      expect(gateway.calls, isNot(contains('create')));
    },
  );

  testWidgets('stale backend photo failure opens the same trust gate', (
    tester,
  ) async {
    final gateway = await _pumpEditor(tester, proposalInputFixture());
    gateway.error = const PostgrestException(
      message: 'Photo required',
      code: 'PT422',
    );

    await _tap(tester, find.byKey(const Key('proposal-publish')));

    expect(find.byKey(const Key('profile-photo-trust-gate')), findsOneWidget);
    expect(
      find.text('A profile photo is required to publish a personal activity.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'invalid timezone survives rebuilds without changing stored dates',
    (tester) async {
      final input = proposalInputFixture();
      final gateway = await _pumpEditor(tester, input);
      final timezone = find.byKey(const Key('proposal-timezone'));
      await _reveal(tester, timezone);
      await tester.enterText(timezone, 'Not/A_Zone');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _tap(tester, find.byKey(const Key('proposal-pick-start')));
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.textContaining('valid IANA time zone'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Saving invalid input reports the exact field and never reaches the gateway.
      await _tap(tester, find.byKey(const Key('proposal-save-draft')));
      expect(
        find.byKey(const Key('proposal-validation-summary')),
        findsOneWidget,
      );
      expect(find.textContaining('Time zone'), findsWidgets);
      expect(gateway.calls, isNot(contains('update:proposal-1')));
      expect(tester.takeException(), isNull);

      await _reveal(tester, timezone, delta: -250);
      await tester.enterText(timezone, 'UTC');
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(timezone).controller!.text, 'UTC');
      await _reveal(tester, find.byKey(const Key('proposal-pick-start')));
      expect(find.text('Starts: 2026-09-10 10:00'), findsOneWidget);
      expect(find.text('Ends: 2026-09-10 12:00'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('proposal-save-draft')));
      expect(gateway.lastInput?.startsAt, input.startsAt);
      expect(gateway.lastInput?.endsAt, input.endsAt);
      expect(gateway.lastInput?.eventTimezone, 'UTC');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stored draft with an unknown timezone renders safely', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      proposalInputFixture(eventTimezone: 'Not/A_Zone'),
    );
    await _reveal(tester, find.byKey(const Key('proposal-pick-start')));
    expect(find.textContaining('valid IANA time zone'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('demo sample fills every publish field without auto-submitting', (
    tester,
  ) async {
    final gateway = await _pumpEditor(tester, null);
    final fill = find.byKey(const Key('proposal-fill-sample'));
    expect(fill, findsOneWidget);
    await tester.tap(fill);
    await tester.pumpAndSettle();
    expect(gateway.calls, isNot(contains('create')));

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('proposal-title')))
          .controller!
          .text,
      'Community garden build day',
    );
    await _reveal(tester, find.byKey(const Key('proposal-pick-start')));
    expect(find.text('Starts: 2026-09-10 00:00'), findsOneWidget);
    expect(find.text('Ends: 2026-09-10 03:00'), findsOneWidget);
    await _reveal(tester, find.byKey(const Key('proposal-skill-mural')));
    expect(
      tester
          .widget<DropdownButton<ProposalSkillImportance?>>(
            find.byKey(const Key('proposal-skill-mural')),
          )
          .value,
      ProposalSkillImportance.required,
    );

    await _tap(tester, find.byKey(const Key('proposal-publish')));
    expect(gateway.calls, containsAllInOrder(['create', 'publish:new-draft']));
    expect(gateway.lastInput?.countryCode, 'IT');
    expect(gateway.lastInput?.startsAt, DateTime.utc(2026, 9, 10));
    expect(find.text('Saved proposal'), findsOneWidget);
  });

  testWidgets('publish names missing fields and shows inline red validation', (
    tester,
  ) async {
    final gateway = await _pumpEditor(tester, null);
    await _tap(tester, find.byKey(const Key('proposal-publish')));

    final summary = find.byKey(const Key('proposal-validation-summary'));
    expect(summary, findsOneWidget);
    expect(
      find.descendant(of: summary, matching: find.textContaining('Title')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.textContaining('Starts')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summary,
        matching: find.textContaining('Country code'),
      ),
      findsOneWidget,
    );
    expect(find.text('This field is required to publish.'), findsWidgets);
    expect(gateway.calls, isNot(contains('create')));

    await _seek(tester, find.byKey(const Key('proposal-start-field')));
    expect(find.text('Choose a start date and time.'), findsOneWidget);
    expect(find.text('Choose an end date and time.'), findsOneWidget);

    await _reveal(tester, find.byKey(const Key('proposal-title')), delta: -250);
    await tester.enterText(find.byKey(const Key('proposal-title')), 'X');
    await tester.pump();
    expect(find.text('Enter at least 2 characters.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('proposal-title')),
      'Valid title',
    );
    await tester.pump();
    expect(
      find.descendant(of: summary, matching: find.textContaining('Title')),
      findsNothing,
    );
  });

  // The two event zones are 24 hours apart: at least one differs from any
  // device timezone, and their picker dates must differ despite equal hours.
  for (final (zone, day) in [
    ('Pacific/Kiritimati', 11),
    ('Pacific/Honolulu', 10),
  ]) {
    testWidgets('$zone pickers use event wall time and preserve UTC instants', (
      tester,
    ) async {
      final input = proposalInputFixture(
        startsAt: DateTime.utc(2026, 9, 10, 12, 45),
        endsAt: DateTime.utc(2026, 9, 10, 13, 50),
        eventTimezone: zone,
      );
      final gateway = await _pumpEditor(tester, input);
      for (final (key, hour, minute) in [
        ('proposal-pick-start', 2, 45),
        ('proposal-pick-end', 3, 50),
      ]) {
        await _tap(tester, find.byKey(Key(key)));
        final datePicker = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        expect(datePicker.initialDate, DateTime(2026, 9, day));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        final timePicker = tester.widget<TimePickerDialog>(
          find.byType(TimePickerDialog),
        );
        expect(timePicker.initialTime, TimeOfDay(hour: hour, minute: minute));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      await _tap(tester, find.byKey(const Key('proposal-save-draft')));
      expect(gateway.lastInput?.startsAt, input.startsAt);
      expect(gateway.lastInput?.endsAt, input.endsAt);
      expect(gateway.lastInput?.eventTimezone, zone);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<FakeProposalGateway> _pumpEditor(
  WidgetTester tester,
  ProposalInput? input, {
  bool hasPhoto = true,
}) async {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final gateway = FakeProposalGateway()
    ..ownItems = input == null ? [] : [ownProposalFixture(input: input)];
  final photoGateway = FakeProfilePhotoGateway();
  if (hasPhoto) photoGateway.photo = profilePhotoFixture();
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
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      proposalGatewayProvider.overrideWithValue(gateway),
      profilePhotoGatewayProvider.overrideWithValue(photoGateway),
      proposalClockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 3)),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(
        path: '/edit',
        builder: (_, _) => ProposalEditorScreen(
          proposalId: input == null ? null : 'proposal-1',
        ),
      ),
      GoRoute(
        path: '/proposals/mine',
        builder: (_, _) => const Scaffold(body: Text('Saved proposal')),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const Scaffold(body: Text('Photo management')),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(container.dispose);
  addTearDown(auth.close);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return gateway;
}

Future<void> _reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 250,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _seek(WidgetTester tester, Finder finder) async {
  final scrollable = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  scrollable.position.jumpTo(0);
  await tester.pump();
  for (var attempt = 0; finder.evaluate().isEmpty && attempt < 20; attempt++) {
    scrollable.position.jumpTo(
      (scrollable.position.pixels + 200).clamp(
        0,
        scrollable.position.maxScrollExtent,
      ),
    );
    await tester.pump();
  }
  expect(finder, findsOneWidget);
  await Scrollable.ensureVisible(finder.evaluate().single);
  await tester.pumpAndSettle();
}
