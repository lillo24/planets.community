import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/core/widgets/requested_badge.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_cover_media.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/rendered_evidence.dart';

void main() {
  late Uint8List cover;
  setUpAll(() async {
    cover = await File('assets/tutorial/garden-tools.webp').readAsBytes();
    await RenderedEvidence.loadFonts(force: true);
  });
  for (final locale in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 360.0]) {
        for (final scale in [1.0, 2.0]) {
          for (final requested in [false, true]) {
            for (final media in ['cover', 'none', 'failed']) {
              for (final idea in [false, true]) {
                testWidgets(
                  'A03 $locale dark=$dark width=$width scale=$scale requested=$requested $media idea=$idea',
                  (tester) async {
                    await tester.binding.setSurfaceSize(Size(width, 2000));
                    addTearDown(() => tester.binding.setSurfaceSize(null));
                    final semantics = tester.ensureSemantics();
                    try {
                      var taps = 0;
                      final proposal = _proposal(locale, idea, media);
                      final gateway = _CoverGateway(fail: media == 'failed')
                        ..downloadResult = cover;
                      await tester.pumpWidget(
                        RenderedEvidence.wrap(
                          ProviderScope(
                            overrides: [
                              coverMediaGatewayProvider.overrideWithValue(
                                gateway,
                              ),
                            ],
                            child: MaterialApp(
                              debugShowCheckedModeBanner: false,
                              theme: dark ? AppTheme.dark : AppTheme.light,
                              locale: Locale(locale),
                              localizationsDelegates:
                                  AppLocalizations.localizationsDelegates,
                              supportedLocales:
                                  AppLocalizations.supportedLocales,
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  textScaler: TextScaler.linear(scale),
                                ),
                                child: child!,
                              ),
                              home: Scaffold(
                                body: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: ProposalCard(
                                      proposal: proposal,
                                      isRequested: requested,
                                      onTap: () => taps++,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                      await tester.pumpAndSettle();
                      expect(tester.takeException(), isNull);
                      final coverFinder = find.byKey(
                        const Key('proposal-cover-proposal-1'),
                      );
                      final coverRect = tester.getRect(coverFinder);
                      expect(
                        coverRect.width / coverRect.height,
                        closeTo(1.5, .001),
                      );
                      final ribbon = find.byKey(
                        const Key('proposal-idea-ribbon-proposal-1'),
                      );
                      expect(ribbon, idea ? findsOneWidget : findsNothing);
                      expect(
                        find.byType(ProposalStatusBadge),
                        idea ? findsNothing : findsOneWidget,
                      );
                      if (idea) {
                        expect(
                          tester.getSemantics(ribbon).label,
                          locale == 'it'
                              ? 'Idea. In definizione'
                              : 'Idea. In definition',
                        );
                        expect(find.text('Idea'), findsOneWidget);
                        expect(
                          find.byKey(const Key('proposal-status-idea')),
                          findsNothing,
                        );
                      }
                      if (requested) {
                        final badge = find.byType(RequestedBadge);
                        final badgeRect = tester.getRect(badge);
                        expect(
                          badgeRect.left,
                          greaterThanOrEqualTo(coverRect.left),
                        );
                        expect(
                          badgeRect.right,
                          lessThanOrEqualTo(coverRect.right),
                        );
                        expect(
                          badgeRect.bottom,
                          lessThanOrEqualTo(coverRect.bottom),
                        );
                        if (idea) {
                          expect(
                            badgeRect.overlaps(tester.getRect(ribbon)),
                            isFalse,
                          );
                        }
                        await tester.tapAt(tester.getCenter(badge));
                      } else {
                        await tester.tapAt(coverRect.center);
                      }
                      expect(taps, 1);
                      final skill = find.text(
                        locale == 'it'
                            ? 'Necessaria: Mural painting'
                            : 'Required: Mural painting',
                      );
                      expect(skill, findsOneWidget);
                      expect(
                        tester
                            .renderObject<RenderParagraph>(skill)
                            .didExceedMaxLines,
                        isFalse,
                      );
                      if (_capture(
                        locale,
                        dark,
                        width,
                        scale,
                        requested,
                        media,
                        idea,
                      )) {
                        await RenderedEvidence.capture(
                          tester,
                          'a03-$locale-${dark ? 'dark' : 'light'}-${width.toInt()}-${scale.toInt()}x-$media-${idea ? 'idea' : 'defined'}',
                        );
                      }
                      expect(tester.takeException(), isNull);
                    } finally {
                      semantics.dispose();
                    }
                  },
                );
              }
            }
          }
        }
      }
    }
  }
  for (final status in ProposalStatus.values) {
    testWidgets('A03 retains defined ${status.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProviderScope(
                child: ProposalCard(
                  proposal: proposalSummaryFixture(status: status),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('proposal-status-${status.wireValue}')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('proposal-idea-ribbon-proposal-1')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

bool _capture(
  String locale,
  bool dark,
  double width,
  double scale,
  bool requested,
  String media,
  bool idea,
) =>
    requested &&
    ((idea && media == 'cover' && width == 360 && scale == 1 && !dark) ||
        (idea &&
            media == 'cover' &&
            locale == 'it' &&
            width == 320 &&
            scale == 2 &&
            dark) ||
        (idea &&
            media == 'none' &&
            locale == 'en' &&
            width == 320 &&
            scale == 2 &&
            !dark) ||
        (idea &&
            media == 'failed' &&
            locale == 'en' &&
            width == 360 &&
            scale == 1 &&
            dark) ||
        (!idea &&
            media == 'cover' &&
            locale == 'it' &&
            width == 360 &&
            scale == 1 &&
            !dark));

ProposalSummary _proposal(String locale, bool idea, String media) {
  final base = proposalSummaryFixture();
  return ProposalSummary(
    id: base.id,
    title: locale == 'it'
        ? 'Organizziamo insieme una giornata di giardinaggio e arte pubblica per il nostro quartiere'
        : 'Plan a shared garden and public art day together in our fictional neighbourhood',
    summary: base.summary,
    definitionPhase: idea
        ? ProposalDefinitionPhase.idea
        : ProposalDefinitionPhase.defined,
    startsAt: idea ? null : base.startsAt,
    endsAt: idea ? null : base.endsAt,
    eventTimezone: idea ? null : base.eventTimezone,
    countryCode: idea ? null : base.countryCode,
    locality: idea ? null : base.locality,
    administrativeArea: idea ? null : base.administrativeArea,
    publicLocationLabel: idea ? null : base.publicLocationLabel,
    status: idea ? null : base.status,
    skills: base.skills,
    capacity: projectCapacityFixture(registrationCapacity: idea ? null : 20),
    coverObjectPath: media == 'none' ? null : 'licensed-garden.webp',
  );
}

class _CoverGateway extends FakeCoverMediaGateway {
  _CoverGateway({required this.fail});
  final bool fail;
  @override
  Future<Uint8List> downloadCover(String objectPath) async {
    if (fail) throw StateError('Synthetic cover failure');
    return super.downloadCover(objectPath);
  }
}
