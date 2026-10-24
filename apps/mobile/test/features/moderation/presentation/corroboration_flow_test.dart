import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/moderation/application/corroboration_controllers.dart';
import 'package:planets_mobile/features/moderation/data/corroboration_gateway.dart';
import 'package:planets_mobile/features/moderation/presentation/corroboration_screens.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_moderation.dart';

const profileId = '00000000-0000-4000-8000-000000000001';
const requestId = '00000000-0000-4000-8000-000000000911';

void main() {
  for (final locale in ['it', 'en']) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'GL1 full witness choices remain visible/selectable at 320dp $locale/$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final gateway = FakeCorroborationGateway();
          final c = _container(gateway);
          addTearDown(c.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: c,
              child: MaterialApp(
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const CorroborationDetailScreen(requestId: requestId),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l = lookupAppLocalizations(Locale(locale));
          for (final (value, label) in [
            ('agree', l.corroborationChoiceAgree),
            ('disagree', l.corroborationChoiceDisagree),
            ('unsure', l.corroborationChoiceUnsure),
          ]) {
            final tile = find.byKey(Key('corroboration-choice-$value'));
            await tester.scrollUntilVisible(
              tile,
              200,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            final paragraph = tester.renderObject<RenderParagraph>(
              find.text(label),
            );
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(paragraph.size.width, lessThanOrEqualTo(320));
            await tester.tap(tile);
            await tester.pump();
            expect(tester.widget<RadioListTile>(tile).enabled, isTrue);
          }
          final submit = find.byKey(const Key('corroboration-submit'));
          await tester.scrollUntilVisible(
            submit,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            tester.element(submit),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(gateway.submitCount, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('shows private wording and records a final unsure response', (
    tester,
  ) async {
    final gateway = FakeCorroborationGateway();
    final container = _container(gateway);
    addTearDown(container.dispose);
    await _pump(
      tester,
      container,
      const CorroborationDetailScreen(requestId: requestId),
    );
    await tester.pumpAndSettle();

    expect(find.text('The original reporter wording.'), findsOneWidget);
    expect(
      find.textContaining('visible only to PLANETS staff'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final unsure = find.byKey(const Key('corroboration-choice-unsure'));
    await tester.tap(unsure);
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('corroboration-submit'));
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(gateway.submitCount, 1);
    expect(find.byKey(const Key('corroboration-submitted')), findsOneWidget);
    expect(find.textContaining('not a vote'), findsOneWidget);
  });

  testWidgets('completed case explains why no response can be submitted', (
    tester,
  ) async {
    final gateway = FakeCorroborationGateway()
      ..detail = corroborationDetailFixture(canRespond: false);
    final container = _container(gateway);
    addTearDown(container.dispose);
    await _pump(
      tester,
      container,
      const CorroborationDetailScreen(requestId: requestId),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('corroboration-closed')), findsOneWidget);
    expect(find.byKey(const Key('corroboration-submit')), findsNothing);
  });
}

ProviderContainer _container(FakeCorroborationGateway gateway) {
  final container = ProviderContainer(
    overrides: [
      corroborationGatewayProvider.overrideWithValue(gateway),
      corroborationSubmissionIdGeneratorProvider.overrideWithValue(
        () => 'corroboration-submission-id',
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: profileId));
  return container;
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget home,
) => tester.pumpWidget(
  UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  ),
);
