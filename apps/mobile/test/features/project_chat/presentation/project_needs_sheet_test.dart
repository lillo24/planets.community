import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/project_chat/application/project_needs_controller.dart';
import 'package:planets_mobile/features/project_chat/data/project_needs_gateway.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';
import 'package:planets_mobile/features/project_chat/domain/project_needs_models.dart';
import 'package:planets_mobile/features/project_chat/presentation/project_needs_sheet.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_needs.dart';

void main() {
  testWidgets('all covered kinds precede active kinds and look completed', (
    tester,
  ) async {
    final gateway = FakeProjectNeedsGateway()..requirements = _mixedNeeds();
    await _pump(tester, gateway);
    final coveredSkill = _card('skill:covered-skill');
    final coveredResource = _card('resource:covered-resource');
    final activeSkill = _card('skill:active-skill');
    final activeResource = _card('resource:active-resource');
    final lastCovered = tester.getBottomLeft(coveredResource).dy;
    expect(tester.getTopLeft(coveredSkill).dy, lessThan(lastCovered));
    expect(lastCovered, lessThan(tester.getTopLeft(activeSkill).dy));
    expect(lastCovered, lessThan(tester.getTopLeft(activeResource).dy));
    expect(find.text('Needed now'), findsNothing);
    expect(find.text('Needed again'), findsNothing);
    expect(find.text('Covered'), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(2));
    expect(find.text('Useful'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    final coveredLabel = tester.element(find.text('Covered skill'));
    final theme = Theme.of(coveredLabel);
    expect(
      DefaultTextStyle.of(coveredLabel).style.color,
      theme.colorScheme.onSurfaceVariant,
    );
    expect(
      tester.widget<Card>(coveredSkill).color,
      theme.colorScheme.surfaceContainerLow,
    );
    expect(
      find.descendant(of: coveredSkill, matching: find.byType(FilledButton)),
      findsNothing,
    );
    expect(find.byTooltip('Mark as needed'), findsNothing);
    expect(find.text('I can help'), findsOneWidget);
    expect(find.text('I can bring it'), findsOneWidget);
    await tester.ensureVisible(find.text('I can bring it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I can bring it'));
    await tester.pumpAndSettle();
    expect(gateway.calls, contains('claim:resource:active-resource'));
    expect(find.text('Active resource'), findsOneWidget);
    expect(find.text('I can bring it'), findsNothing);
  });

  testWidgets(
    'canonical uncovered refresh returns a completed item to active',
    (tester) async {
      final gateway = FakeProjectNeedsGateway()
        ..requirements = [
          projectRequirementFixture(
            id: 'changed',
            label: 'Changed need',
            isCovered: true,
          ),
          projectRequirementFixture(
            id: 'retained',
            label: 'Retained need',
            isCovered: true,
          ),
        ];
      final container = await _pump(tester, gateway);
      expect(find.text('All needs are covered.'), findsOneWidget);
      gateway.requirements = [
        projectRequirementFixture(id: 'changed', label: 'Changed need'),
        gateway.requirements.last,
      ];
      container.read(projectNeedsProvider.notifier).handleRequirementSignal();
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(_card('skill:retained')).dy,
        lessThan(tester.getTopLeft(_card('skill:changed')).dy),
      );
      expect(find.text('All needs are covered.'), findsNothing);
      expect(find.text('Needed again'), findsNothing);
      expect(
        find.descendant(
          of: _card('skill:changed'),
          matching: find.text('I can help'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _card('skill:changed'),
          matching: find.text('Covered'),
        ),
        findsNothing,
      );
    },
  );

  for (final role in [
    ProjectChatViewerRole.creator,
    ProjectChatViewerRole.delegate,
  ]) {
    testWidgets('$role reverses only manual coverage through subtle undo', (
      tester,
    ) async {
      final gateway = FakeProjectNeedsGateway()..requirements = _mixedNeeds();
      await _pump(tester, gateway, role: role);
      final undo = find.byKey(
        const Key('project-need-reopen-resource:covered-resource'),
      );
      expect(find.byTooltip('Mark as needed'), findsOneWidget);
      expect(
        find.byKey(const Key('project-need-reopen-skill:covered-skill')),
        findsNothing,
      );
      final semantics = tester.ensureSemantics();
      await tester.ensureVisible(undo);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(undo).getSemanticsData().tooltip,
        'Mark as needed',
      );
      semantics.dispose();
      expect(find.text('Needed again'), findsNothing);
      expect(find.text('I can help'), findsNothing);
      expect(find.text('Found outside app'), findsNWidgets(2));
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(gateway.calls, contains('manual:resource:covered-resource:false'));
      expect(find.byTooltip('Mark as needed'), findsNothing);
      expect(
        find.descendant(
          of: _card('resource:covered-resource'),
          matching: find.text('Found outside app'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(_card('skill:covered-skill')).dy,
        lessThan(tester.getTopLeft(_card('resource:covered-resource')).dy),
      );
    });
  }

  for (final locale in ['en', 'it']) {
    testWidgets(
      'all-covered copy and completed items remain visible in $locale',
      (tester) async {
        final gateway = FakeProjectNeedsGateway()
          ..requirements = [projectRequirementFixture(isCovered: true)];
        await _pump(tester, gateway, locale: locale);
        expect(find.text(locale == 'it' ? 'Bisogni' : 'Needs'), findsOneWidget);
        expect(
          find.text(
            locale == 'it'
                ? 'Tutti i bisogni sono coperti.'
                : 'All needs are covered.',
          ),
          findsOneWidget,
        );
        expect(find.text('Painting'), findsOneWidget);
        expect(
          find.text(locale == 'it' ? 'Coperto' : 'Covered'),
          findsOneWidget,
        );
        expect(find.byType(FilledButton), findsNothing);
      },
    );
    for (final brightness in Brightness.values) {
      for (final role in [
        ProjectChatViewerRole.currentMember,
        ProjectChatViewerRole.delegate,
      ]) {
        testWidgets('320px and 2x text: $locale $brightness $role', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final gateway = FakeProjectNeedsGateway()
            ..requirements = [
              projectRequirementFixture(
                id: 'covered',
                label: 'Already provided competence with a long label',
                isCovered: true,
                isManuallyCovered: true,
              ),
              projectRequirementFixture(
                id: 'active',
                label: 'Still needed competence with a long label',
              ),
            ];
          await _pump(
            tester,
            gateway,
            locale: locale,
            scale: 2,
            brightness: brightness,
            role: role,
          );
          final active = _card('skill:active');
          await tester.ensureVisible(active);
          await tester.pumpAndSettle();
          final label = find.descendant(
            of: active,
            matching: find.text('Still needed competence with a long label'),
          );
          final button = find.descendant(
            of: active,
            matching: find.byType(FilledButton),
          );
          expect(
            tester.getBottomLeft(label).dy,
            lessThan(tester.getTopLeft(button).dy),
          );
          expect(
            tester.getRect(button).left,
            greaterThanOrEqualTo(tester.getRect(active).left),
          );
          expect(
            tester.getRect(button).right,
            lessThanOrEqualTo(tester.getRect(active).right),
          );
          expect(
            find.text(locale == 'it' ? 'Necessari ora' : 'Needed now'),
            findsNothing,
          );
          expect(
            find.text(locale == 'it' ? 'Necessari di nuovo' : 'Needed again'),
            findsNothing,
          );
          expect(
            find.byTooltip(
              locale == 'it' ? 'Segna come necessario' : 'Mark as needed',
            ),
            role == ProjectChatViewerRole.delegate
                ? findsOneWidget
                : findsNothing,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

Finder _card(String key) => find.byKey(Key('project-need-$key'));

List<ProjectLiveRequirement> _mixedNeeds() => [
  projectRequirementFixture(
    kind: ProjectRequirementKind.resource,
    id: 'active-resource',
    label: 'Active resource',
  ),
  projectRequirementFixture(id: 'active-skill', label: 'Active skill'),
  projectRequirementFixture(
    kind: ProjectRequirementKind.resource,
    id: 'covered-resource',
    label: 'Covered resource',
    isCovered: true,
    isManuallyCovered: true,
  ),
  projectRequirementFixture(
    id: 'covered-skill',
    label: 'Covered skill',
    isCovered: true,
    importance: ProjectRequirementImportance.useful,
  ),
];

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeProjectNeedsGateway gateway, {
  ProjectChatViewerRole role = ProjectChatViewerRole.currentMember,
  String locale = 'en',
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final auth = FakeAuthGateway();
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      projectNeedsGatewayProvider.overrideWithValue(gateway),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await auth.close();
  });
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  await container
      .read(projectNeedsProvider.notifier)
      .load(
        expectedProfileId: 'user-1',
        projectId: 'proposal-1',
        chatId: 'chat-1',
        viewerRole: role,
      );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(locale),
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showProjectNeedsSheet(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return container;
}
