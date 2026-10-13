import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/project_chat/data/project_needs_gateway.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';
import 'package:planets_mobile/features/project_chat/presentation/project_chat_info_screen.dart';
import 'package:planets_mobile/features/project_delegates/application/project_invite_sharing.dart';
import 'package:planets_mobile/features/project_delegates/application/project_delegate_controllers.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/project_delegates/presentation/project_coorganizers_screen.dart';
import 'package:planets_mobile/features/project_delegates/presentation/project_manage_screen.dart';
import 'package:planets_mobile/features/project_participant_invites/data/participant_invitation_gateway.dart';
import 'package:planets_mobile/features/project_participant_invites/domain/participant_invitation_models.dart';
import 'package:planets_mobile/features/project_participant_invites/presentation/participant_link_management_screen.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_pending_add_store.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_participant_invitation.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_project_chat.dart';
import '../../../support/fake_project_needs.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_project_workspace.dart';

const _renderKey = Key('organization-render');
const _capture = String.fromEnvironment('ORG_UX01_CAPTURE_DIR');

void main() {
  setUpAll(() async {
    // Screenshots use the SDK's actual Roboto and Material glyphs, not Ahem.
    // Capture is opt-in; normal CI verifies behavior without writing artifacts.
    if (_capture.isEmpty) return;
    final fonts =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          File('$fonts/${entry.value}')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });

  for (final locale in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        for (final populated in [false, true]) {
          for (final screen in ['manage', 'team', 'links', 'info']) {
            testWidgets(
              '$screen $locale dark=$dark scale=$scale populated=$populated at 320dp',
              (tester) async {
                tester.view.devicePixelRatio = 1;
                tester.view.physicalSize = const Size(320, 800);
                addTearDown(tester.view.resetPhysicalSize);
                addTearDown(tester.view.resetDevicePixelRatio);
                final h = await _pump(
                  tester,
                  screen,
                  locale: locale,
                  dark: dark,
                  scale: scale,
                  populated: populated,
                );
                expect(tester.takeException(), isNull);
                expect(find.byKey(const Key('page-close')), findsOneWidget);
                await _captureFrame(
                  tester,
                  '$screen-$locale-${dark ? 'dark' : 'light'}-${scale}x-${populated ? 'populated' : 'empty'}',
                );
                // Exercise the whole scroll extent, not only the initial viewport.
                await tester.drag(
                  find.byType(ListView).first,
                  const Offset(0, -1600),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                if (screen == 'team' && populated) {
                  await tester.ensureVisible(
                    find.byKey(const Key('project-invitation-invite-1')),
                  );
                  await tester.pumpAndSettle();
                  expect(
                    find
                        .byKey(const Key('project-invitation-invite-1'))
                        .hitTestable(),
                    findsOneWidget,
                  );
                  await _captureFrame(
                    tester,
                    'team-$locale-${dark ? 'dark' : 'light'}-${scale}x-invitations',
                  );
                }
                if (screen == 'info') {
                  expect(
                    h.participation.calls.where(
                      (c) => c.startsWith('meeting:'),
                    ),
                    isEmpty,
                  );
                }
              },
            );
          }
        }
      }
    }
  }

  for (final role in [
    ProjectManagementRole.creator,
    ProjectManagementRole.coCreator,
    ProjectManagementRole.coOrganizer,
  ]) {
    for (final kind in ProjectKind.values) {
      testWidgets('Manage destinations navigate for $role / $kind', (
        tester,
      ) async {
        final h = await _pump(tester, 'manage', role: role, kind: kind);
        final hasNeeds = kind == ProjectKind.oneTime
            ? role.hasStructuralAuthority
            : role == ProjectManagementRole.creator;
        final groups = find.byType(Card);
        expect(groups, findsNWidgets(2));
        expect(find.text('Project management'), findsOneWidget);
        expect(find.text('Organization'), findsOneWidget);
        expect(
          find.descendant(
            of: groups.first,
            matching: find.byKey(const Key('participant-links-manage')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: groups.last,
            matching: find.byKey(const Key('project-manage-workspace')),
          ),
          findsOneWidget,
        );
        expect(
          find.byType(Divider),
          findsNWidgets(
            (role.hasStructuralAuthority ? 3 : 1) +
                (kind == ProjectKind.oneTime ? 1 : 0) +
                (hasNeeds ? 1 : 0),
          ),
        );
        if (role.hasStructuralAuthority) {
          expect(find.text('Manage organizers'), findsOneWidget);
        }
        expect(
          find.byKey(const Key('project-manage-needs')),
          hasNeeds ? findsOneWidget : findsNothing,
        );
        if (hasNeeds && kind == ProjectKind.oneTime) {
          expect(
            tester
                .getTopLeft(
                  find.byKey(const Key('project-manage-organization')),
                )
                .dy,
            lessThan(
              tester
                  .getTopLeft(find.byKey(const Key('project-manage-needs')))
                  .dy,
            ),
          );
          expect(
            tester.getTopLeft(find.byKey(const Key('project-manage-needs'))).dy,
            lessThan(
              tester
                  .getTopLeft(find.byKey(const Key('project-manage-workspace')))
                  .dy,
            ),
          );
        }
        expect(
          find.byKey(const Key('project-manage-organization')),
          kind == ProjectKind.oneTime ? findsOneWidget : findsNothing,
        );
        final prefix = kind == ProjectKind.oneTime
            ? '/proposals/project-1'
            : '/tavoli/project-1';
        final destinations = {
          'project-manage-participation': '$prefix/participants',
          'participant-links-manage': '$prefix/participant-links',
          if (role.hasStructuralAuthority) ...{
            'project-manage-team': '$prefix/co-organizers',
            'project-manage-structural-edit': '$prefix/edit',
          },
          if (hasNeeds)
            'project-manage-needs':
                '$prefix/${kind == ProjectKind.oneTime ? 'needs' : 'resources'}',
          'project-manage-workspace': '$prefix/workspace',
        };
        if (!role.hasStructuralAuthority) {
          expect(find.byKey(const Key('project-manage-team')), findsNothing);
          expect(
            find.byKey(const Key('project-manage-structural-edit')),
            findsNothing,
          );
        }
        for (final destination in destinations.entries) {
          final row = find.byKey(Key(destination.key));
          await tester.ensureVisible(row);
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(h.router.state.uri.path, destination.value);
          h.router.pop();
          await tester.pumpAndSettle();
        }
      });
    }
  }

  testWidgets(
    'Team omits proven empty sections and preserves lost-link advice in confirmation',
    (tester) async {
      await _pump(tester, 'team', populated: false);
      expect(find.text('Active roles'), findsNothing);
      expect(find.text('Pending invitations'), findsNothing);
      expect(find.textContaining('Revoke a lost link'), findsNothing);
      await tester.tap(find.byKey(const Key('project-delegate-create')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Revoke a lost link'), findsOneWidget);
    },
  );

  testWidgets(
    'history disclosure preserves chronology and explicit pagination',
    (tester) async {
      final links = FakeParticipantInvitationGateway()
        ..rows = List.generate(
          20,
          (i) => ParticipantLinkHistory(
            id: 'generation-$i',
            issuerId: 'user-1',
            createdAt: DateTime.utc(2030, 1, 30 - i),
            reason: i == 0
                ? null
                : i == 1
                ? 'replaced'
                : 'revoked',
          ),
        );
      final h = await _pump(tester, 'links', links: links);
      expect(find.byKey(const Key('participant-link-retry')), findsNothing);
      expect(find.byKey(const ValueKey('generation-0')), findsNothing);
      await tester.tap(find.byKey(const Key('participant-link-history')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('generation-0')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('generation-0'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('generation-1'))).dy,
        ),
      );
      final more = find.byKey(const Key('participant-link-history-more'));
      await tester.scrollUntilVisible(
        more,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      links.rows = [
        ParticipantLinkHistory(
          id: 'older',
          issuerId: 'user-1',
          createdAt: DateTime.utc(2029),
        ),
      ];
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(links.cursor?.id, 'generation-19');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('older')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('older')), findsOneWidget);
      expect(
        find.byKey(const Key('participant-link-history-more')),
        findsNothing,
      );
      expect(h.links.calls.where((c) => c.startsWith('history:')).length, 2);
    },
  );

  testWidgets(
    'empty history has no heading; create and replacement keep explicit actions',
    (tester) async {
      final h = await _pump(tester, 'links', populated: false);
      expect(find.byKey(const Key('participant-link-history')), findsNothing);
      await tester.tap(find.byKey(const Key('participant-link-regenerate')));
      await tester.pumpAndSettle();
      expect(h.links.calls, contains('create:user-1:project-1'));
      await tester.tap(find.byKey(const Key('project-share-native')));
      await tester.pumpAndSettle();
      expect(h.sharing.shared, contains('/join/project/'));
      await tester.tap(find.byKey(const Key('participant-link-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('participant-link-regenerate')));
      await tester.pumpAndSettle();
      expect(h.links.calls.where((c) => c.startsWith('regenerate:')), isEmpty);
      await tester.tap(find.byKey(const Key('participant-link-confirm')));
      await tester.pumpAndSettle();
      expect(h.links.calls, contains('regenerate:user-1:project-1'));
    },
  );

  for (final loseAccount in [false, true]) {
    testWidgets(
      'pending management copy clears on ${loseAccount ? 'account' : 'authority'} loss',
      (tester) async {
        final h = await _pump(tester, 'links');
        final delay = Completer<void>();
        h.links.readDelay = delay.future;
        await tester.tap(find.byKey(const Key('project-share-copy')));
        await tester.pump();
        if (loseAccount) {
          h.container
              .read(authSessionProvider.notifier)
              .markProfileReady(const AuthIdentity(id: 'user-2'));
        } else {
          final gateway = h.container.read(
            projectDelegateGatewayProvider,
          ) as FakeProjectDelegateGateway;
          gateway.role = ProjectManagementRole.none;
          await h.container
              .read(projectManagementRoleProvider.notifier)
              .load(
                expectedProfileId: 'user-1',
                projectId: 'project-1',
                projectKind: ProjectKind.oneTime,
              );
        }
        await tester.pump();
        delay.complete();
        await tester.pumpAndSettle();
        expect(h.sharing.copied, isNull);
        expect(find.byKey(const Key('project-share-copy')), findsNothing);
        expect(find.byKey(const Key('participant-link-actions')), findsNothing);
      },
    );
  }

  testWidgets(
    'link read failure shows retry and recovers; unjoinable stays visible',
    (tester) async {
      final links = FakeParticipantInvitationGateway()
        ..readError = StateError('offline');
      await _pump(tester, 'links', links: links);
      expect(find.byKey(const Key('participant-link-error')), findsOneWidget);
      expect(find.byKey(const Key('project-share-native')), findsNothing);
      links.readError = null;
      links.previewValue = const ParticipantInvitePreview(available: false);
      await tester.tap(find.byKey(const Key('participant-link-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('participant-link-retry')), findsNothing);
      expect(
        find.text('This participant link is unavailable for a new join.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('project-share-native')), findsOneWidget);
    },
  );

  for (final viewer in ProjectChatViewerRole.values) {
    testWidgets(
      'Group info preserves $viewer entitlement and lazy meeting read',
      (tester) async {
        final h = await _pump(tester, 'info', viewer: viewer, populated: false);
        final former = viewer == ProjectChatViewerRole.formerMember;
        expect(
          find.byKey(const Key('project-chat-manage-participation')),
          former ? findsNothing : findsOneWidget,
        );
        expect(
          h.participation.calls.where((c) => c.startsWith('meeting:')),
          isEmpty,
        );
        expect(h.workspace.calls.isEmpty, former);
        expect(
          find.byKey(const Key('participant-links-manage')),
          viewer == ProjectChatViewerRole.creator ||
                  viewer == ProjectChatViewerRole.delegate
              ? findsOneWidget
              : findsNothing,
        );
        if (viewer == ProjectChatViewerRole.currentMember) {
          expect(
            find.byKey(const Key('project-workspace-info-section')),
            findsNothing,
          );
        }
      },
    );
  }

  for (final failed in [false, true]) {
    testWidgets(
      'workspace ${failed ? 'failure' : 'loading'} remains discernible in compact hub',
      (tester) async {
        final delay = Completer<void>();
        final workspace = FakeProjectWorkspaceGateway();
        if (failed) {
          workspace.readError = StateError('offline');
        } else {
          workspace.readDelay = delay.future;
        }
        await _pump(tester, 'manage', workspace: workspace, settle: failed);
        expect(
          find.byKey(const Key('project-manage-workspace')),
          findsOneWidget,
        );
        if (failed) {
          expect(find.byTooltip('Try again'), findsOneWidget);
          workspace.readError = null;
          await tester.tap(find.byTooltip('Try again'));
          await tester.pumpAndSettle();
        } else {
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          delay.complete();
          await tester.pumpAndSettle();
        }
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  }

  testWidgets(
    'landscape large text keeps Team menus and invitation handoff reachable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, 'team', locale: 'it', scale: 2);
      await tester.scrollUntilVisible(
        find.byKey(const Key('project-delegate-create')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('project-delegate-create')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('delegate-invite-share')),
      );
      expect(
        find.byKey(const Key('delegate-invite-share')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _captureFrame(WidgetTester tester, String name) async {
  if (_capture.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_renderKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_capture/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<
  ({
    GoRouter router,
    ProviderContainer container,
    FakeParticipationGateway participation,
    FakeParticipantInvitationGateway links,
    FakeProjectInviteSharing sharing,
    FakeProjectWorkspaceGateway workspace,
  })
>
_pump(
  WidgetTester tester,
  String screen, {
  String locale = 'en',
  bool dark = false,
  double scale = 1,
  bool populated = true,
  ProjectManagementRole role = ProjectManagementRole.creator,
  ProjectKind kind = ProjectKind.oneTime,
  ProjectChatViewerRole viewer = ProjectChatViewerRole.creator,
  FakeParticipantInvitationGateway? links,
  FakeProjectWorkspaceGateway? workspace,
  bool settle = true,
}) async {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final delegates = FakeProjectDelegateGateway()..role = role;
  if (populated) {
    delegates.delegates = [
      ProjectDelegate(
        id: 'delegate-1',
        profileId: 'user-2',
        displayName: 'Jordan Rossi',
        delegatedAt: DateTime.utc(2030, 1, 1),
        grantedByProfileId: 'user-1',
        grantedByDisplayName: 'Alex',
      ),
      ProjectDelegate(
        id: 'delegate-2',
        profileId: 'user-3',
        displayName: 'Sofia Bianchi',
        delegatedAt: DateTime.utc(2030, 1, 2),
        grantedByProfileId: 'user-1',
        grantedByDisplayName: 'Alex',
        authorityRole: ProjectDelegatedAuthorityRole.coCreator,
      ),
    ];
    delegates.invitations = [
      ProjectDelegateInvitation(
        id: 'invite-1',
        createdAt: DateTime.utc(2030, 1, 2),
        expiresAt: DateTime.utc(2030, 1, 9),
        issuerProfileId: 'user-1',
        issuerDisplayName: 'Alex',
      ),
    ];
  }
  final invitations = links ?? FakeParticipantInvitationGateway();
  if (links == null && !populated) invitations.link = null;
  final sharedWorkspace = workspace ?? FakeProjectWorkspaceGateway();
  if (workspace == null && populated) {
    sharedWorkspace.workspace = projectWorkspaceFixture(
      projectId: 'project-1',
      url: 'https://docs.example.org/team',
    );
  }
  final participation = FakeParticipationGateway();
  final sharing = FakeProjectInviteSharing();
  final chats = FakeProjectChatGateway()
    ..summaries = [
      projectChatSummaryFixture(
        projectId: 'project-1',
        projectKind: kind,
        viewerRole: viewer,
        projectTitle: locale == 'it'
            ? 'Dipingiamo la piazza'
            : 'Paint the square',
      ),
    ];
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      projectDelegateGatewayProvider.overrideWithValue(delegates),
      participantInvitationGatewayProvider.overrideWithValue(invitations),
      projectWorkspacePendingAddStoreProvider.overrideWithValue(
        FakeWorkspacePendingAddStore(),
      ),
      projectWorkspaceGatewayProvider.overrideWithValue(sharedWorkspace),
      participationGatewayProvider.overrideWithValue(participation),
      projectInviteSharingProvider.overrideWithValue(sharing),
      projectChatGatewayProvider.overrideWithValue(chats),
      projectNeedsGatewayProvider.overrideWithValue(FakeProjectNeedsGateway()),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  final prefix = kind == ProjectKind.oneTime
      ? '/proposals/project-1'
      : '/tavoli/project-1';
  final routes = {
    'manage': '$prefix/manage',
    'team': '$prefix/co-organizers',
    'links': '$prefix/participant-links',
    'info': '/messages/chats/chat-1/info',
  };
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold()),
      for (final entry in routes.entries)
        GoRoute(
          path: entry.value,
          builder: (_, _) => switch (entry.key) {
            'manage' => ProjectManageScreen(
              projectId: 'project-1',
              projectKind: kind,
            ),
            'team' => ProjectTeamScreen(
              projectId: 'project-1',
              projectKind: kind,
            ),
            'links' => ParticipantLinkManagementScreen(
              projectId: 'project-1',
              kind: kind,
            ),
            _ => const ProjectChatInfoScreen(chatId: 'chat-1'),
          },
        ),
      for (final destination in [
        '$prefix/participants',
        '$prefix/edit',
        '$prefix/workspace',
        '$prefix/needs',
        '$prefix/resources',
        prefix,
      ])
        GoRoute(path: destination, builder: (_, _) => const Scaffold()),
    ],
  );
  addTearDown(() {
    router.dispose();
    container.dispose();
    auth.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: _renderKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          routerConfig: router,
        ),
      ),
    ),
  );
  router.push(routes[screen]!);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  return (
    router: router,
    container: container,
    participation: participation,
    links: invitations,
    sharing: sharing,
    workspace: sharedWorkspace,
  );
}
