import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/locations/presentation/location_fallbacks.dart';
import 'package:planets_mobile/features/locations/presentation/location_preview_panel.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_proposal.dart';
import '../proposals/presentation/proposal_draft_departure_test.dart' as draft;

void main() {
  testWidgets(
    'legacy manual draft saves without changing country, labels or instructions',
    (tester) async {
      final prior = proposalInputFixture();
      final legacy = ProposalInput(
        title: prior.title,
        summary: prior.summary,
        description: prior.description,
        startsAt: prior.startsAt,
        endsAt: prior.endsAt,
        eventTimezone: 'UTC',
        countryCode: 'GB',
        locality: 'Legacy town',
        administrativeArea: 'Legacy region',
        publicLocationLabel: 'User-authored broad area',
        exactMeetingText: 'Private side entrance, bell 4',
        exactLocationVisibility: ExactLocationVisibility.participants,
        skillImportanceById: prior.skillImportanceById,
        registrationCapacity: 20,
        countOrganizersTowardCapacity: false,
      );
      final app = await draft.pumpEditor(
        tester,
        proposal: ownProposalFixture(input: legacy),
      );
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Changed title only',
      );
      await draft.reveal(
        tester,
        find.byKey(const Key('proposal-public-location')),
      );
      expect(find.byKey(const Key('proposal-country')), findsNothing);
      await draft.reveal(tester, find.byKey(const Key('proposal-save-draft')));
      await tester.tap(find.byKey(const Key('proposal-save-draft')));
      await tester.pumpAndSettle();
      final saved = app.gateway.lastInput!;
      expect(saved.countryCode, 'GB');
      expect(saved.locality, 'Legacy town');
      expect(saved.administrativeArea, 'Legacy region');
      expect(saved.publicLocationLabel, legacy.publicLocationLabel);
      expect(saved.exactMeetingText, legacy.exactMeetingText);
      expect(
        saved.exactLocationVisibility,
        ExactLocationVisibility.participants,
      );
      expect(saved.eventTimezone, 'UTC');
      expect(
        app.gateway.calls.where((call) => call.startsWith('update:')).length,
        1,
      );
    },
  );

  testWidgets(
    'manual entry remains independently saveable with unconfigured search',
    (tester) async {
      final app = await draft.pumpEditor(tester);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Manual draft',
      );
      await draft.reveal(
        tester,
        find.byKey(const Key('proposal-optional-exact')),
      );
      await tester.tap(find.byKey(const Key('proposal-optional-exact')));
      await tester.pumpAndSettle();
      for (final entry in {
        'proposal-public-location': 'User-authored city centre',
        'proposal-exact-location': 'Side entrance, bell 4',
      }.entries) {
        final field = find.byKey(Key(entry.key));
        await draft.reveal(tester, field);
        await tester.enterText(field, entry.value);
      }
      await draft.reveal(
        tester,
        find.byKey(const Key('proposal-confirm-manual-city')),
      );
      await tester.tap(find.byKey(const Key('proposal-confirm-manual-city')));
      await tester.pumpAndSettle();
      await draft.reveal(tester, find.byKey(const Key('proposal-save-draft')));
      await tester.tap(find.byKey(const Key('proposal-save-draft')));
      await tester.pumpAndSettle();
      expect(
        app.gateway.lastInput?.publicLocationLabel,
        'User-authored city centre',
      );
      expect(app.gateway.lastInput?.exactMeetingText, 'Side entrance, bell 4');
      expect(
        app.gateway.lastInput?.exactLocationVisibility,
        ExactLocationVisibility.participants,
      );
      expect(app.gateway.calls.where((call) => call == 'create').length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'public detail panel offers only coarse text without a protected bitmap',
    (tester) async {
      final gateway = FakeProposalGateway()
        ..publicDetail = proposalDetailFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProposalDetailScreen(proposalId: 'proposal-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('location-preview-proposal-1')),
        250,
      );
      expect(
        find.text('Area information · map image unavailable'),
        findsNothing,
      );
      expect(find.textContaining('fountain'), findsNothing);
      expect(find.byType(LocationPreviewPanel), findsOneWidget);
      expect(find.byType(RawImage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['en', 'it']) {
    testWidgets(
      '$locale city-only public detail states absence without a hidden-place claim',
      (tester) async {
        final gateway = FakeProposalGateway()
          ..publicDetail = proposalDetailFixture(
            locality: 'Trento',
            publicLocationLabel: 'Trento',
            restricted: false,
            exactMeetingText: null,
          );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
            child: MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ProposalDetailScreen(proposalId: 'proposal-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final message = find.byKey(
          const Key('participation-public-meeting-proposal-1'),
        );
        await tester.scrollUntilVisible(message, 200);
        expect(
          tester.widget<Text>(message).data,
          locale == 'it'
              ? 'Le istruzioni per il luogo preciso non sono ancora state aggiunte.'
              : 'Precise meeting instructions have not been added yet.',
        );
        expect(
          find.byKey(const Key('participation-restricted-meeting-proposal-1')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('location-open-maps-proposal-1')),
          findsNothing,
        );
        expect(find.byType(RawImage), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final locale in ['en', 'it']) {
    testWidgets(
      '$locale fallback wraps with narrow, large-text keyboard in dark mode',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  ManualLocationNotice(),
                  UnavailableLocationMap(),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('location-manual-fallback')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('location-map-unavailable')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
