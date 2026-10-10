import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/locations/presentation/location_preview_panel.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_planning_review.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_proposal.dart';

void main() {
  for (final language in ['en', 'it']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$language $scale public Idea card is truthful at 320dp', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final idea = ProposalSummary(
          id: 'idea-1',
          title: 'Garden together',
          summary: 'Plan a shared garden together.',
          definitionPhase: ProposalDefinitionPhase.idea,
          startsAt: null,
          endsAt: null,
          eventTimezone: null,
          countryCode: null,
          locality: null,
          administrativeArea: null,
          publicLocationLabel: null,
          status: null,
          skills: const [],
          capacity: projectCapacityFixture(registrationCapacity: null),
        );
        await tester.pumpWidget(
          ProviderScope(
            child: _app(
              language,
              scale,
              Scaffold(
                body: ListView(
                  children: [ProposalCard(proposal: idea, onTap: () {})],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('proposal-status-idea')), findsOneWidget);
        final place = find.text(
          language == 'it'
              ? 'Luogo da decidere insieme'
              : 'Place to decide together',
        );
        await tester.scrollUntilVisible(place, 160);
        expect(place, findsOneWidget);
        expect(find.text('Upcoming'), findsNothing);
        expect(find.text('Completed'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$language $scale planning cannot confirm missing fields', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final idea = ownProposalFixture(
          definitionPhase: ProposalDefinitionPhase.idea,
          lifecycle: ProposalLifecycle.published,
        );
        await tester.pumpWidget(
          _app(
            language,
            scale,
            Scaffold(
              body: ProposalPlanningReview(
                proposal: idea,
                requirements: const ProposalPromotionRequirements(
                  proposalId: 'proposal-1',
                  missingFields: [
                    'locality',
                    'starts_at',
                    'registration_capacity',
                    'creator_photo',
                  ],
                  canPromote: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('proposal-confirm-promotion')),
          findsNothing,
        );
        expect(find.textContaining('registration_capacity'), findsNothing);
        expect(tester.takeException(), isNull);
        expect(idea.isIdea, isTrue);
      });

      testWidgets(
        '$language $scale Idea detail keeps undecided place visible',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final summary = ProposalSummary(
            id: 'idea-1',
            title: 'Garden together',
            summary: 'Plan a shared garden together.',
            definitionPhase: ProposalDefinitionPhase.idea,
            startsAt: null,
            endsAt: null,
            eventTimezone: null,
            countryCode: null,
            locality: null,
            administrativeArea: null,
            publicLocationLabel: null,
            status: null,
            skills: const [],
            capacity: projectCapacityFixture(registrationCapacity: null),
          );
          final gateway = FakeProposalGateway()
            ..publicDetail = ProposalDetail(
              summary: summary,
              creatorProfileId: 'creator-1',
              creatorDisplayName: 'Casey',
              description: null,
              exactMeetingText: null,
              exactLocationRestricted: false,
            );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
              child: _app(
                language,
                scale,
                const ProposalDetailScreen(proposalId: 'idea-1'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(summary.summary), findsOneWidget);
          expect(
            find.byKey(const Key('tutorial-project-purpose')),
            findsOneWidget,
          );
          final place = find.text(
            language == 'it'
                ? 'Luogo da decidere insieme'
                : 'Place to decide together',
          );
          await tester.scrollUntilVisible(place, 160);
          expect(place, findsOneWidget);
          expect(find.byType(LocationPreviewPanel), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '$language $scale planning requires an explicit confirm or return',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final idea = ownProposalFixture(
            definitionPhase: ProposalDefinitionPhase.idea,
            lifecycle: ProposalLifecycle.published,
          );
          bool? decision;
          await tester.pumpWidget(
            _app(
              language,
              scale,
              Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      decision = await showDialog<bool>(
                        context: context,
                        builder: (_) => ProposalPlanningReview(
                          proposal: idea,
                          requirements: const ProposalPromotionRequirements(
                            proposalId: 'proposal-1',
                            missingFields: [],
                            canPromote: true,
                          ),
                        ),
                      );
                    },
                    child: const Text('Review'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Review'));
          await tester.pumpAndSettle();
          expect(decision, isNull);
          await tester.tap(
            find.text(
              language == 'it' ? 'Torna alle modifiche' : 'Back to editing',
            ),
          );
          await tester.pumpAndSettle();
          expect(decision, isFalse);
          expect(idea.isIdea, isTrue);
          await tester.tap(find.text('Review'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('proposal-confirm-promotion')));
          await tester.pumpAndSettle();
          expect(decision, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Widget _app(String language, double scale, Widget child) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, content) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: content!,
  ),
  home: child,
);
