import 'dart:async';

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
import 'package:planets_mobile/features/project_workspace/application/project_workspace_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/presentation/project_workspace_screen.dart';
import 'package:planets_mobile/features/project_workspace/presentation/project_workspace_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_project_workspace.dart';

void main() {
  for (final locale in ['en', 'it']) {
    for (final manager in [false, true]) {
      testWidgets(
        '$locale 320px 2x collection supports long names, many links and ${manager ? "manager" : "member"} actions',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final workspace = FakeProjectWorkspaceGateway()
            ..links.addAll(
              List.generate(
                12,
                (i) => projectWorkspaceFixture(
                  id: 'link-$i',
                  projectId: 'project-1',
                  name:
                      'Documento organizzazione molto lungo ${'materiali ' * 8}$i',
                ),
              ),
            );
          final delegates = FakeProjectDelegateGateway()
            ..role = manager
                ? ProjectManagementRole.creator
                : ProjectManagementRole.none;
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
                locale: locale,
                scale: 2,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('workspace-link-link-0')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('workspace-edit-link-0')),
            manager ? findsOneWidget : findsNothing,
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('workspace-link-link-11')),
            400,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('manager edits/removes one item and cancels individual removal', (
    tester,
  ) async {
    final workspace = FakeProjectWorkspaceGateway()
      ..links.addAll([
        projectWorkspaceFixture(
          id: 'a',
          projectId: 'project-1',
          name: 'Documento',
        ),
        projectWorkspaceFixture(
          id: 'b',
          projectId: 'project-1',
          name: 'Budget',
        ),
      ]);
    final session = _readyContainer(
      workspace,
      FakeProjectDelegateGateway()..role = ProjectManagementRole.creator,
    );
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
    await tester.tap(find.byKey(const ValueKey('workspace-edit-b')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('project-workspace-name-field')),
      'Sheet Budget',
    );
    await tester.tap(find.byKey(const Key('project-workspace-save')));
    await tester.pumpAndSettle();
    expect(workspace.links.map((x) => x.name), ['Documento', 'Sheet Budget']);
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.byKey(const ValueKey('workspace-remove-a')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Documento'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(workspace.links, hasLength(2));
    await tester.tap(find.byKey(const ValueKey('workspace-remove-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-workspace-confirm-remove')));
    await tester.pumpAndSettle();
    expect(workspace.links.single.name, 'Sheet Budget');
  });
  testWidgets('loading and error are distinct from empty and Retry recovers', (
    tester,
  ) async {
    final pending = Completer<void>();
    final workspace = FakeProjectWorkspaceGateway()..readDelay = pending.future;
    final session = _readyContainer(workspace, FakeProjectDelegateGateway());
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
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No links shared yet.'), findsNothing);
    workspace.readError = StateError('private');
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('information is unavailable'), findsOneWidget);
    expect(find.text('No links shared yet.'), findsNothing);
    workspace.readDelay = null;
    workspace.readError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No links shared yet.'), findsOneWidget);
  });
  testWidgets('pending save disables fields, add, cancel and Save', (
    tester,
  ) async {
    final pending = Completer<void>();
    final workspace = FakeProjectWorkspaceGateway()
      ..mutationDelay = pending.future;
    final session = _readyContainer(
      workspace,
      FakeProjectDelegateGateway()..role = ProjectManagementRole.creator,
    );
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
    await tester.tap(find.byKey(const Key('project-workspace-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('project-workspace-name-field')),
      'Doc',
    );
    await tester.enterText(
      find.byKey(const Key('project-workspace-url-field')),
      'https://example.org',
    );
    await tester.tap(find.byKey(const Key('project-workspace-save')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('project-workspace-save')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('project-workspace-name-field')),
          )
          .enabled,
      isFalse,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(workspace.links, hasLength(1));
  });
  testWidgets('external confirmation rechecks entitlement before launch', (
    tester,
  ) async {
    final workspace = FakeProjectWorkspaceGateway()
      ..workspace = projectWorkspaceFixture(projectId: 'project-1');
    final launcher = FakeProjectWorkspaceLauncher();
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
    workspace.readError = const PostgrestException(
      message: 'private',
      code: '42501',
    );
    await tester.tap(find.byKey(const Key('project-workspace-confirm-open')));
    await tester.pumpAndSettle();
    expect(launcher.calls, 0);
    expect(find.text('drive.google.com'), findsNothing);
    expect(session.container.read(projectWorkspaceProvider).links, isEmpty);
  });
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

    await tester.tap(find.byKey(const Key('project-workspace-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('project-workspace-name-field')),
      'Documento',
    );
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
    expect(find.text('Link saved.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.byKey(const Key('workspace-remove-link-1')));
    await tester.pumpAndSettle();
    expect(find.text('Remove this link?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('project-workspace-confirm-remove')));
    await tester.pumpAndSettle();
    expect(workspace.workspace, isNull);
    expect(find.text('Link removed.'), findsOneWidget);
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

    expect(find.text('No links shared yet.'), findsOneWidget);
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

      await tester.tap(find.byKey(const Key('project-workspace-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('project-workspace-name-field')),
        'Budget',
      );
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

  testWidgets('Project Manage card opens the existing collection route', (
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

    expect(find.text('No links shared yet.'), findsOneWidget);
    expect(find.byKey(const Key('project-workspace-add')), findsNothing);
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

    expect(find.byKey(const Key('project-workspace-add')), findsOneWidget);
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

Widget _localized(Widget child, {String locale = 'en', double scale = 1}) =>
    MaterialApp(
      locale: Locale(locale),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
