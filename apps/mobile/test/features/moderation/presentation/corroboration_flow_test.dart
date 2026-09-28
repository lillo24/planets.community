import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/moderation/application/corroboration_controllers.dart';
import 'package:planets_mobile/features/moderation/data/corroboration_gateway.dart';
import 'package:planets_mobile/features/moderation/presentation/corroboration_screens.dart';
import 'package:planets_mobile/features/moderation/presentation/corroboration_session_prompt.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_moderation.dart';

const profileId = '00000000-0000-4000-8000-000000000001';
const requestId = '00000000-0000-4000-8000-000000000911';

void main() {
  testWidgets('prompts one pending request only once in the app session', (
    tester,
  ) async {
    final gateway = FakeCorroborationGateway()
      ..items = [corroborationSummaryFixture()];
    final container = _container(gateway);
    addTearDown(container.dispose);
    await _pump(
      tester,
      container,
      const CorroborationSessionPromptHost(child: Scaffold()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('corroboration-session-prompt')), findsOne);
    expect(find.textContaining('identity is hidden'), findsOneWidget);
    expect(find.textContaining('does not mean you witnessed'), findsOneWidget);
    expect(gateway.pendingOnly, isTrue);

    await tester.tap(find.byKey(const Key('corroboration-later')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('corroboration-session-prompt')), findsNothing);

    await _pump(
      tester,
      container,
      const CorroborationSessionPromptHost(child: Scaffold()),
    );
    await tester.pumpAndSettle();
    expect(gateway.listCount, 1);
  });

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
