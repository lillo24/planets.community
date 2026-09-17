import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/domain/project_resource_need_models.dart';
import 'package:planets_mobile/features/project_resource_needs/presentation/project_resource_needs_screen.dart';
import 'package:planets_mobile/features/project_resource_needs/presentation/project_resource_needs_section.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_resource_needs.dart';

void main() {
  testWidgets('public failure is local and retry renders open need chips', (
    tester,
  ) async {
    final gateway = FakeProjectResourceNeedsGateway()
      ..error = StateError('private diagnostic');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectResourceNeedsGatewayProvider.overrideWithValue(gateway),
        ],
        child: _localized(
          Scaffold(
            body: ListView(
              children: const [
                Text('Project body remains available'),
                ProjectResourceNeedsSection(projectId: 'proposal-1'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Project body remains available'), findsOneWidget);
    expect(
      find.byKey(const Key('project-resource-needs-error')),
      findsOneWidget,
    );

    gateway
      ..error = null
      ..publicItems = [
        publicProjectResourceNeedFixture(id: 'paint', title: 'Exterior paint'),
      ];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('public-resource-need-paint')), findsOneWidget);
    expect(find.text('Exterior paint'), findsWidgets);
  });

  testWidgets(
    'owner adds, edits, and closes while closed history is read-only',
    (tester) async {
      final gateway = FakeProjectResourceNeedsGateway()
        ..ownItems = [
          projectResourceNeedFixture(id: 'open', title: 'Paint'),
          projectResourceNeedFixture(
            id: 'closed',
            title: 'Old ladder',
            state: ProjectResourceNeedState.closed,
          ),
        ];
      gateway.publicItems = [publicProjectResourceNeedFixture(id: 'open')];
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      final container = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(auth),
          projectResourceNeedsGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(auth.close);
      addTearDown(container.dispose);
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-1'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _localized(
            const ProjectResourceNeedsScreen(
              projectId: 'proposal-1',
              projectKind: ProjectKind.oneTime,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('project-resource-edit-open')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('project-resource-edit-closed')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('project-resource-closed-closed')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('project-resource-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('project-resource-title')),
        'Wooden boards',
      );
      await tester.tap(find.byKey(const Key('project-resource-save')));
      await tester.pumpAndSettle();
      expect(gateway.calls, contains('create:proposal-1'));
      expect(find.text('Wooden boards'), findsOneWidget);

      await tester.tap(find.byKey(const Key('project-resource-edit-open')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('project-resource-title')),
        'Exterior paint',
      );
      await tester.tap(find.byKey(const Key('project-resource-save')));
      await tester.pumpAndSettle();
      expect(gateway.calls, contains('update:open'));

      await tester.tap(find.byKey(const Key('project-resource-close-open')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'does not record that it was supplied or fulfilled',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('project-resource-confirm-close')));
      await tester.pumpAndSettle();
      expect(gateway.calls, contains('close:open'));
      expect(
        find.byKey(const Key('project-resource-closed-open')),
        findsOneWidget,
      );
    },
  );
}

Widget _localized(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
