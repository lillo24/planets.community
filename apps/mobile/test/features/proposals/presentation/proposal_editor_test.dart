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

import 'package:planets_mobile/features/locations/data/item_location_gateway.dart';
import 'package:planets_mobile/features/locations/domain/item_location.dart';

import '../../../support/fake_location.dart';
import '../../../support/fake_auth.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_profile_photo.dart';

void main() {
  for (final language in ['en', 'it']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$language $scale publishes a public Idea without invented planning',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final gateway = await _pumpEditor(
            tester,
            null,
            locale: language,
            scale: scale,
          );
          await _tap(tester, find.byKey(const Key('proposal-mode-idea')));
          await _seek(tester, find.byKey(const Key('proposal-title')));
          await tester.enterText(
            find.byKey(const Key('proposal-title')),
            'Garden together',
          );
          await tester.pumpAndSettle();
          await _reveal(tester, find.byKey(const Key('proposal-summary')));
          await tester.enterText(
            find.byKey(const Key('proposal-summary')),
            'Let us plan a shared community garden.',
          );
          await _tap(tester, find.byKey(const Key('proposal-publish')));
          expect(gateway.calls, contains('publish-idea:new-draft'));
          expect(gateway.lastInput!.startsAt, isNull);
          expect(gateway.lastInput!.endsAt, isNull);
          expect(gateway.lastInput!.eventTimezone, isEmpty);
          expect(gateway.lastInput!.locality, isEmpty);
          expect(gateway.lastInput!.publicLocationLabel, isEmpty);
          expect(gateway.lastInput!.registrationCapacity, isNull);
          expect(gateway.lastInput!.description, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final language in ['en', 'it']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$language $scale city-only location is one field with optional exact details',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final gateway = await _pumpEditor(
            tester,
            proposalInputFixture(
              locality: 'Trento',
              publicLocationLabel: 'Trento',
              exactMeetingText: '',
            ),
            locale: language,
            scale: scale,
          );
          final city = find.byKey(const Key('proposal-public-location'));
          await _reveal(tester, city);
          expect(tester.widget<TextFormField>(city).controller!.text, 'Trento');
          expect(find.byKey(const Key('proposal-country')), findsNothing);
          expect(find.byKey(const Key('proposal-locality')), findsNothing);
          expect(
            find.byKey(const Key('proposal-administrative-area')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('proposal-exact-location')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('proposal-exact-visibility')),
            findsNothing,
          );
          await tester.enterText(city, 'Rovereto');
          await _tap(tester, find.byKey(const Key('proposal-optional-exact')));
          expect(
            find.byKey(const Key('proposal-exact-location')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('proposal-exact-visibility')),
            findsNothing,
          );
          final exact = find.byKey(const Key('proposal-exact-location'));
          await _reveal(tester, exact);
          await tester.enterText(exact, 'Side entrance');
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('proposal-exact-visibility')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.enterText(exact, '');
          await tester.pumpAndSettle();
          await _tap(tester, find.byKey(const Key('proposal-publish')));
          expect(gateway.calls, contains('publish:proposal-1'));
          expect(gateway.lastInput!.countryCode, 'IT');
          expect(gateway.lastInput!.locality, 'Rovereto');
          expect(gateway.lastInput!.publicLocationLabel, 'Rovereto');
          expect(gateway.lastInput!.exactMeetingText, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('new city-only draft derives Italy internally and saves once', (
    tester,
  ) async {
    final gateway = await _pumpEditor(tester, null);
    final city = find.byKey(const Key('proposal-public-location'));
    await _reveal(tester, city);
    await tester.enterText(city, 'Trento');
    await _tap(tester, find.byKey(const Key('proposal-save-draft')));
    expect(gateway.calls.where((call) => call == 'create'), hasLength(1));
    expect(gateway.lastInput!.countryCode, 'IT');
    expect(gateway.lastInput!.locality, 'Trento');
    expect(gateway.lastInput!.publicLocationLabel, 'Trento');
    expect(gateway.lastInput!.exactMeetingText, isEmpty);
  });

  testWidgets(
    'ordinary international edit retains country, timezone and precise content',
    (tester) async {
      final input = proposalInputFixture(
        countryCode: 'FR',
        locality: 'Lyon',
        publicLocationLabel: 'Lyon centre',
        eventTimezone: 'Europe/Paris',
      );
      final gateway = await _pumpEditor(tester, input);
      await _reveal(tester, find.byKey(const Key('proposal-exact-location')));
      expect(
        find.byKey(const Key('proposal-exact-visibility')),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('proposal-save-draft')));
      expect(gateway.lastInput!.countryCode, 'FR');
      expect(gateway.lastInput!.locality, 'Lyon');
      expect(gateway.lastInput!.publicLocationLabel, 'Lyon centre');
      expect(gateway.lastInput!.eventTimezone, 'Europe/Paris');
      expect(gateway.lastInput!.exactMeetingText, input.exactMeetingText);
      expect(gateway.lastInput!.administrativeArea, input.administrativeArea);
    },
  );

  testWidgets(
    'removing precise details clears protected selection and saves null text',
    (tester) async {
      final locations = FakeItemLocationGateway()
        ..value = const ItemLocation(3, exactPlace: syntheticExact);
      final gateway = await _pumpEditor(
        tester,
        proposalInputFixture(),
        locations: locations,
      );
      await _tap(tester, find.byKey(const Key('proposal-remove-exact')));
      expect(locations.value.exactPlace, isNull);
      expect(find.byKey(const Key('proposal-exact-location')), findsNothing);
      await _tap(tester, find.byKey(const Key('proposal-save-draft')));
      expect(gateway.lastInput!.exactMeetingText, isEmpty);
      expect(locations.mutations.single.$1.slot, 'exact');
      expect(locations.mutations.single.$3, 'clear');
    },
  );

  testWidgets(
    'lost exact-clear response retries once and finishes clearing instructions',
    (tester) async {
      final locations = FakeItemLocationGateway()
        ..value = const ItemLocation(3, exactPlace: syntheticExact)
        ..loseNextResponse = true;
      final gateway = await _pumpEditor(
        tester,
        proposalInputFixture(),
        locations: locations,
      );
      await _tap(tester, find.byKey(const Key('proposal-remove-exact')));
      expect(find.byKey(const Key('proposal-exact-location')), findsOneWidget);
      expect(locations.value.exactPlace, isNull);
      await _tap(tester, find.byKey(const Key('location-retry')));
      expect(find.byKey(const Key('proposal-exact-location')), findsNothing);
      expect(locations.accepted, hasLength(1));
      expect(locations.mutations.map((m) => m.$2).toSet(), hasLength(1));
      await _tap(tester, find.byKey(const Key('proposal-save-draft')));
      expect(gateway.lastInput!.exactMeetingText, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy undated draft preserves an unset zone while saving text',
    (tester) async {
      final proposal = ownProposalFixture(
        unsetTimezone: true,
        input: const ProposalInput(
          title: 'Legacy draft',
          summary: '',
          description: '',
          startsAt: null,
          endsAt: null,
          eventTimezone: '',
          countryCode: '',
          locality: '',
          administrativeArea: '',
          publicLocationLabel: '',
          exactMeetingText: '',
          exactLocationVisibility: ExactLocationVisibility.participants,
          skillImportanceById: {},
          registrationCapacity: null,
          countOrganizersTowardCapacity: false,
        ),
      );
      final gateway = await _pumpEditor(tester, null, proposal: proposal);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Legacy text changed',
      );
      await _tap(tester, find.byKey(const Key('proposal-save-draft')));
      expect(gateway.lastInput!.eventTimezone, '');
      expect(gateway.lastInput!.startsAt, isNull);
      expect(gateway.lastInput!.endsAt, isNull);
    },
  );

  testWidgets(
    'publish without photo opens trust gate and preserves the draft on return',
    (tester) async {
      final gateway = await _pumpEditor(tester, null, hasPhoto: false);
      await _tap(tester, find.byKey(const Key('proposal-fill-sample')));
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
      await tester.scrollUntilVisible(
        find.byKey(const Key('proposal-title')),
        -500,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
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

  testWidgets('organizer capacity setting defaults off and persists edits', (
    tester,
  ) async {
    final gateway = await _pumpEditor(tester, proposalInputFixture());
    final toggle = find.byKey(const Key('proposal-count-organizers-capacity'));
    await _reveal(tester, toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    await _tap(tester, find.byKey(const Key('proposal-save-draft')));
    expect(gateway.lastInput?.countOrganizersTowardCapacity, isTrue);
  });

  testWidgets('legacy timezone hint preserves stored instants on save', (
    tester,
  ) async {
    final input = proposalInputFixture(eventTimezone: 'UTC');
    final gateway = await _pumpEditor(tester, input);
    expect(find.byKey(const Key('proposal-timezone')), findsNothing);
    await _seek(tester, find.byKey(const Key('proposal-legacy-zone')));
    expect(find.text('Times shown in UTC'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('proposal-save-draft')));
    expect(gateway.lastInput?.eventTimezone, 'UTC');
    expect(gateway.lastInput?.startsAt, input.startsAt);
    expect(gateway.lastInput?.endsAt, input.endsAt);
  });

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
    await _seek(tester, fill);
    expect(fill, findsOneWidget);
    await tester.tap(fill);
    await tester.pumpAndSettle();
    expect(gateway.calls, isNot(contains('create')));

    await _seek(tester, find.byKey(const Key('proposal-title')));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('proposal-title')))
          .controller!
          .text,
      'Community garden build day',
    );
    await _reveal(tester, find.byKey(const Key('proposal-pick-start')));
    expect(find.textContaining('2:00'), findsOneWidget);
    expect(find.textContaining('5:00'), findsOneWidget);
    await _reveal(tester, find.byKey(const Key('proposal-skill-mural')));
    expect(
      tester
          .widget<DropdownButton<ProposalSkillImportance>>(
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
        matching: find.textContaining('Where will it take place?'),
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

  testWidgets('published proposal exposes Save changes without Publish', (
    tester,
  ) async {
    final proposal = ownProposalFixture(lifecycle: ProposalLifecycle.published);
    final gateway = await _pumpEditor(tester, null, proposal: proposal);

    expect(find.byKey(const Key('proposal-save-draft')), findsNothing);
    expect(find.byKey(const Key('proposal-publish')), findsNothing);
    await _tap(tester, find.byKey(const Key('proposal-save-changes')));

    expect(gateway.calls, contains('update:proposal-1'));
    expect(gateway.calls, isNot(contains('publish:proposal-1')));
    expect(find.text('Saved proposal'), findsOneWidget);
  });

  testWidgets('started proposal is read-only but remains cancellable', (
    tester,
  ) async {
    final proposal = ownProposalFixture(
      lifecycle: ProposalLifecycle.published,
      status: ProposalStatus.happening,
      startsAt: DateTime.utc(2026, 9, 2),
      endsAt: DateTime.utc(2026, 9, 4),
    );
    final gateway = await _pumpEditor(tester, null, proposal: proposal);

    expect(find.byKey(const Key('proposal-editor-read-only')), findsOneWidget);
    expect(find.byKey(const Key('proposal-save-changes')), findsNothing);
    expect(find.byKey(const Key('proposal-publish')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('proposal-title')))
          .enabled,
      isFalse,
    );
    await _tap(tester, find.byKey(const Key('proposal-editor-cancel')));
    expect(find.text('Cancel this proposal?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel proposal'));
    await tester.pumpAndSettle();

    expect(gateway.calls, contains('cancel:proposal-1'));
    await _seek(tester, find.byKey(const Key('proposal-editor-read-only')));
    expect(
      find.textContaining('cancelled proposal is read-only'),
      findsOneWidget,
    );
  });

  testWidgets('terminal proposal exposes no structural mutation controls', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      null,
      proposal: ownProposalFixture(
        lifecycle: ProposalLifecycle.published,
        status: ProposalStatus.completed,
        startsAt: DateTime.utc(2026, 9, 1),
        endsAt: DateTime.utc(2026, 9, 2),
      ),
    );

    expect(find.byKey(const Key('proposal-editor-read-only')), findsOneWidget);
    expect(find.byKey(const Key('proposal-save-changes')), findsNothing);
    expect(find.byKey(const Key('proposal-publish')), findsNothing);
    expect(find.byKey(const Key('proposal-editor-cancel')), findsNothing);
    expect(find.byKey(const Key('proposal-manage-resources')), findsNothing);
  });

  testWidgets('forbidden published save removes structural controls', (
    tester,
  ) async {
    final gateway = await _pumpEditor(
      tester,
      null,
      proposal: ownProposalFixture(lifecycle: ProposalLifecycle.published),
    );
    gateway.mutationError = const PostgrestException(
      message: 'private structural denial',
      code: '42501',
    );

    await _tap(tester, find.byKey(const Key('proposal-save-changes')));

    expect(find.textContaining("couldn't complete"), findsOneWidget);
    expect(find.byKey(const Key('proposal-save-changes')), findsNothing);
    expect(find.byKey(const Key('proposal-editor-cancel')), findsNothing);
  });
}

Future<FakeProposalGateway> _pumpEditor(
  WidgetTester tester,
  ProposalInput? input, {
  bool hasPhoto = true,
  OwnProposal? proposal,
  ItemLocationGateway? locations,
  String locale = 'en',
  double scale = 1,
}) async {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final gateway = FakeProposalGateway()
    ..ownItems = proposal != null
        ? [proposal]
        : input == null
        ? []
        : [ownProposalFixture(input: input)];
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
      if (locations != null)
        itemLocationGatewayProvider.overrideWithValue(locations),
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
          proposalId: proposal?.id ?? (input == null ? null : 'proposal-1'),
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
        locale: Locale(locale),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
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
