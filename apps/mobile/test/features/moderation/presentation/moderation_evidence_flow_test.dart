import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/moderation/application/counterstatement_controllers.dart';
import 'package:planets_mobile/features/moderation/data/counterstatement_gateway.dart';
import 'package:planets_mobile/features/moderation/data/moderation_evidence_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_evidence_models.dart';
import 'package:planets_mobile/features/moderation/presentation/counterstatement_screen.dart';
import 'package:planets_mobile/features/moderation/presentation/moderation_evidence_requests_screen.dart';
import 'package:planets_mobile/features/moderation/presentation/moderation_evidence_session_prompt.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_moderation.dart';

const profileId = '00000000-0000-4000-8000-000000000001';
const requestId = '00000000-0000-4000-8000-000000000921';

void main() {
  testWidgets('prompts the oldest unified request once per app session', (
    tester,
  ) async {
    final evidenceGateway = FakeModerationEvidenceGateway()
      ..items = [moderationEvidenceSummaryFixture()];
    final container = _container(evidenceGateway: evidenceGateway);
    addTearDown(container.dispose);

    await _pump(
      tester,
      container,
      const ModerationEvidenceSessionPromptHost(child: Scaffold()),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('moderation-evidence-session-prompt')),
      findsOneWidget,
    );
    expect(find.textContaining('interaction between you'), findsOneWidget);
    expect(find.textContaining('obvious who submitted'), findsOneWidget);
    expect(evidenceGateway.pendingOnly, isTrue);
    expect(evidenceGateway.limit, 1);

    await tester.tap(find.byKey(const Key('moderation-evidence-later')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('moderation-evidence-session-prompt')),
      findsNothing,
    );

    await _pump(
      tester,
      container,
      const ModerationEvidenceSessionPromptHost(child: Scaffold()),
    );
    await tester.pumpAndSettle();
    expect(evidenceGateway.listCount, 1);
  });

  testWidgets('unified review history differentiates both evidence kinds', (
    tester,
  ) async {
    final evidenceGateway = FakeModerationEvidenceGateway()
      ..items = [
        moderationEvidenceSummaryFixture(
          requestId: '00000000-0000-4000-8000-000000000911',
          kind: ModerationEvidenceKind.groupCorroboration,
        ),
        moderationEvidenceSummaryFixture(),
      ];
    final container = _container(evidenceGateway: evidenceGateway);
    addTearDown(container.dispose);

    await _pump(tester, container, const ModerationEvidenceRequestsScreen());
    await tester.pumpAndSettle();

    expect(find.text('Project group context'), findsOneWidget);
    expect(find.text('Scambio-Dona counterparty statement'), findsOneWidget);
    expect(evidenceGateway.pendingOnly, isFalse);
  });

  testWidgets('account changes never stack private evidence prompts', (
    tester,
  ) async {
    final evidenceGateway = FakeModerationEvidenceGateway()
      ..items = [moderationEvidenceSummaryFixture()];
    final container = _container(evidenceGateway: evidenceGateway);
    addTearDown(container.dispose);

    await _pump(
      tester,
      container,
      const ModerationEvidenceSessionPromptHost(child: Scaffold()),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('moderation-evidence-session-prompt')),
      findsOneWidget,
    );

    container
        .read(authSessionProvider.notifier)
        .markProfileReady(
          const AuthIdentity(id: '00000000-0000-4000-8000-000000000099'),
        );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('moderation-evidence-session-prompt')),
      findsOneWidget,
    );
    expect(evidenceGateway.listCount, 2);
  });

  testWidgets('validates and submits one final private counterstatement', (
    tester,
  ) async {
    final counterstatementGateway = FakeCounterstatementGateway();
    final container = _container(
      counterstatementGateway: counterstatementGateway,
    );
    addTearDown(container.dispose);

    await _pump(
      tester,
      container,
      const CounterstatementDetailScreen(requestId: requestId),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('The original Resource request report wording.'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('counterstatement-submit'));
    await tester.tap(submit);
    await tester.pump();
    expect(find.textContaining('10 and 4,000'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('counterstatement-statement')),
      'My private response.',
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(counterstatementGateway.submitCount, 1);
    expect(find.byKey(const Key('counterstatement-submitted')), findsOneWidget);
    expect(find.byKey(const Key('counterstatement-submit')), findsNothing);
  });

  testWidgets('completed request is read-only without a submit control', (
    tester,
  ) async {
    final counterstatementGateway = FakeCounterstatementGateway()
      ..detail = counterstatementDetailFixture(canRespond: false);
    final container = _container(
      counterstatementGateway: counterstatementGateway,
    );
    addTearDown(container.dispose);

    await _pump(
      tester,
      container,
      const CounterstatementDetailScreen(requestId: requestId),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('counterstatement-closed')), findsOneWidget);
    expect(find.byKey(const Key('counterstatement-submit')), findsNothing);
  });
}

ProviderContainer _container({
  FakeModerationEvidenceGateway? evidenceGateway,
  FakeCounterstatementGateway? counterstatementGateway,
}) {
  final container = ProviderContainer(
    overrides: [
      if (evidenceGateway != null)
        moderationEvidenceGatewayProvider.overrideWithValue(evidenceGateway),
      if (counterstatementGateway != null)
        counterstatementGatewayProvider.overrideWithValue(
          counterstatementGateway,
        ),
      counterstatementSubmissionIdGeneratorProvider.overrideWithValue(
        () => 'counterstatement-submission-id',
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
