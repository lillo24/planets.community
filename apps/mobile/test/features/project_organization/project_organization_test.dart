import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/project_organization/application/project_organization_controller.dart';
import 'package:planets_mobile/features/project_organization/data/project_organization_gateway.dart';
import 'package:planets_mobile/features/project_organization/domain/project_organization.dart';
import 'package:planets_mobile/features/project_organization/presentation/project_organization_sheet.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../test_support/check01_fixture.dart';
import '../../support/fake_auth.dart';

class _Gateway implements ProjectOrganizationGateway {
  ProjectOrganization snapshot = organizationFixture();
  Completer<ProjectOrganization>? pending;
  Object? failure;
  final writes = <Map<String, dynamic>>[];
  @override
  Future<ProjectOrganization> read(String actor, String projectId) async =>
      pending == null ? snapshot : pending!.future;
  @override
  Future<ProjectOrganization> mutate(
    String actor,
    String projectId,
    int revision,
    String requestId,
    Map<String, dynamic> command,
  ) async {
    writes.add({
      'actor': actor,
      'project': projectId,
      'revision': revision,
      'request': requestId,
      'command': command,
    });
    if (failure != null) throw failure!;
    return snapshot;
  }
}

void main() {
  setUpAll(() async {
    // Licensed SDK Roboto instead of the test framework's Ahem rectangles.
    final loader = FontLoader('Roboto');
    for (final style in ['regular', 'medium', 'bold']) {
      final font = File.fromUri(
        Uri.file(Platform.resolvedExecutable)
            .resolve('../../material_fonts/roboto-$style.ttf'),
      );
      loader.addFont(
        Future.value(ByteData.sublistView(await font.readAsBytes())),
      );
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      Future.value(
        ByteData.sublistView(
          await File.fromUri(
            Uri.file(Platform.resolvedExecutable)
                .resolve('../../material_fonts/materialicons-regular.otf'),
          ).readAsBytes(),
        ),
      ),
    );
    await icons.load();
  });
  test(
    'parser rejects cross-project, malformed values and third-level tasks',
    () {
      expect(
        () => ProjectOrganization.parse({}, 'other'),
        throwsFormatException,
      );
      final payload = {
        'project_id': 'p',
        'revision': 0,
        'definition_phase': 'idea',
        'can_mutate': true,
        'can_plan': true,
        'can_manage_tasks': true,
        'proposals': {
          'capacity': {'limit': 0, 'count_organizers': false},
        },
        'official': {},
        'tasks': [],
      };
      expect(
        () => ProjectOrganization.parse(payload, 'p'),
        throwsFormatException,
      );
      payload['proposals'] = {};
      payload['tasks'] = [
        for (final pair in [('a', null), ('b', 'a'), ('c', 'b')])
          {
            'id': pair.$1,
            'parent_id': pair.$2,
            'title': 'Task',
            'done': false,
            'can_edit': true,
            'can_remove': true,
          },
      ];
      expect(
        () => ProjectOrganization.parse(payload, 'p'),
        throwsFormatException,
      );
    },
  );

  for (final code in ['PT409', '42501', '55000', 'network']) {
    test(
      'controller clears private state after $code without optimistic success',
      () async {
        final gateway = _Gateway()
          ..failure = PostgrestException(
            message: 'Private diagnostic',
            code: code,
          );
        final (container, auth) = _container(gateway);
        addTearDown(() {
          container.dispose();
          auth.close();
        });
        final controller = container.read(projectOrganizationProvider.notifier);
        await controller.load('user-1', 'fictional-check01');
        expect(
          await controller.mutate({
            'action': 'set_task_done',
          }, expectedRevision: 1),
          false,
        );
        expect(container.read(projectOrganizationProvider).snapshot, isNull);
        expect(gateway.writes.single['actor'], 'user-1');
        expect(gateway.writes.single['revision'], 1);
        expect(gateway.writes.single['request'], isNotEmpty);
      },
    );
  }
  test(
    'a modal opened at an old revision cannot silently rebase its edit',
    () async {
      final gateway = _Gateway();
      final (container, auth) = _container(gateway);
      addTearDown(() {
        container.dispose();
        auth.close();
      });
      final controller = container.read(projectOrganizationProvider.notifier);
      await controller.load('user-1', 'fictional-check01');
      gateway.snapshot = organizationFixture(revision: 2);
      await controller.load('user-1', 'fictional-check01', background: true);
      expect(
        await controller.mutate({'action': 'edit_task'}, expectedRevision: 1),
        false,
      );
      expect(gateway.writes, isEmpty);
      expect(
        container.read(projectOrganizationProvider).failure,
        OrganizationFailure.changed,
      );
    },
  );
  test(
    'profile/session change clears private state and ignores late read',
    () async {
      final pending = Completer<ProjectOrganization>();
      final gateway = _Gateway()..pending = pending;
      final (container, auth) = _container(gateway);
      addTearDown(() {
        container.dispose();
        auth.close();
      });
      final controller = container.read(projectOrganizationProvider.notifier);
      final read = controller.load('user-1', 'fictional-check01');
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      pending.complete(organizationFixture());
      await read;
      expect(container.read(projectOrganizationProvider).snapshot, isNull);
    },
  );

  for (final locale in ['en', 'it']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$locale 320dp ${scale}x missing/proposed/confirmed have one row and no subtitle',
        (tester) async {
          for (final state in [
            'missing',
            'proposed',
            'confirmed',
            'replacement',
            'stale',
          ]) {
            await _pump(
              tester,
              organizationFixture(state: state),
              locale: locale,
              scale: scale,
            );
            expect(find.byType(OrganizationDecisionRow), findsNWidgets(3));
            expect(find.byType(ListTile), findsNothing);
            expect(
              find.text(state == 'confirmed' ? 'Trento' : 'Rovereto'),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
  testWidgets(
    'read-only member expands private replacement without save/confirm',
    (tester) async {
      await _pump(
        tester,
        organizationFixture(state: 'replacement', canPlan: false),
      );
      await tester.tap(find.byKey(const Key('organization-decision-location')));
      await tester.pumpAndSettle();
      expect(find.text('Rovereto'), findsOneWidget);
      expect(find.text('Currently public: Trento'), findsOneWidget);
      expect(
        find.byKey(const Key('organization-confirm-location')),
        findsNothing,
      );
      expect(find.byKey(const Key('organization-save-location')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'save proposal and explicit confirmation are different commands',
    (tester) async {
      final commands = <Map<String, dynamic>>[];
      await _pump(
        tester,
        organizationFixture(state: 'replacement'),
        onCommand: (c) async {
          commands.add(c);
          return true;
        },
      );
      await tester.tap(find.byKey(const Key('organization-decision-location')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-save-location')));
      await tester.pumpAndSettle();
      expect(commands.single['action'], 'save_decision');
      await tester.ensureVisible(
        find.byKey(const Key('organization-confirm-location')),
      );
      await tester.tap(find.byKey(const Key('organization-confirm-location')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Confirming makes this value official on the public Project card.',
        ),
        findsOneWidget,
      );
      expect(commands, hasLength(1));
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(commands.last, {'action': 'confirm_decision', 'kind': 'location'});
    },
  );
  testWidgets('unsaved input cannot confirm the previous persisted proposal', (
    tester,
  ) async {
    await _pump(tester, organizationFixture(state: 'replacement'));
    await tester.tap(find.byKey(const Key('organization-decision-location')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Different city');
    await tester.pump();
    final confirm = tester.widget<TextButton>(
      find.byKey(const Key('organization-confirm-location')),
    );
    expect(confirm.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('same fictional planner before and after expansion', (
    tester,
  ) async {
    await _pump(tester, organizationFixture(state: 'proposed'), locale: 'it');
    if (Platform.isWindows) {
      await expectLater(
        find.byKey(const Key('organization-review-image')),
        matchesGoldenFile('goldens/proposed-it-1.0-false.png'),
      );
    }
    await tester.tap(find.byKey(const Key('organization-decision-location')));
    await tester.pumpAndSettle();
    if (Platform.isWindows) {
      await expectLater(
        find.byKey(const Key('organization-review-image')),
        matchesGoldenFile('goldens/proposed-it-expanded.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('closing the real sheet clears its private provider safely', (
    tester,
  ) async {
    final (container, _) = _container(_Gateway());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showProjectOrganization(
                  context,
                  organizationFixture().projectId,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(container.read(projectOrganizationProvider).snapshot, isNotNull);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(container.read(projectOrganizationProvider).snapshot, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'parent checkbox is derived, children can reopen, no child submenu for nesting',
    (tester) async {
      final commands = <Map<String, dynamic>>[];
      await _pump(
        tester,
        organizationFixture(),
        onCommand: (c) async {
          commands.add(c);
          return true;
        },
      );
      final parent = find.descendant(
        of: find.byKey(const ValueKey('organization-task-materials')),
        matching: find.byType(Checkbox),
      );
      expect(tester.widget<Checkbox>(parent).onChanged, isNull);
      final child = find.byKey(const ValueKey('organization-task-tools'));
      await tester.tap(
        find.descendant(of: child, matching: find.byType(Checkbox)),
      );
      await tester.pump();
      expect(commands.single, {
        'action': 'set_task_done',
        'task_id': 'tools',
        'done': false,
      });
      await tester.tap(
        find.descendant(
          of: child,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add subtask'), findsNothing);
      expect(find.text('Remove task'), findsNothing);
    },
  );
  testWidgets('Defined hides decisions, ended shows read-only custom tasks', (
    tester,
  ) async {
    await _pump(
      tester,
      organizationFixture(state: 'defined', canMutate: false),
    );
    expect(find.byType(OrganizationDecisionRow), findsNothing);
    expect(find.text('This Project is read-only.'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('organization-add-task')))
          .onPressed,
      isNull,
    );
  });
  testWidgets('expanded schedule scrolls at 320dp/2x with keyboard inset', (
    tester,
  ) async {
    await _pump(
      tester,
      organizationFixture(),
      locale: 'it',
      scale: 2,
      inset: 260,
    );
    await tester.ensureVisible(
      find.byKey(const Key('organization-decision-schedule')),
    );
    await tester.tap(find.byKey(const Key('organization-decision-schedule')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('organization-save-schedule')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  for (final entry in [
    ('missing', 'it', 1.0, false, null),
    ('proposed', 'it', 1.0, false, null),
    ('confirmed', 'en', 1.0, false, null),
    ('replacement', 'it', 1.0, false, 'location'),
    ('proposed', 'en', 2.0, true, 'schedule'),
    ('missing', 'it', 2.0, false, null),
  ]) {
    testWidgets(
      'CHECK01 visual ${entry.$1}-${entry.$2}-${entry.$3}-${entry.$4}',
      (tester) async {
        await _pump(
          tester,
          organizationFixture(state: entry.$1),
          locale: entry.$2,
          scale: entry.$3,
          dark: entry.$4,
        );
        if (entry.$5 != null) {
          await tester.tap(
            find.byKey(Key('organization-decision-${entry.$5}')),
          );
          await tester.pumpAndSettle();
        }
        if (Platform.isWindows) {
          await expectLater(
            find.byKey(const Key('organization-review-image')),
            matchesGoldenFile(
              'goldens/${entry.$1}-${entry.$2}-${entry.$3}-${entry.$4}.png',
            ),
          );
        }
      },
    );
  }
}

(ProviderContainer, FakeAuthGateway) _container(_Gateway gateway) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      projectOrganizationGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return (container, auth);
}

Future<void> _pump(
  WidgetTester tester,
  ProjectOrganization snapshot, {
  String locale = 'en',
  double scale = 1,
  bool dark = false,
  double inset = 0,
  Future<bool> Function(Map<String, dynamic>)? onCommand,
}) async {
  tester.view.physicalSize = const Size(320, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: inset),
        ),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const Key('organization-review-image'),
        child: Scaffold(
          appBar: AppBar(
            title: Text(locale == 'it' ? 'Organizzazione' : 'Organization'),
          ),
          body: Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: ProjectOrganizationContent(
              key: ValueKey(
                '${snapshot.revision}:${snapshot.proposed}:${snapshot.official}',
              ),
              snapshot: snapshot,
              onCommand: onCommand ?? (_) async => true,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
