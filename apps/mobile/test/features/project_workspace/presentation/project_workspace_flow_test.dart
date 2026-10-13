import '../../../support/fake_policy.dart';
import '../../../support/rendered_evidence.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/policies/application/policy_documents.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';
import 'package:planets_mobile/features/policies/presentation/policy_acceptance_screen.dart';
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
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_pending_add_store.dart';
import 'package:planets_mobile/features/project_workspace/presentation/project_workspace_screen.dart';
import 'package:planets_mobile/features/project_workspace/presentation/project_workspace_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_project_workspace.dart';

void main() {
  setUpAll(RenderedEvidence.loadFonts);
  for (final locale in ['en', 'it']) {
    for (final dark in [false, true]) {
      testWidgets('A04 recovery controls $locale dark=$dark 320dp/2x', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final workspace = FakeProjectWorkspaceGateway()
          ..loseNextAddReply = true;
        final session = _readyContainer(
          workspace,
          FakeProjectDelegateGateway()..role = ProjectManagementRole.creator,
        );
        addTearDown(session.dispose);
        await _pumpWorkspace(
          tester,
          session.container,
          locale: locale,
          scale: 2,
          dark: dark,
        );
        await _tapWorkspace(
          tester,
          find.byKey(const Key('project-workspace-add')),
        );
        await tester.enterText(
          find.byKey(const Key('project-workspace-name-field')),
          locale == 'it' ? 'Documento condiviso' : 'Shared document',
        );
        await tester.enterText(
          find.byKey(const Key('project-workspace-url-field')),
          'https://docs.example.invalid/retained',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await _tapWorkspace(
          tester,
          find.byKey(const Key('project-workspace-save')),
        );
        expect(
          find.byKey(const Key('project-workspace-save')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('project-workspace-editor-check')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.text(locale == 'it' ? 'Chiudi' : 'Close').hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await RenderedEvidence.capture(
          tester,
          'a04-recovery-$locale-${dark ? 'dark' : 'light'}-320-2x',
        );
        await _tapWorkspace(
          tester,
          find.byKey(const Key('project-workspace-editor-check')),
        );
        expect(workspace.requestIds, hasLength(1));
        expect(workspace.links, hasLength(1));
      });
    }
  }
  testWidgets(
    'Load more and page retry require explicit actions and preserve rows',
    (tester) async {
      final workspace = FakeProjectWorkspaceGateway()
        ..links.addAll(
          List.generate(
            25,
            (i) => projectWorkspaceFixture(
              id: 'id-${i.toString().padLeft(2, '0')}',
              projectId: 'project-1',
            ),
          ),
        );
      final session = _readyContainer(workspace, FakeProjectDelegateGateway());
      addTearDown(session.dispose);
      await _pumpWorkspace(tester, session.container);
      expect(
        session.container.read(projectWorkspaceProvider).links,
        hasLength(10),
      );
      workspace.pageError = StateError('offline');
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-load-more')),
      );
      expect(
        session.container.read(projectWorkspaceProvider).links,
        hasLength(10),
      );
      expect(find.text('Try loading more again'), findsOneWidget);
      final count = workspace.calls.length;
      await tester.pump(const Duration(seconds: 2));
      expect(workspace.calls, hasLength(count));
      workspace.pageError = null;
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-load-more')),
      );
      expect(
        session.container.read(projectWorkspaceProvider).links,
        hasLength(20),
      );
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-load-more')),
      );
      expect(
        session.container.read(projectWorkspaceProvider).links,
        hasLength(25),
      );
      expect(
        find.byKey(const Key('project-workspace-load-more')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'lost Add response is frozen; explicit status check confirms one item',
    (tester) async {
      final workspace = FakeProjectWorkspaceGateway()..loseNextAddReply = true;
      final session = _readyContainer(
        workspace,
        FakeProjectDelegateGateway()..role = ProjectManagementRole.creator,
      );
      addTearDown(session.dispose);
      await _pumpWorkspace(tester, session.container);
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-add')),
      );
      await tester.enterText(
        find.byKey(const Key('project-workspace-name-field')),
        'Kept document',
      );
      await tester.enterText(
        find.byKey(const Key('project-workspace-url-field')),
        'https://docs.example.invalid/kept',
      );
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-save')),
      );
      expect(workspace.links, hasLength(1));
      // A cached empty page cannot describe the result of an unresolved Add.
      expect(find.text('No links shared yet.'), findsNothing);
      expect(find.textContaining("Couldn't confirm this link"), findsOneWidget);
      final field = find.descendant(
        of: find.byKey(const Key('project-workspace-url-field')),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).readOnly, isTrue);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('project-workspace-url-field')),
            )
            .controller!
            .text,
        'https://docs.example.invalid/kept',
      );
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-editor-check')),
      );
      expect(find.text('Link saved.'), findsOneWidget);
      expect(workspace.requestIds, hasLength(1));
      expect(workspace.links, hasLength(1));
    },
  );

  testWidgets(
    'recreated UI restores outstanding Add before permitting a new one',
    (tester) async {
      final workspace = FakeProjectWorkspaceGateway()..loseNextAddReply = true;
      final pending = FakeWorkspacePendingAddStore();
      final first = _readyContainer(
        workspace,
        FakeProjectDelegateGateway()..role = ProjectManagementRole.creator,
        pending: pending,
      );
      addTearDown(first.dispose);
      await _pumpWorkspace(tester, first.container);
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-add')),
      );
      await tester.enterText(
        find.byKey(const Key('project-workspace-name-field')),
        'Restart document',
      );
      await tester.enterText(
        find.byKey(const Key('project-workspace-url-field')),
        'https://docs.example.invalid/restart',
      );
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-save')),
      );
      final request = workspace.requestIds.single;
      await tester.pumpWidget(const SizedBox());
      final restarted = _readyContainer(
        workspace,
        FakeProjectDelegateGateway()..role = ProjectManagementRole.creator,
        pending: pending,
      );
      addTearDown(restarted.dispose);
      await _pumpWorkspace(tester, restarted.container);
      expect(
        find.textContaining('An earlier link may have been added'),
        findsOneWidget,
      );
      expect(find.text('Review previous link'), findsOneWidget);
      expect(workspace.requestIds, [request]);
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-add')),
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('project-workspace-name-field')),
            )
            .controller!
            .text,
        'Restart document',
      );
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-editor-check')),
      );
      expect(workspace.requestIds, [request]);
      expect(pending.values, isEmpty);
    },
  );

  testWidgets(
    'a changed URL is reconfirmed before opening its canonical destination',
    (tester) async {
      final workspace = FakeProjectWorkspaceGateway()
        ..workspace = projectWorkspaceFixture(projectId: 'project-1');
      final launcher = FakeProjectWorkspaceLauncher();
      final session = _readyContainer(
        workspace,
        FakeProjectDelegateGateway(),
        launcher: launcher,
      );
      addTearDown(session.dispose);
      await _pumpWorkspace(tester, session.container);
      await _tapWorkspace(
        tester,
        find.byKey(const ValueKey('workspace-open-link-1')),
      );
      workspace.workspace = projectWorkspaceFixture(
        projectId: 'project-1',
        version: 2,
        url: 'https://changed.example.invalid/current',
      );
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-confirm-open')),
      );
      expect(launcher.calls, 0);
      expect(
        find.textContaining('Confirm the current destination'),
        findsOneWidget,
      );
      expect(find.textContaining('changed.example.invalid'), findsWidgets);
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-confirm-open')),
      );
      expect(launcher.calls, 1);
      expect(launcher.opened!.value, 'https://changed.example.invalid/current');
      expect(
        workspace.calls.where((call) => call.startsWith('item:')),
        hasLength(2),
      );
    },
  );

  testWidgets(
    'A-B-A during hostname confirmation removes old private content and callbacks',
    (tester) async {
      final workspace = FakeProjectWorkspaceGateway()
        ..workspace = projectWorkspaceFixture(projectId: 'project-1');
      final launcher = FakeProjectWorkspaceLauncher();
      final session = _readyContainer(
        workspace,
        FakeProjectDelegateGateway(),
        launcher: launcher,
      );
      addTearDown(session.dispose);
      await _pumpWorkspace(tester, session.container);
      await _tapWorkspace(
        tester,
        find.byKey(const ValueKey('workspace-open-link-1')),
      );
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const Key('project-workspace-confirm-host')),
        findsNothing,
      );
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const Key('project-workspace-confirm-open')),
        findsNothing,
      );
      expect(launcher.calls, 0);
    },
  );

  testWidgets(
    'remove confirmation cannot delete a concurrently changed version',
    (tester) async {
      final workspace = FakeProjectWorkspaceGateway()
        ..workspace = projectWorkspaceFixture(projectId: 'project-1');
      final session = _readyContainer(
        workspace,
        FakeProjectDelegateGateway()..role = ProjectManagementRole.creator,
      );
      addTearDown(session.dispose);
      await _pumpWorkspace(tester, session.container);
      await _tapWorkspace(
        tester,
        find.byKey(const ValueKey('workspace-remove-link-1')),
      );
      final old = workspace.links.single;
      await workspace.saveLink(
        expectedManagerProfileId: 'other-manager',
        projectId: 'project-1',
        name: 'Changed by another manager',
        url: old.url,
        linkId: old.id,
        expectedVersion: old.version,
      );
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-confirm-remove')),
      );
      expect(workspace.links.single.name, 'Changed by another manager');
      expect(
        session.container.read(projectWorkspaceProvider).failure,
        ProjectWorkspaceFailureKind.conflict,
      );
      expect(find.textContaining('This link changed'), findsWidgets);
      expect(find.text('Link removed.'), findsNothing);
    },
  );

  testWidgets(
    'policy review retains unsent input and action without automatic submission',
    (tester) async {
      final workspace = FakeProjectWorkspaceGateway();
      final policies = FakePolicyAcceptanceStore();
      final session = _readyContainer(
        workspace,
        FakeProjectDelegateGateway()..role = ProjectManagementRole.creator,
        policies: policies,
      );
      policies.versions['user-1'] = session.container.read(
        policyVersionProvider,
      );
      addTearDown(session.dispose);
      await _pumpWorkspace(tester, session.container);
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-add')),
      );
      await tester.enterText(
        find.byKey(const Key('project-workspace-name-field')),
        'Policy document',
      );
      await tester.enterText(
        find.byKey(const Key('project-workspace-url-field')),
        'https://docs.example.invalid/policy',
      );
      final controller = session.container.read(
        projectWorkspaceProvider.notifier,
      );
      final request = controller
          .beginDraft('user-1', 'project-1', null)
          .requestId;
      policies.versions.clear();
      await session.container
          .read(policyAcceptanceProvider.notifier)
          .retryRead();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('project-workspace-save')),
            )
            .onPressed,
        isNull,
      );
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-review-policy')),
      );
      expect(find.byType(PolicyAcceptanceScreen), findsOneWidget);
      expect(workspace.requestIds, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('project-workspace-name-field')),
            )
            .controller!
            .text,
        'Policy document',
      );
      expect(
        controller.beginDraft('user-1', 'project-1', null).requestId,
        request,
      );
      policies.versions['user-1'] = session.container.read(
        policyVersionProvider,
      );
      await session.container
          .read(policyAcceptanceProvider.notifier)
          .retryRead();
      await tester.pumpAndSettle();
      expect(workspace.requestIds, isEmpty);
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-save')),
      );
      expect(workspace.requestIds, [request]);
    },
  );

  testWidgets(
    'route disposal retains an unsent draft and its original action',
    (tester) async {
      final workspace = FakeProjectWorkspaceGateway();
      final session = _readyContainer(
        workspace,
        FakeProjectDelegateGateway()..role = ProjectManagementRole.creator,
      );
      addTearDown(session.dispose);
      await _pumpWorkspace(tester, session.container);
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-add')),
      );
      await tester.enterText(
        find.byKey(const Key('project-workspace-name-field')),
        'Route document',
      );
      await tester.enterText(
        find.byKey(const Key('project-workspace-url-field')),
        'https://docs.example.invalid/route',
      );
      final controller = session.container.read(
        projectWorkspaceProvider.notifier,
      );
      final request = controller
          .beginDraft('user-1', 'project-1', null)
          .requestId;
      await tester.pumpWidget(const SizedBox());
      await _pumpWorkspace(tester, session.container);
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-add')),
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('project-workspace-name-field')),
            )
            .controller!
            .text,
        'Route document',
      );
      expect(
        controller.beginDraft('user-1', 'project-1', null).requestId,
        request,
      );
      expect(workspace.requestIds, isEmpty);
      await _tapWorkspace(
        tester,
        find.byKey(const Key('project-workspace-save')),
      );
      expect(workspace.requestIds, [request]);
    },
  );
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
            ..canManage = manager
            ..links.addAll(
              List.generate(
                12,
                (i) => projectWorkspaceFixture(
                  id: 'link-$i',
                  createdAt: DateTime.utc(2030).add(Duration(seconds: i)),
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
          // Reads are now bounded. Older links appear only after explicit paging.
          expect(
            session.container.read(projectWorkspaceProvider).links,
            hasLength(10),
          );
          expect(
            find.byKey(const ValueKey('workspace-link-link-0')),
            findsNothing,
          );
          final more = find.byKey(const Key('project-workspace-load-more'));
          await tester.ensureVisible(more);
          await tester.pumpAndSettle();
          await tester.tap(more);
          await tester.pumpAndSettle();
          expect(
            session.container.read(projectWorkspaceProvider).links,
            hasLength(12),
          );
          expect(
            find.byKey(const ValueKey('workspace-link-link-0')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('workspace-edit-link-0')),
            manager ? findsOneWidget : findsNothing,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('workspace-link-link-11')),
          );
          await tester.pumpAndSettle();
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

      expect(find.textContaining("Couldn't confirm this link"), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('project-workspace-url-field')),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      expect(
        find.byKey(const Key('project-workspace-editor-check')),
        findsOneWidget,
      );
      expect(find.textContaining('private provider diagnostic'), findsNothing);
    },
  );

  testWidgets('Project Manage keeps the compact collection destination', (
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
    final destination = tester.widget<ListTile>(
      find.byKey(const Key('project-manage-workspace')),
    );
    expect(destination.onTap, isNotNull);
    expect(
      find.byKey(const Key('project-manage-workspace-edit')),
      findsNothing,
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
  FakeWorkspacePendingAddStore? pending,
  FakePolicyAcceptanceStore? policies,
}) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      policyAcceptanceStoreProvider.overrideWithValue(
        policies ?? FakePolicyAcceptanceStore(preaccepted: true),
      ),
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      projectWorkspacePendingAddStoreProvider.overrideWithValue(
        pending ?? FakeWorkspacePendingAddStore(),
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

Widget _localized(
  Widget child, {
  String locale = 'en',
  double scale = 1,
  bool dark = false,
}) => RenderedEvidence.wrap(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.dark : AppTheme.light,
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
  ),
);

Future<void> _pumpWorkspace(
  WidgetTester tester,
  ProviderContainer container, {
  String locale = 'en',
  double scale = 1,
  bool dark = false,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _localized(
        const ProjectWorkspaceScreen(
          projectId: 'project-1',
          projectKind: ProjectKind.oneTime,
        ),
        locale: locale,
        scale: scale,
        dark: dark,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapWorkspace(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
