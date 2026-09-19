import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/data/actual_contribution_gateway.dart';
import 'package:planets_mobile/features/participation/domain/actual_contribution_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/participation/presentation/actual_contribution_sheet.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_actual_contribution.dart';
import '../../../support/fake_auth.dart';

void main() {
  testWidgets('read-only mode groups factual contributions and effort', (
    tester,
  ) async {
    final gateway = FakeActualContributionGateway()
      ..contributions = [
        actualContributionFixture(),
        actualContributionFixture(
          id: 'need-1',
          kind: ActualContributionKind.resource,
          label: 'Wooden boards',
        ),
        substantialEffortFixture(),
      ];
    await _pumpHost(tester, gateway: gateway, editable: false);

    await tester.tap(find.byKey(const Key('open-actual-contributions')));
    await tester.pumpAndSettle();

    expect(find.text('Competences / Knowledge'), findsOneWidget);
    expect(find.text('Carpentry'), findsOneWidget);
    expect(find.text('Resources / Materials'), findsOneWidget);
    expect(find.text('Wooden boards'), findsOneWidget);
    expect(find.text('Other contribution'), findsOneWidget);
    expect(find.text('Substantial Effort / Energy'), findsOneWidget);
    expect(find.byKey(const Key('actual-contribution-save')), findsNothing);
    expect(gateway.calls, ['contributions:membership-1']);
  });

  testWidgets('empty and lifecycle-unavailable reads use neutral copy', (
    tester,
  ) async {
    final emptyGateway = FakeActualContributionGateway();
    await _pumpHost(tester, gateway: emptyGateway, editable: false);
    await tester.tap(find.byKey(const Key('open-actual-contributions')));
    await tester.pumpAndSettle();
    expect(find.text('No actual contributions recorded.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('actual-contribution-close')));
    await tester.pumpAndSettle();
    emptyGateway.readError = const PostgrestException(
      message: 'private lifecycle diagnostic',
      code: '55000',
    );
    await tester.tap(find.byKey(const Key('open-actual-contributions')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Actual contributions are available after an eligible one-time Project ends.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('private lifecycle diagnostic'), findsNothing);
  });

  testWidgets('editor starts from effective set and saves explicit CAS draft', (
    tester,
  ) async {
    final gateway = FakeActualContributionGateway()
      ..contributions = [
        actualContributionFixture(),
        substantialEffortFixture(),
      ]
      ..options = [
        actualContributionOptionFixture(),
        actualContributionOptionFixture(
          id: 'need-1',
          kind: ActualContributionKind.resource,
          label: 'Paint',
        ),
      ];
    await _pumpHost(tester, gateway: gateway, editable: true);
    await tester.tap(find.byKey(const Key('open-actual-contributions')));
    await tester.pumpAndSettle();

    final save = find.byKey(const Key('actual-contribution-save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const Key('actual-contribution-option-skill-skill-1')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const Key('actual-contribution-option-resource-need-1')),
          )
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const Key('actual-contribution-effort')),
          )
          .selected,
      isTrue,
    );

    await tester.tap(find.text('Carpentry'));
    await tester.tap(find.text('Paint'));
    await tester.tap(find.text('Substantial Effort / Energy'));
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Edit actual contributions'), findsNothing);
    expect(gateway.lastExpectedSkillIds, {'skill-1'});
    expect(gateway.lastExpectedResourceNeedIds, isEmpty);
    expect(gateway.lastExpectedSubstantialEffort, isTrue);
    expect(gateway.lastSkillIds, isEmpty);
    expect(gateway.lastResourceNeedIds, {'need-1'});
    expect(gateway.lastSubstantialEffort, isFalse);
  });

  testWidgets('transient options failure keeps facts and retries editing', (
    tester,
  ) async {
    final gateway = FakeActualContributionGateway()
      ..contributions = [actualContributionFixture()]
      ..optionsError = StateError('private options diagnostic');
    await _pumpHost(tester, gateway: gateway, editable: true);
    await tester.tap(find.byKey(const Key('open-actual-contributions')));
    await tester.pumpAndSettle();

    expect(find.text('Carpentry'), findsOneWidget);
    expect(
      find.byKey(const Key('actual-contribution-options-error')),
      findsOneWidget,
    );
    expect(find.textContaining('private options diagnostic'), findsNothing);
    expect(find.byKey(const Key('actual-contribution-save')), findsNothing);

    gateway.optionsError = null;
    gateway.options = [actualContributionOptionFixture()];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('actual-contribution-save')), findsOneWidget);
    expect(
      gateway.calls.where((call) => call.startsWith('contributions:')),
      hasLength(1),
    );
  });

  testWidgets('stale save reloads and announces conflict without resubmit', (
    tester,
  ) async {
    final gateway = FakeActualContributionGateway()
      ..contributions = [actualContributionFixture(id: 'skill-old')]
      ..options = [
        actualContributionOptionFixture(id: 'skill-old'),
        actualContributionOptionFixture(id: 'skill-new', label: 'Painting'),
      ]
      ..replaceErrors.add(
        const PostgrestException(message: 'private stale', code: '40001'),
      );
    await _pumpHost(tester, gateway: gateway, editable: true);
    await tester.tap(find.byKey(const Key('open-actual-contributions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Painting'));
    await tester.pump();
    gateway.contributions = [
      actualContributionFixture(id: 'skill-concurrent', label: 'Gardening'),
    ];
    await tester.tap(find.byKey(const Key('actual-contribution-save')));
    await tester.pumpAndSettle();

    expect(find.text('Edit actual contributions'), findsOneWidget);
    expect(find.text('Gardening'), findsOneWidget);
    expect(find.textContaining('changed elsewhere'), findsOneWidget);
    expect(find.textContaining('private stale'), findsNothing);
    expect(
      gateway.calls.where((call) => call.startsWith('replace:')),
      hasLength(1),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('actual-contribution-save')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('changed options reload canonical state without resubmit', (
    tester,
  ) async {
    final gateway = FakeActualContributionGateway()
      ..contributions = [actualContributionFixture(id: 'skill-old')]
      ..options = [
        actualContributionOptionFixture(id: 'skill-old'),
        actualContributionOptionFixture(id: 'skill-new', label: 'Painting'),
      ]
      ..replaceErrors.add(
        const PostgrestException(message: 'private option', code: '22023'),
      );
    await _pumpHost(tester, gateway: gateway, editable: true);
    await tester.tap(find.byKey(const Key('open-actual-contributions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Painting'));
    await tester.pump();
    gateway.options = [actualContributionOptionFixture(id: 'skill-old')];
    await tester.tap(find.byKey(const Key('actual-contribution-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('options changed'), findsOneWidget);
    expect(find.text('Painting'), findsNothing);
    expect(find.textContaining('private option'), findsNothing);
    expect(
      gateway.calls.where((call) => call.startsWith('replace:')),
      hasLength(1),
    );
  });

  testWidgets('save shows progress and prevents duplicate actions', (
    tester,
  ) async {
    final pending = pendingActualContributionOperation();
    final gateway = FakeActualContributionGateway()
      ..options = [actualContributionOptionFixture()]
      ..replaceDelay = pending.future;
    await _pumpHost(tester, gateway: gateway, editable: true);
    await tester.tap(find.byKey(const Key('open-actual-contributions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carpentry'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('actual-contribution-save')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('actual-contribution-save')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('actual-contribution-clear')),
          )
          .onPressed,
      isNull,
    );
    expect(
      gateway.calls.where((call) => call.startsWith('replace:')),
      hasLength(1),
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Edit actual contributions'), findsNothing);
  });

  testWidgets('limit disables only additions and long scaled labels wrap', (
    tester,
  ) async {
    final longLabel = 'A very long contribution label ' * 5;
    final gateway = FakeActualContributionGateway()
      ..contributions = [
        for (var index = 0; index < participationSkillSelectionMax; index++)
          actualContributionFixture(id: 'skill-$index', label: 'Skill $index'),
      ]
      ..options = [
        for (var index = 0; index < participationSkillSelectionMax; index++)
          actualContributionOptionFixture(
            id: 'skill-$index',
            label: 'Skill $index',
          ),
        actualContributionOptionFixture(id: 'skill-extra', label: longLabel),
      ];
    await _pumpHost(
      tester,
      gateway: gateway,
      editable: true,
      textScaler: const TextScaler.linear(2),
    );
    await tester.tap(find.byKey(const Key('open-actual-contributions')));
    await tester.pumpAndSettle();

    final selected = tester.widget<FilterChip>(
      find.byKey(const Key('actual-contribution-option-skill-skill-0')),
    );
    final extra = tester.widget<FilterChip>(
      find.byKey(const Key('actual-contribution-option-skill-skill-extra')),
    );
    expect(selected.onSelected, isNotNull);
    expect(extra.onSelected, isNull);
    expect(find.text('Maximum 50 selections'), findsOneWidget);
    expect(find.text(longLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pumpHost(
  WidgetTester tester, {
  required FakeActualContributionGateway gateway,
  required bool editable,
  TextScaler textScaler = TextScaler.noScaling,
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
      actualContributionGatewayProvider.overrideWithValue(gateway),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const Key('open-actual-contributions'),
                onPressed: () => showActualContributionSheet(
                  context,
                  expectedProfileId: 'user-1',
                  membershipId: 'membership-1',
                  editable: editable,
                  participantDisplayName: editable ? 'Jordan' : null,
                ),
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
