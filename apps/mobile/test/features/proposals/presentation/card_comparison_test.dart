import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/core/widgets/requested_badge.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../../test_support/proposal_card_comparison.dart';
import '../../../support/fake_cover_media.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/rendered_evidence.dart';

const _cases = [
  'idea',
  'requested',
  'popular',
  'all',
  'defined',
  'no-cover',
  'failed-cover',
];
const _longTitle =
    'Organizziamo insieme una giornata di giardinaggio e arte pubblica per rendere più accogliente il cortile del nostro quartiere';

ProposalSummary _proposal(String scenario) {
  final base = proposalSummaryFixture();
  final idea = scenario != 'defined';
  return ProposalSummary(
    id: base.id,
    title: scenario == 'no-cover' || scenario == 'all'
        ? _longTitle
        : 'Garden together · Insieme in giardino',
    summary: base.summary,
    startsAt: idea ? null : base.startsAt,
    endsAt: idea ? null : base.endsAt,
    eventTimezone: idea ? null : base.eventTimezone,
    countryCode: idea ? null : base.countryCode,
    locality: idea ? null : base.locality,
    administrativeArea: idea ? null : base.administrativeArea,
    publicLocationLabel: idea ? null : base.publicLocationLabel,
    status: idea ? null : base.status,
    definitionPhase: idea
        ? ProposalDefinitionPhase.idea
        : ProposalDefinitionPhase.defined,
    skills: base.skills,
    capacity: projectCapacityFixture(registrationCapacity: idea ? null : 20),
    coverObjectPath: scenario == 'no-cover' ? null : 'licensed-garden.webp',
  );
}

bool _requested(String scenario) => [
  'requested',
  'all',
  'defined',
  'no-cover',
  'failed-cover',
].contains(scenario);
bool _popular(String scenario) =>
    ['popular', 'all', 'no-cover', 'failed-cover'].contains(scenario);

void main() {
  late Uint8List cover;
  setUpAll(() async {
    cover = await File('assets/tutorial/garden-tools.webp').readAsBytes();
    // Compare real app typography in CI too, not Ahem's block glyph metrics.
    await RenderedEvidence.loadFonts(force: true);
  });
  for (final locale in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 360.0]) {
        for (final scale in [1.0, 2.0]) {
          for (final scenario in _cases) {
            for (final composition in CardComposition.values) {
              testWidgets(
                'A02 $locale dark=$dark width=$width scale=$scale $scenario ${composition.name}',
                (tester) async {
                  await tester.binding.setSurfaceSize(Size(width, 1800));
                  addTearDown(() => tester.binding.setSurfaceSize(null));
                  final semantics = tester.ensureSemantics();
                  try {
                    var taps = 0;
                    final gateway = _ComparisonCoverGateway()
                      ..downloadResult = cover;
                    if (scenario == 'failed-cover') {
                      gateway.downloadError = StateError(
                        'Synthetic media failure',
                      );
                    }
                    await tester.pumpWidget(
                      _app(
                        locale,
                        dark,
                        scale,
                        gateway,
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ProposalCardComparison(
                            proposal: _proposal(scenario),
                            composition: composition,
                            requested: _requested(scenario),
                            syntheticPopular: _popular(scenario),
                            onTap: () => taps++,
                          ),
                        ),
                      ),
                    );
                    await tester.pumpAndSettle();
                    expect(tester.takeException(), isNull);
                    final image = find.byType(AspectRatio).first;
                    final rect = tester.getRect(image);
                    expect(rect.width / rect.height, closeTo(1.5, .001));
                    if (composition != CardComposition.baseline) {
                      final idea = find.byKey(const Key('comparison-idea'));
                      expect(
                        idea,
                        scenario == 'defined' ? findsNothing : findsOneWidget,
                      );
                      if (scenario != 'defined') {
                        expect(tester.getSemantics(idea).label, 'Idea');
                        if (_requested(scenario)) {
                          expect(
                            tester
                                .getRect(idea)
                                .overlaps(
                                  tester.getRect(find.byType(RequestedBadge)),
                                ),
                            isFalse,
                          );
                        }
                      }
                      expect(
                        find.byKey(const Key('comparison-popular')),
                        _popular(scenario) ? findsOneWidget : findsNothing,
                      );
                    }
                    if (_requested(scenario)) {
                      final requested = find.byKey(
                        const Key('browse-requested-badge'),
                      );
                      expect(
                        tester.getSemantics(requested).label,
                        contains(locale == 'it' ? 'Richiesta' : 'Requested'),
                      );
                      final badge = tester.getRect(requested);
                      expect(badge.left, greaterThanOrEqualTo(rect.left));
                      expect(badge.right, lessThanOrEqualTo(rect.right));
                      expect(badge.bottom, lessThanOrEqualTo(rect.bottom));
                      // Candidate overlays ignore pointers; hit the card at that
                      // visible marker rather than requiring the marker itself
                      // to participate in hit testing.
                      await tester.tapAt(tester.getCenter(requested));
                    } else {
                      await tester.tap(image);
                    }
                    expect(taps, 1);
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

  for (final capture in [
    ('idea', 'en', false, 360.0, 1.0),
    ('all', 'it', false, 320.0, 1.0),
    ('all', 'it', false, 360.0, 1.0),
    ('all', 'it', true, 320.0, 2.0),
    ('defined', 'it', false, 360.0, 1.0),
    ('no-cover', 'en', false, 320.0, 2.0),
    ('failed-cover', 'en', true, 360.0, 1.0),
  ]) {
    testWidgets('A02 curated $capture', (tester) async {
      final (scenario, locale, dark, width, scale) = capture;
      await tester.binding.setSurfaceSize(Size(width * 3, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = _ComparisonCoverGateway()..downloadResult = cover;
      if (scenario == 'failed-cover') {
        gateway.downloadError = StateError('Synthetic media failure');
      }
      await tester.pumpWidget(
        _app(
          locale,
          dark,
          scale,
          gateway,
          RenderedEvidence.wrap(
            ColoredBox(
              color:
                  (dark ? AppTheme.dark : AppTheme.light).colorScheme.surface,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final composition in CardComposition.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              composition.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            ProposalCardComparison(
                              proposal: _proposal(scenario),
                              composition: composition,
                              requested: _requested(scenario),
                              syntheticPopular: _popular(scenario),
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await RenderedEvidence.capture(
        tester,
        'a02-$scenario-$locale-${dark ? 'dark' : 'light'}-${width.toInt()}-${scale.toInt()}x',
      );
    });
  }
}

Widget _app(
  String locale,
  bool dark,
  double scale,
  FakeCoverMediaGateway gateway,
  Widget child,
) => ProviderScope(
  overrides: [coverMediaGatewayProvider.overrideWithValue(gateway)],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.dark : AppTheme.light,
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

class _ComparisonCoverGateway extends FakeCoverMediaGateway {
  Object? downloadError;
  @override
  Future<Uint8List> downloadCover(String objectPath) async {
    if (downloadError case final failure?) throw failure;
    return super.downloadCover(objectPath);
  }
}
