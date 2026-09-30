import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/project_delegates/presentation/project_manage_screen.dart';
import 'package:planets_mobile/features/project_workspace/application/project_workspace_launcher.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/presentation/project_workspace_screen.dart';
import 'package:planets_mobile/features/project_workspace/presentation/project_workspace_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_project_workspace.dart';

void main() {
  testWidgets('manager validates, saves, and removes provider-neutral links', (
    tester,
  ) async {
    final workspace = FakeProjectWorkspaceGateway();
    final delegates = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.coOrganizer;
    final session = _readyContainer(workspace, delegates);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectWorkspaceScreen(
            projectId: 'project-1',
            projectKind: ProjectKind.oneTime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('project-workspace-url-field')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('project-workspace-url-field')),
      'http://docs.example.org/team',
    );
    await tester.tap(find.byKey(const Key('project-workspace-save')));
    await tester.pump();
    expect(find.textContaining('valid HTTPS link'), findsOneWidget);
    expect(workspace.calls.where((call) => call.startsWith('set:')), isEmpty);

    await tester.enterText(
      find.byKey(const Key('project-workspace-url-field')),
      'not a URL',
    );
    await tester.tap(find.byKey(const Key('project-workspace-save')));
    await tester.pump();
    expect(find.text('Enter a valid workspace link.'), findsOneWidget);
    expect(workspace.calls.where((call) => call.startsWith('set:')), isEmpty);

    await tester.enterText(
      find.byKey(const Key('project-workspace-url-field')),
      'https://docs.example.org/team',
    );
    await tester.tap(find.byKey(const Key('project-workspace-save')));
    await tester.pumpAndSettle();
    expect(workspace.workspace?.url.hostname, 'docs.example.org');
    expect(find.text('Shared workspace saved.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.byKey(const Key('project-workspace-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Remove shared workspace?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('project-workspace-confirm-remove')));
    await tester.pumpAndSettle();
    expect(workspace.workspace, isNull);
    expect(find.text('Shared workspace removed.'), findsOneWidget);
  });

  testWidgets('workspace editor fails closed after authorization loss', (
    tester,
  ) async {
    final workspace = FakeProjectWorkspaceGateway();
    final delegates = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.none;
    final session = _readyContainer(workspace, delegates);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectWorkspaceScreen(
            projectId: 'project-1',
            projectKind: ProjectKind.recurring,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('information is unavailable'), findsOneWidget);
    expect(find.byKey(const Key('project-workspace-save')), findsNothing);
  });

  testWidgets(
    'workspace editor reports mutation failures without diagnostics',
    (tester) async {
      final workspace = FakeProjectWorkspaceGateway()
        ..mutationError = StateError('private provider diagnostic');
      final delegates = FakeProjectDelegateGateway()
        ..role = ProjectManagementRole.creator;
      final session = _readyContainer(workspace, delegates);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: session.container,
          child: _localized(
            const ProjectWorkspaceScreen(
              projectId: 'project-1',
              projectKind: ProjectKind.oneTime,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('project-workspace-url-field')),
        'https://docs.example.org/team',
      );
      await tester.tap(find.byKey(const Key('project-workspace-save')));
      await tester.pumpAndSettle();

      expect(find.textContaining('information is unavailable'), findsOneWidget);
      expect(find.textContaining('private provider diagnostic'), findsNothing);
    },
  );

  testWidgets('configured Project Manage card exposes Open and Edit', (
    tester,
  ) async {
    final workspace = FakeProjectWorkspaceGateway()
      ..workspace = projectWorkspaceFixture(projectId: 'project-1');
    final delegates = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.creator;
    final session = _readyContainer(workspace, delegates);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectManageScreen(
            projectId: 'project-1',
            projectKind: ProjectKind.oneTime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('drive.google.com'), findsOneWidget);
    expect(
      find.byKey(const Key('project-manage-workspace-open')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('project-manage-workspace-edit')),
      findsOneWidget,
    );
  });

  testWidgets(
    'external confirmation shows hostname and Cancel does not launch',
    (tester) async {
      final workspace = FakeProjectWorkspaceGateway()
        ..workspace = projectWorkspaceFixture(projectId: 'project-1');
      final launcher = FakeProjectWorkspaceLauncher();
      final delegates = FakeProjectDelegateGateway();
      final session = _readyContainer(workspace, delegates, launcher: launcher);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: session.container,
          child: _localized(
            const ProjectWorkspaceInfoSection(
              expectedProfileId: 'user-1',
              projectId: 'project-1',
              projectKind: ProjectKind.oneTime,
              isManager: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('drive.google.com'));
      await tester.pumpAndSettle();
      expect(find.textContaining('drive.google.com'), findsWidgets);
      expect(find.textContaining('private-token'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(launcher.calls, 0);

      await tester.tap(find.text('drive.google.com'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('project-workspace-confirm-open')));
      await tester.pumpAndSettle();
      expect(launcher.calls, 1);
      expect(
        launcher.opened?.value,
        'https://drive.google.com/drive/folders/private-token',
      );
    },
  );

  testWidgets('launch failure exposes safe localized feedback', (tester) async {
    final workspace = FakeProjectWorkspaceGateway()
      ..workspace = projectWorkspaceFixture(projectId: 'project-1');
    final launcher = FakeProjectWorkspaceLauncher()..result = false;
    final session = _readyContainer(
      workspace,
      FakeProjectDelegateGateway(),
      launcher: launcher,
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectWorkspaceInfoSection(
            expectedProfileId: 'user-1',
            projectId: 'project-1',
            projectKind: ProjectKind.oneTime,
            isManager: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('drive.google.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-workspace-confirm-open')));
    await tester.pumpAndSettle();

    expect(
      find.text('The external workspace could not be opened.'),
      findsOneWidget,
    );
    expect(find.textContaining('private-token'), findsNothing);
  });

  testWidgets('participant without a link sees a neutral Group info state', (
    tester,
  ) async {
    final workspace = FakeProjectWorkspaceGateway();
    final session = _readyContainer(workspace, FakeProjectDelegateGateway());
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectWorkspaceInfoSection(
            expectedProfileId: 'user-1',
            projectId: 'project-1',
            projectKind: ProjectKind.oneTime,
            isManager: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No shared workspace link has been added.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('project-workspace-info-add')), findsNothing);
  });

  testWidgets('manager without a link can add one from Group info', (
    tester,
  ) async {
    final workspace = FakeProjectWorkspaceGateway();
    final session = _readyContainer(workspace, FakeProjectDelegateGateway());
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectWorkspaceInfoSection(
            expectedProfileId: 'user-1',
            projectId: 'project-1',
            projectKind: ProjectKind.oneTime,
            isManager: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('project-workspace-info-add')), findsOneWidget);
  });
}

({ProviderContainer container, void Function() dispose}) _readyContainer(
  FakeProjectWorkspaceGateway workspace,
  FakeProjectDelegateGateway delegates, {
  FakeProjectWorkspaceLauncher? launcher,
}) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      projectWorkspaceGatewayProvider.overrideWithValue(workspace),
      projectDelegateGatewayProvider.overrideWithValue(delegates),
      if (launcher != null)
        projectWorkspaceLauncherProvider.overrideWithValue(launcher),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return (
    container: container,
    dispose: () {
      container.dispose();
      auth.close();
    },
  );
}

Widget _localized(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
