import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/widgets/requested_badge.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_cover_media.dart';
import '../../../support/fake_proposal.dart';

const _longTitle =
    'Organizziamo insieme una giornata di giardinaggio e arte pubblica '
    'per rendere più accogliente il cortile del nostro quartiere';

void main() {
  for (final language in ['en', 'it']) {
    for (final hasImage in [false, true]) {
      testWidgets(
        '$language requested badge overlays ${hasImage ? 'image' : 'placeholder'} '
        'and preserves narrow long-title layout, semantics and taps',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 1400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final semantics = tester.ensureSemantics();
          try {
            final covers = FakeCoverMediaGateway()
              // Valid synthetic one-pixel PNG: no network or production media.
              ..downloadResult = base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
                'AAAADUlEQVR4nGMomLHlPwAF9AK85D4hXwAAAABJRU5ErkJggg==',
              );
            var taps = 0;
            final proposal = proposalSummaryFixture(
              title: _longTitle,
              coverObjectPath: hasImage ? 'synthetic-cover.webp' : null,
            );

            Widget card({required bool requested}) => ProviderScope(
              overrides: [coverMediaGatewayProvider.overrideWithValue(covers)],
              child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: ListView(
                    children: [
                      ProposalCard(
                        proposal: proposal,
                        isRequested: requested,
                        onTap: () => taps++,
                      ),
                    ],
                  ),
                ),
              ),
            );

            await tester.pumpWidget(card(requested: true));
            await tester.pumpAndSettle();
            final cover = find.byKey(const Key('proposal-cover-proposal-1'));
            final badge = find.byType(RequestedBadge);
            final status = find.byType(ProposalStatusBadge);
            final title = find.text(_longTitle);
            final coverRect = tester.getRect(cover);
            final badgeRect = tester.getRect(badge);
            expect(badgeRect.left, greaterThanOrEqualTo(coverRect.left));
            expect(badgeRect.bottom, lessThanOrEqualTo(coverRect.bottom));
            expect(badgeRect.right, closeTo(coverRect.right - 8, 0.1));
            expect(badgeRect.top, closeTo(coverRect.top + 8, 0.1));
            expect(tester.getRect(status).top, greaterThan(coverRect.bottom));
            expect(tester.getRect(title).top, greaterThan(coverRect.bottom));
            expect(
              find.text(language == 'it' ? 'Richiesta inviata' : 'Requested'),
              findsOneWidget,
            );
            expect(
              find.text(language == 'it' ? 'In programma' : 'Upcoming'),
              findsOneWidget,
            );
            final l10n = AppLocalizations.of(tester.element(title));
            expect(
              tester
                  .getSemantics(find.byKey(const Key('browse-requested-badge')))
                  .label,
              contains(l10n.browseRequestedSemantics),
            );
            final shape =
                tester.widget<Card>(find.byType(Card)).shape! as OutlinedBorder;
            expect(shape.side.width, 2);
            expect(tester.takeException(), isNull);
            if (hasImage) expect(find.byType(Image), findsOneWidget);

            await tester.tap(badge);
            expect(taps, 1);
            final requestedTitleWidth = tester.getSize(title).width;

            await tester.pumpWidget(card(requested: false));
            await tester.pumpAndSettle();
            expect(badge, findsNothing);
            expect(tester.widget<Card>(find.byType(Card)).shape, isNull);
            expect(tester.getRect(cover), coverRect);
            expect(
              tester.getSize(title).width,
              closeTo(requestedTitleWidth, 0.1),
            );
            expect(tester.takeException(), isNull);
            await tester.tap(find.byKey(const Key('proposal-card-proposal-1')));
            expect(taps, 2);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
