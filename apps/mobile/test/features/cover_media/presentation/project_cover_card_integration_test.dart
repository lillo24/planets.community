import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/recurring_activity_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_cover_media.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_recurring_activity.dart';

const _owner = 'c1000000-0000-4000-8000-000000000001';
const _project = 'c2000000-0000-4000-8000-000000000001';
const _path =
    '$_owner/projects/$_project/c3000000-0000-4000-8000-000000000001.webp';

void main() {
  testWidgets(
    'Proposal card leads with the canonical cover and remains tappable',
    (tester) async {
      final gateway = FakeCoverMediaGateway()..downloadResult = _imageBytes();
      var tapped = false;
      await tester.pumpWidget(
        _host(
          gateway,
          ProposalCard(
            proposal: proposalSummaryFixture(coverObjectPath: _path),
            onTap: () => tapped = true,
            isRequested: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('proposal-cover-proposal-1')),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byKey(const Key('proposal-card-proposal-1')));
      expect(tapped, isTrue);
    },
  );

  testWidgets('Tavolo card renders the shared cover component', (tester) async {
    final gateway = FakeCoverMediaGateway()..downloadResult = _imageBytes();
    await tester.pumpWidget(
      _host(
        gateway,
        RecurringActivityCard(
          activity: publicRecurringSummaryFixture(coverObjectPath: _path),
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tavolo-cover-tavolo-1')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}

Widget _host(CoverMediaGateway gateway, Widget child) {
  return ProviderScope(
    overrides: [coverMediaGatewayProvider.overrideWithValue(gateway)],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

Uint8List _imageBytes() {
  final source = image.Image(width: 32, height: 18);
  image.fill(source, color: image.ColorRgb8(80, 140, 60));
  return image.encodePng(source);
}
