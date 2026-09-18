import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/application/join_acceptance_triage_controller.dart';
import 'package:planets_mobile/features/participation/data/join_acceptance_triage_gateway.dart';
import 'package:planets_mobile/features/participation/domain/join_acceptance_triage_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/participation/presentation/join_acceptance_triage_sheet.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_join_acceptance_triage.dart';

void main() {
  testWidgets('groups offers, validates every item, guides once, and accepts', (
    tester,
  ) async {
    bool? result;
    final gateway = FakeJoinAcceptanceTriageGateway()
      ..selections = [
        triageItemFixture(
          label: 'Community carpentry and timber repair knowledge',
        ),
        triageItemFixture(
          id: 'need-1',
          kind: JoinAcceptanceSelectionKind.resource,
          label: 'Weather-resistant exterior paint and long wooden boards',
        ),
      ];
    final container = await _pumpHost(
      tester,
      gateway: gateway,
      onResult: (value) => result = value,
    );
    addTearDown(container.dispose);

    await tester.tap(find.byKey(const Key('open-triage')));
    await tester.pumpAndSettle();
    expect(find.text('Review contribution offers'), findsOneWidget);
    expect(find.text('Competences / Knowledge'), findsOneWidget);
    expect(find.text('Resources / Materials'), findsOneWidget);
    expect(find.textContaining('Community carpentry'), findsOneWidget);
    expect(find.textContaining('Weather-resistant'), findsOneWidget);

    await tester.tap(find.byKey(const Key('join-acceptance-submit')));
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const Key('join-acceptance-validation-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('join-acceptance-item-error-skill-skill-1')),
      findsOneWidget,
    );
    expect(find.textContaining('current commitments later'), findsOneWidget);
    expect(gateway.calls.where((call) => call.startsWith('accept:')), isEmpty);
    var state = container.read(joinAcceptanceTriageProvider('request-1'));
    expect(state.validationAttempt, 1);
    expect(state.hasShownFirstGuidance, isTrue);

    Tooltip.dismissAllToolTips();
    await tester.pump();
    await tester.tap(find.byKey(const Key('join-acceptance-submit')));
    await tester.pump();
    state = container.read(joinAcceptanceTriageProvider('request-1'));
    expect(state.validationAttempt, 2);
    expect(find.textContaining('current commitments later'), findsNothing);

    final skillDecision = find.byKey(
      const Key('join-acceptance-skill-skill-1-needed'),
    );
    await tester.scrollUntilVisible(
      skillDecision,
      250,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.tap(skillDecision);
    await tester.pump();
    expect(tester.widget<ChoiceChip>(skillDecision).selected, isTrue);
    final alreadyFoundDecision = find.byKey(
      const Key('join-acceptance-skill-skill-1-alreadyFound'),
    );
    await tester.tap(alreadyFoundDecision);
    await tester.pump();
    expect(tester.widget<ChoiceChip>(skillDecision).selected, isFalse);
    expect(tester.widget<ChoiceChip>(alreadyFoundDecision).selected, isTrue);
    await tester.tap(skillDecision);
    await tester.pump();
    expect(
      find.byKey(const Key('join-acceptance-item-error-skill-skill-1')),
      findsNothing,
    );
    final resourceDecision = find.byKey(
      const Key('join-acceptance-resource-need-1-extra'),
    );
    await tester.scrollUntilVisible(
      resourceDecision,
      250,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.tap(resourceDecision);
    await tester.pump();
    await tester.tap(find.byKey(const Key('join-acceptance-submit')));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(gateway.neededSkillIds, {'skill-1'});
    expect(gateway.extraResourceNeedIds, {'need-1'});
    expect(find.text('Review contribution offers'), findsNothing);
    expect(
      container.read(joinAcceptanceTriageProvider('request-1')).items,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero offers submit six empty partitions', (tester) async {
    bool? result;
    final gateway = FakeJoinAcceptanceTriageGateway();
    final container = await _pumpHost(
      tester,
      gateway: gateway,
      onResult: (value) => result = value,
    );
    addTearDown(container.dispose);

    await tester.tap(find.byKey(const Key('open-triage')));
    await tester.pumpAndSettle();
    expect(find.text('No contribution offers to classify.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('join-acceptance-submit')));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(gateway.neededSkillIds, isEmpty);
    expect(gateway.alreadyFoundSkillIds, isEmpty);
    expect(gateway.extraSkillIds, isEmpty);
    expect(gateway.neededResourceNeedIds, isEmpty);
    expect(gateway.alreadyFoundResourceNeedIds, isEmpty);
    expect(gateway.extraResourceNeedIds, isEmpty);
  });

  testWidgets('Tavolo offers render resources without a competence group', (
    tester,
  ) async {
    final gateway = FakeJoinAcceptanceTriageGateway()
      ..selections = [
        triageItemFixture(
          id: 'need-1',
          kind: JoinAcceptanceSelectionKind.resource,
          label: 'Folding table',
        ),
      ];
    final container = await _pumpHost(
      tester,
      gateway: gateway,
      projectKind: ProjectKind.recurring,
    );
    addTearDown(container.dispose);

    await tester.tap(find.byKey(const Key('open-triage')));
    await tester.pumpAndSettle();
    expect(find.text('Resources / Materials'), findsOneWidget);
    expect(find.text('Competences / Knowledge'), findsNothing);
    expect(find.text('Folding table'), findsOneWidget);
  });

  testWidgets('load failure retries and accepting state blocks duplicates', (
    tester,
  ) async {
    final pending = Completer<void>();
    final gateway = FakeJoinAcceptanceTriageGateway()
      ..selectionError = StateError('private load diagnostic');
    final container = await _pumpHost(tester, gateway: gateway);
    addTearDown(container.dispose);

    await tester.tap(find.byKey(const Key('open-triage')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-acceptance-load-error')), findsOneWidget);
    expect(find.textContaining('private load diagnostic'), findsNothing);

    gateway
      ..selectionError = null
      ..selections = []
      ..mutationDelay = pending.future;
    await tester.tap(find.byKey(const Key('join-acceptance-retry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('join-acceptance-submit')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('join-acceptance-submit')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('join-acceptance-submit')))
          .onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(
      gateway.calls.where((call) => call == 'accept:request-1'),
      hasLength(1),
    );
  });

  testWidgets('account switch removes private triage content', (tester) async {
    final gateway = FakeJoinAcceptanceTriageGateway()
      ..selections = [triageItemFixture(label: 'Private offer')];
    final container = await _pumpHost(tester, gateway: gateway);
    addTearDown(container.dispose);

    await tester.tap(find.byKey(const Key('open-triage')));
    await tester.pumpAndSettle();
    expect(find.text('Private offer'), findsOneWidget);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    await tester.pump();

    expect(find.text('Private offer'), findsNothing);
    expect(find.byKey(const Key('join-acceptance-submit')), findsNothing);
  });
}

Future<ProviderContainer> _pumpHost(
  WidgetTester tester, {
  required FakeJoinAcceptanceTriageGateway gateway,
  ValueChanged<bool>? onResult,
  ProjectKind projectKind = ProjectKind.oneTime,
}) async {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  addTearDown(auth.close);
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      joinAcceptanceTriageGatewayProvider.overrideWithValue(gateway),
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
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const Key('open-triage'),
                onPressed: () async {
                  final result = await showJoinAcceptanceTriageSheet(
                    context,
                    expectedCreatorProfileId: 'user-1',
                    requestId: 'request-1',
                    projectId: 'proposal-1',
                    projectKind: projectKind,
                    requesterDisplayName: 'Jordan',
                  );
                  onResult?.call(result);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}
