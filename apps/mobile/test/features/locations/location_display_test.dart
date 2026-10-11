import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/locations/presentation/location_attribution.dart';
import 'package:planets_mobile/features/locations/presentation/public_location_label.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/presentation/project_participation_section.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/recurring_activity_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_participation.dart';
import '../../support/fake_project_delegates.dart';
import '../../support/fake_proposal.dart';
import '../../support/fake_recurring_activity.dart';

Widget shell(String language, Widget body, {ProviderContainer? container}) {
  final app = MaterialApp(
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
      child: child!,
    ),
    home: Scaffold(body: SingleChildScrollView(child: body)),
  );
  return container == null
      ? ProviderScope(child: app)
      : UncontrolledProviderScope(container: container, child: app);
}

void main() {
  test(
    'compact labels prefer public structure and preserve ambiguous comma names',
    () {
      expect(
        shortPublicLocationLabel(' Trento ', 'Trento, Provincia, Italia'),
        'Trento',
      );
      expect(
        shortPublicLocationLabel('City, District', 'Other'),
        'City, District',
      );
      expect(
        shortPublicLocationLabel(' ', ' Legacy town, Region '),
        'Legacy town, Region',
      );
      expect(shortPublicLocationLabel(null, null), isNull);
      expect(shortPublicLocationLabel('', '  '), isNull);
      for (final suffix in [
        'Trento, Provincia di Trento, Trentino – Alto Adige/Südtirol, Italy',
        'Trento, Provincia autonoma di Trento, Italia',
      ]) {
        expect(shortPublicLocationLabel(null, suffix), 'Trento');
        expect(shortPublicLocationLabel(null, suffix, manual: true), suffix);
      }
      expect(
        shortPublicLocationLabel('', 'Rovereto, Trentino-Alto Adige, Italia'),
        'Rovereto',
      );
      for (final text in [
        'Washington, D.C.',
        'Boca Chica, Santo Domingo',
        'Via Roma, Provincia di Trento, Italia',
      ]) {
        expect(shortPublicLocationLabel(null, text), text);
      }
    },
  );
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language Project and Tavolo cards prefer locality with safe legacy fallbacks',
      (t) async {
        t.view.physicalSize = const Size(320, 740);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        for (final sample in [
          ('Trento', 'Trento, Provincia autonoma di Trento, Italia', 'Trento'),
          ('Rovereto', 'Rovereto, Trentino-Alto Adige, Italia', 'Rovereto'),
          (
            '',
            'Trento, Provincia di Trento, Trentino – Alto Adige/Südtirol, Italy',
            'Trento',
          ),
          ('', 'Legacy town, Region, Italia', 'Legacy town, Region, Italia'),
          (
            '',
            '',
            language == 'it' ? 'Luogo da decidere' : 'Place to be decided',
          ),
        ]) {
          for (final recurring in [false, true]) {
            await t.pumpWidget(
              shell(
                language,
                recurring
                    ? RecurringActivityCard(
                        activity: publicRecurringSummaryFixture(
                          locality: sample.$1,
                          publicLocationLabel: sample.$2,
                        ),
                        now: DateTime.utc(2026, 9, 7),
                        onTap: () {},
                      )
                    : ProposalCard(
                        proposal: proposalSummaryFixture(
                          locality: sample.$1.isEmpty ? null : sample.$1,
                          publicLocationLabel: sample.$2.isEmpty
                              ? null
                              : sample.$2,
                          definitionPhase: sample.$2.isEmpty
                              ? ProposalDefinitionPhase.idea
                              : ProposalDefinitionPhase.defined,
                        ),
                        onTap: () {},
                      ),
              ),
            );
            await t.pumpAndSettle();
            final l10n = AppLocalizations.of(t.element(find.byType(Scaffold)));
            expect(
              find.text(
                sample.$2.isEmpty ? l10n.proposalPlaceUndecided : sample.$3,
              ),
              findsOneWidget,
            );
            if (sample.$1.isNotEmpty) {
              expect(find.text(sample.$2), findsNothing);
            }
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox());
          }
        }
      },
    );
    for (final kind in ProjectKind.values) {
      testWidgets(
        '$language $kind private instructions render only when authorized and nonempty',
        (t) async {
          for (final instructions in [
            null,
            '',
            '  ',
            'PRIVATE east gate instructions',
          ]) {
            final gateway = FakeParticipationGateway()
              ..meetingDetails = meetingDetailsFixture(
                projectId: 'item',
                projectKind: kind,
                exactMeetingText: instructions,
              );
            final c = ProviderContainer(
              overrides: [
                participationGatewayProvider.overrideWithValue(gateway),
                projectDelegateGatewayProvider.overrideWithValue(
                  FakeProjectDelegateGateway()
                    ..role = ProjectManagementRole.creator,
                ),
              ],
            );
            final auth = c.read(authSessionProvider.notifier);
            auth.markProfileReady(const AuthIdentity(id: 'creator'));
            await t.pumpWidget(
              shell(
                language,
                ProjectParticipationSection(
                  projectId: 'item',
                  projectKind: kind,
                  creatorProfileId: 'creator',
                  acceptsNewRequests: true,
                  publicLocationLines: const ['Public city'],
                  publicExactMeetingText: null,
                  exactLocationRestricted: true,
                  capacity: capacityFixture(),
                ),
                container: c,
              ),
            );
            await t.pumpAndSettle();
            expect(
              find.byKey(const Key('participation-protected-meeting-item')),
              instructions?.trim().isNotEmpty == true
                  ? findsOneWidget
                  : findsNothing,
            );
            expect(
              find.byKey(const Key('participation-restricted-meeting-item')),
              findsNothing,
            );
            if (instructions?.trim().isNotEmpty == true) {
              expect(find.text(instructions!), findsOneWidget);
            }
            auth.markSignedOut();
            await t.pumpAndSettle();
            expect(find.text('PRIVATE east gate instructions'), findsNothing);
            expect(
              find.byKey(const Key('participation-protected-meeting-item')),
              findsNothing,
            );
            expect(
              find.byKey(const Key('participation-restricted-meeting-item')),
              findsOneWidget,
            );
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox());
            c.dispose();
          }
        },
      );
      testWidgets(
        '$language $kind legacy detail omits empty instructions and preserves useful restricted notice',
        (t) async {
          for (final instructions in [
            null,
            '',
            '  ',
            'Use the east entrance.',
          ]) {
            await t.pumpWidget(
              shell(
                language,
                ProjectParticipationSection(
                  projectId: 'item',
                  projectKind: kind,
                  creatorProfileId: 'creator',
                  acceptsNewRequests: true,
                  publicLocationLines: const [
                    'Trento, Provincia autonoma di Trento, Italia',
                  ],
                  publicExactMeetingText: instructions,
                  exactLocationRestricted: false,
                  capacity: capacityFixture(),
                ),
              ),
            );
            await t.pumpAndSettle();
            expect(
              find.text('Trento, Provincia autonoma di Trento, Italia'),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('participation-public-meeting-item')),
              instructions?.trim().isNotEmpty == true
                  ? findsOneWidget
                  : findsNothing,
            );
            expect(
              find.byKey(const Key('participation-restricted-meeting-item')),
              findsNothing,
            );
            expect(t.takeException(), isNull);
          }
          await t.pumpWidget(
            shell(
              language,
              ProjectParticipationSection(
                projectId: 'item',
                projectKind: kind,
                creatorProfileId: 'creator',
                acceptsNewRequests: true,
                publicLocationLines: const ['Public city'],
                publicExactMeetingText: 'SECRET private arrival instructions',
                exactLocationRestricted: true,
                capacity: capacityFixture(),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(
            find.text('SECRET private arrival instructions'),
            findsNothing,
          );
          expect(
            find.byKey(const Key('participation-restricted-meeting-item')),
            findsOneWidget,
          );
          await t.pumpWidget(const SizedBox());
        },
      );
    }
    testWidgets(
      '$language compatibility Project location keeps full label and credits without empty instructions',
      (t) async {
        for (final instructions in [null, ' ', 'Use the east entrance.']) {
          await t.pumpWidget(
            shell(
              language,
              ProposalLocation(
                detail: proposalDetailFixture(
                  publicLocationLabel:
                      'Trento, Provincia autonoma di Trento, Italia',
                  restricted: false,
                  exactMeetingText: instructions,
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(
            find.text('Trento, Provincia autonoma di Trento, Italia'),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('proposal-location-public')),
            instructions?.trim().isNotEmpty == true
                ? findsOneWidget
                : findsNothing,
          );
          // Stored text has no durable provenance; absence of a map is not proof.
          expect(find.byType(LocationAttribution), findsOneWidget);
        }
        await t.pumpWidget(
          shell(
            language,
            ProposalLocation(
              detail: proposalDetailFixture(
                restricted: true,
                exactMeetingText: 'SECRET',
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('SECRET'), findsNothing);
        expect(
          find.byKey(const Key('proposal-location-restricted')),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
