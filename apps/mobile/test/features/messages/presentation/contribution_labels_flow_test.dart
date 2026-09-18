import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_models.dart';
import 'package:planets_mobile/features/messages/presentation/participation_request_message_screen.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/data/join_acceptance_triage_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_messages.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_join_acceptance_triage.dart';

void main() {
  testWidgets(
    'request detail wraps skill and resource labels in canonical order',
    (tester) async {
      final messages = FakeMessagesGateway()
        ..items = [messageItemFixture(status: JoinRequestStatus.accepted)]
        ..selections = const [
          RequestContributionSelection(
            kind: RequestContributionSelectionKind.skill,
            id: 'skill-1',
            label: 'Community carpentry and timber repair knowledge',
          ),
          RequestContributionSelection(
            kind: RequestContributionSelectionKind.resource,
            id: 'need-1',
            label: 'Weather-resistant exterior paint and long wooden boards',
          ),
        ];
      final session = await _pump(tester, messages);
      addTearDown(session.dispose);

      expect(find.text('Can contribute'), findsOneWidget);
      expect(find.text('Competences / Knowledge'), findsOneWidget);
      expect(find.text('Resources / Materials'), findsOneWidget);
      expect(
        find.byKey(const Key('message-contribution-skill-skill-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('message-contribution-resource-need-1')),
        findsOneWidget,
      );
      expect(find.text('Accepted'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('zero selections remain explicit beside the optional message', (
    tester,
  ) async {
    final messages = FakeMessagesGateway()..items = [messageItemFixture()];
    final session = await _pump(tester, messages);
    addTearDown(session.dispose);

    expect(find.text('No contributions selected'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('message-detail-request-message')),
      250,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    expect(find.text('I can bring paint brushes.'), findsOneWidget);
  });

  testWidgets(
    'selection failure keeps request and creator actions, then retries',
    (tester) async {
      final messages = FakeMessagesGateway()
        ..items = [messageItemFixture()]
        ..selectionError = StateError('private diagnostic');
      final triage = FakeJoinAcceptanceTriageGateway()
        ..selectionError = StateError('private action diagnostic');
      final session = await _pump(tester, messages, triage: triage);
      addTearDown(session.dispose);

      expect(
        find.byKey(const Key('message-contributions-error')),
        findsOneWidget,
      );
      expect(find.textContaining('private diagnostic'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('message-accept')),
        300,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      expect(find.byKey(const Key('message-accept')), findsOneWidget);
      expect(find.byKey(const Key('message-reject')), findsOneWidget);
      await tester.tap(find.byKey(const Key('message-accept')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('join-acceptance-load-error')),
        findsOneWidget,
      );
      expect(triage.calls.where((call) => call.startsWith('accept:')), isEmpty);
      await tester.tap(find.byKey(const Key('join-acceptance-close')));
      await tester.pumpAndSettle();

      messages
        ..selectionError = null
        ..selections = const [
          RequestContributionSelection(
            kind: RequestContributionSelectionKind.resource,
            id: 'need-1',
            label: 'Paint',
          ),
        ];
      await tester.scrollUntilVisible(
        find.byKey(const Key('message-contributions-retry')),
        -300,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await tester.tap(find.byKey(const Key('message-contributions-retry')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('message-contribution-resource-need-1')),
        findsOneWidget,
      );
    },
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeMessagesGateway messages, {
  FakeJoinAcceptanceTriageGateway? triage,
}) async {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  addTearDown(auth.close);
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      messagesGatewayProvider.overrideWithValue(messages),
      participationGatewayProvider.overrideWithValue(
        FakeParticipationGateway(),
      ),
      joinAcceptanceTriageGatewayProvider.overrideWithValue(
        triage ?? FakeJoinAcceptanceTriageGateway(),
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ParticipationRequestMessageScreen(requestId: 'request-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
