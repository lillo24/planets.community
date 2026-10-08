import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/moderation/presentation/own_request_restriction_notice.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language narrow large-text explanation announces and reaches action',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: OwnRequestRestrictionNotice(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final explanation = find.byKey(
            const Key('own-request-restriction-explanation'),
          );
          final node = tester.getSemantics(explanation);
          expect(node.flagsCollection.isLiveRegion, isTrue);
          final action = find.byKey(
            const Key('own-request-restriction-notices'),
          );
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          expect(action.hitTestable(), findsOneWidget);
          expect(
            find.text(
              language == 'it'
                  ? 'Consulta gli avvisi di PLANETS'
                  : 'View PLANETS notices',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
