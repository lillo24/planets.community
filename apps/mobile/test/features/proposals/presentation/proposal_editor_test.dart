import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_proposal.dart';

void main() {
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

      // Saving invalid input rebuilds the form from provider state as well.
      await _tap(tester, find.byKey(const Key('proposal-save-draft')));
      expect(
        find.byKey(const Key('proposal-editor-safe-error')),
        findsOneWidget,
      );
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
  ProposalInput input,
) async {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final gateway = FakeProposalGateway()
    ..ownItems = [ownProposalFixture(input: input)];
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      proposalGatewayProvider.overrideWithValue(gateway),
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
        builder: (_, _) => const ProposalEditorScreen(proposalId: 'proposal-1'),
      ),
      GoRoute(
        path: '/proposals/mine',
        builder: (_, _) => const Scaffold(body: Text('Saved proposal')),
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
