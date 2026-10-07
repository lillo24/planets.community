import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/theme/app_tokens.dart';
import 'package:planets_mobile/core/widgets/error_state.dart';
import 'package:planets_mobile/core/widgets/loading_state.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/participation/data/actual_contribution_gateway.dart';
import 'package:planets_mobile/features/participation/data/membership_commitment_gateway.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/membership_commitment_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/project_chat/data/project_needs_gateway.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_controllers.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/application/project_workspace_launcher.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/resource_chat/data/resource_chat_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_actual_contribution.dart';
import '../../../support/fake_messages.dart';
import '../../../support/fake_message_chats.dart';
import '../../../support/fake_membership_commitment.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_project_chat.dart';
import '../../../support/fake_project_needs.dart';
import '../../../support/fake_project_workspace.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_recurring_activity.dart';
import '../../../support/fake_resource_chat.dart';

void main() {
  testWidgets('Project chat idle and loading render loading', (tester) async {
    final pending = Completer<void>();
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = []
      ..historyDelay = pending.future;
    final app = await _pump(tester, chats: chats);

    app.read(appRouterProvider).go('/messages/chats/chat-1');
    // Complete awaitable route entry before asserting the pending data load.
    await tester.pump();
    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project-chat-composer')), findsOneWidget);
    expect(find.byKey(const Key('project-chat-tools-strip')), findsOneWidget);
    expect(find.byKey(const Key('project-needs-button')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('project-chat-composer-bar')),
        matching: find.byKey(const Key('project-needs-button')),
      ),
      findsNothing,
    );
  });

  testWidgets('Project chat info idle and loading render loading', (
    tester,
  ) async {
    final pending = Completer<void>();
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = []
      ..historyDelay = pending.future;
    final app = await _pump(tester, chats: chats);

    app.read(appRouterProvider).go('/messages/chats/chat-1/info');
    // Complete awaitable route entry before asserting the pending data load.
    await tester.pump();
    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Paint the square'), findsOneWidget);
  });

  testWidgets('Messages defaults to chat previews without unread state', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [
        projectChatSummaryFixture(),
        projectChatSummaryFixture(
          chatId: 'chat-2',
          projectId: 'tavolo-1',
          projectKind: ProjectKind.recurring,
          projectTitle: 'Repair table',
          viewerRole: ProjectChatViewerRole.formerMember,
          lastVisibleMessageId: null,
        ),
      ];
    final app = await _pump(tester, chats: chats);
    app.read(appRouterProvider).go('/messages');
    await tester.pumpAndSettle();

    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);
    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();
    expect(find.text('Jordan: Bring a small brush.'), findsOneWidget);
    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.text('Read-only'), findsNothing);
    expect(find.textContaining('unread'), findsNothing);
    expect(chats.subscriptions, hasLength(1));
    expect(chats.subscriptions.single.chatId, 'chat-1');
  });

  testWidgets('chat-list failure is localized and hides diagnostics', (
    tester,
  ) async {
    const diagnostic = 'private database identifier';
    final chats = FakeProjectChatGateway()..listError = StateError(diagnostic);
    final app = await _pump(
      tester,
      chats: chats,
      unifiedChats: FakeMessageChatsGateway()..error = StateError(diagnostic),
    );
    app.read(appRouterProvider).go('/messages');
    await tester.pumpAndSettle();

    expect(find.textContaining(diagnostic), findsNothing);
    expect(find.textContaining("couldn't load chats"), findsOneWidget);
  });

  testWidgets('current member sees full returned history and sends once', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [
        projectChatMessageFixture(
          messageId: 'message-after-join',
          body: 'Welcome aboard.',
          createdAt: DateTime.utc(2026, 9, 14, 11),
        ),
        projectChatMessageFixture(
          messageId: 'message-before-join',
          body: 'This message predates the new member.',
          createdAt: DateTime.utc(2026, 9, 10, 11),
        ),
      ];
    final app = await _pump(tester, chats: chats);
    app.read(appRouterProvider).go('/messages/chats/chat-1');
    await tester.pumpAndSettle();

    expect(find.text('This message predates the new member.'), findsOneWidget);
    expect(find.text('Welcome aboard.'), findsOneWidget);
    expect(find.byKey(const Key('project-chat-composer')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('project-chat-composer')),
      '  Hello team  ',
    );
    await tester.tap(find.byKey(const Key('project-chat-send')));
    await tester.pumpAndSettle();

    expect(chats.calls.where((call) => call == 'send:chat-1'), hasLength(1));
    expect(chats.lastSentBody, 'Hello team');
    expect(find.text('Hello team'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('project-chat-composer')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('send failure retains typed text and shows safe copy', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = []
      ..sendError = StateError('private backend diagnostic');
    final app = await _pump(tester, chats: chats);
    app.read(appRouterProvider).go('/messages/chats/chat-1');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('project-chat-composer')),
      'Please keep this text',
    );
    await tester.tap(find.byKey(const Key('project-chat-send')));
    await tester.pumpAndSettle();

    expect(find.text('Please keep this text'), findsOneWidget);
    expect(find.textContaining('private backend diagnostic'), findsNothing);
    expect(
      find.textContaining("couldn't load the project chat"),
      findsOneWidget,
    );
  });

  testWidgets('configured workspace appears in the current chat tools strip', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final workspace = FakeProjectWorkspaceGateway()
      ..workspace = projectWorkspaceFixture();
    final launcher = FakeProjectWorkspaceLauncher();
    final app = await _pump(
      tester,
      chats: chats,
      workspace: workspace,
      workspaceLauncher: launcher,
    );
    app.read(appRouterProvider).go('/messages/chats/chat-1');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('project-chat-tools-strip')), findsOneWidget);
    expect(
      find.byKey(const Key('project-workspace-chat-control')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('project-workspace-chat-control')));
    await tester.pumpAndSettle();
    expect(find.textContaining('drive.google.com'), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);
    await tester.tap(find.byKey(const Key('project-workspace-confirm-open')));
    await tester.pumpAndSettle();
    expect(launcher.calls, 1);
  });

  testWidgets('manager without a link sees Add workspace in chat', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [
        projectChatSummaryFixture(viewerRole: ProjectChatViewerRole.creator),
      ]
      ..histories['chat-1'] = [];
    final app = await _pump(tester, chats: chats);
    app.read(appRouterProvider).go('/messages/chats/chat-1');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('project-workspace-chat-control')),
      findsOneWidget,
    );
    expect(find.text('Add workspace'), findsOneWidget);
  });

  testWidgets('former member keeps history without composer or Realtime', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [
        projectChatSummaryFixture(
          viewerRole: ProjectChatViewerRole.formerMember,
        ),
      ]
      ..histories['chat-1'] = [projectChatMessageFixture()];
    final app = await _pump(tester, chats: chats);
    app.read(appRouterProvider).go('/messages/chats/chat-1');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('project-chat-composer')), findsNothing);
    expect(find.byKey(const Key('project-chat-read-only')), findsOneWidget);
    expect(find.text('Bring a small brush.'), findsOneWidget);
    expect(find.byKey(const Key('project-needs-button')), findsNothing);
    expect(find.byKey(const Key('project-chat-tools-strip')), findsNothing);
    expect(
      find.byKey(const Key('project-workspace-chat-control')),
      findsNothing,
    );
    expect(chats.subscriptions, isEmpty);
  });

  testWidgets('mixed feed renders a neutral resurfacing system card', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [
        projectChatSystemEventFixture(requirementLabel: 'Exterior paint'),
        projectChatMessageFixture(),
      ];
    final app = await _pump(tester, chats: chats);
    app.read(appRouterProvider).go('/messages/chats/chat-1');
    await tester.pumpAndSettle();

    expect(find.text('Exterior paint is needed again.'), findsOneWidget);
    expect(
      find.byKey(const Key('project-chat-system-event-1')),
      findsOneWidget,
    );
    expect(find.text('Jordan'), findsOneWidget);
  });

  testWidgets('Project chat applies explicit bubble and system-card spacing', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [
        projectChatMessageFixture(
          messageId: 'message-1',
          body: 'First message',
          createdAt: DateTime.utc(2026, 9, 14, 9),
        ),
        projectChatMessageFixture(
          messageId: 'message-2',
          body: 'Second message',
          createdAt: DateTime.utc(2026, 9, 14, 10),
        ),
        projectChatSystemEventFixture(
          eventId: 'event-1',
          createdAt: DateTime.utc(2026, 9, 14, 11),
        ),
      ];
    final app = await _pump(tester, chats: chats);
    app.read(appRouterProvider).go('/messages/chats/chat-1');
    await tester.pumpAndSettle();

    final entries = <({Rect rect, bool isSystem})>[
      (
        rect: tester.getRect(
          find.byKey(const Key('project-chat-message-message-1')),
        ),
        isSystem: false,
      ),
      (
        rect: tester.getRect(
          find.byKey(const Key('project-chat-message-message-2')),
        ),
        isSystem: false,
      ),
      (
        rect: tester.getRect(
          find.byKey(const Key('project-chat-system-event-1')),
        ),
        isSystem: true,
      ),
    ]..sort((left, right) => left.rect.top.compareTo(right.rect.top));

    for (var index = 1; index < entries.length; index += 1) {
      final previous = entries[index - 1];
      final current = entries[index];
      final minimumGap = previous.isSystem || current.isSystem
          ? AppSpacing.small + AppSpacing.xSmall
          : AppSpacing.small;
      expect(
        current.rect.top - previous.rect.bottom,
        greaterThanOrEqualTo(minimumGap),
      );
    }
  });

  testWidgets('Project chat wraps long messages on a narrow large-text phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [
        projectChatMessageFixture(
          messageId: 'message-long-1',
          body: List.filled(14, 'coordination').join(' '),
          createdAt: DateTime.utc(2026, 9, 14, 9),
        ),
        projectChatMessageFixture(
          messageId: 'message-long-2',
          body: List.filled(14, 'materials').join(' '),
          createdAt: DateTime.utc(2026, 9, 14, 10),
        ),
      ];
    final app = await _pump(tester, chats: chats);
    app.read(appRouterProvider).go('/messages/chats/chat-1');
    await tester.pumpAndSettle();

    final history = tester.getRect(
      find.byKey(const Key('project-chat-history')),
    );
    final composerBar = tester.getRect(
      find.byKey(const Key('project-chat-composer-bar')),
    );
    expect(history.bottom, lessThanOrEqualTo(composerBar.top));
    final messages = [
      find.byKey(const Key('project-chat-message-message-long-1')),
      find.byKey(const Key('project-chat-message-message-long-2')),
    ].where((finder) => finder.evaluate().isNotEmpty);
    expect(messages, isNotEmpty);
    for (final message in messages) {
      expect(tester.getRect(message).width, lessThanOrEqualTo(history.width));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('participant opens grouped Needs drawer and claims a need', (
    tester,
  ) async {
    final needs = FakeProjectNeedsGateway()
      ..requirements = [
        projectRequirementFixture(label: 'Painting'),
        projectRequirementFixture(
          kind: ProjectRequirementKind.resource,
          id: 'resource-1',
          label: 'Paint brushes',
        ),
      ];
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final app = await _pump(tester, chats: chats, needs: needs);
    app.read(appRouterProvider).go('/messages/chats/chat-1');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('project-needs-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('project-needs-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('project-needs-drawer')), findsOneWidget);
    expect(find.text('Competences / Knowledge'), findsOneWidget);
    expect(find.text('Resources / Materials'), findsOneWidget);
    expect(find.text('I can help'), findsOneWidget);
    expect(find.text('I can bring it'), findsOneWidget);

    await tester.tap(find.text('I can help'));
    await tester.pumpAndSettle();
    expect(needs.calls, contains('claim:skill:skill-1'));
    expect(find.text('Painting'), findsNothing);
  });

  testWidgets('creator sees manual management without participant actions', (
    tester,
  ) async {
    final needs = FakeProjectNeedsGateway()
      ..requirements = [
        projectRequirementFixture(label: 'Painting'),
        projectRequirementFixture(
          kind: ProjectRequirementKind.resource,
          id: 'resource-1',
          label: 'Ladder',
          isCovered: true,
          isManuallyCovered: true,
        ),
      ];
    final chats = FakeProjectChatGateway()
      ..summaries = [
        projectChatSummaryFixture(viewerRole: ProjectChatViewerRole.creator),
      ]
      ..histories['chat-1'] = [];
    final app = await _pump(tester, chats: chats, needs: needs);
    app.read(appRouterProvider).go('/messages/chats/chat-1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-needs-button')));
    await tester.pumpAndSettle();

    expect(find.text('Found outside app'), findsOneWidget);
    expect(find.text('Found outside the app'), findsOneWidget);
    expect(find.text('Needed again'), findsOneWidget);
    expect(find.text('I can help'), findsNothing);
  });

  testWidgets(
    'attention persists until visible drawer refresh acknowledges it',
    (tester) async {
      final needs = FakeProjectNeedsGateway()
        ..requirements = [projectRequirementFixture()]
        ..attention = projectAttentionFixture(
          hasUnseen: true,
          eventId: 'event-A',
        );
      final chats = FakeProjectChatGateway()
        ..summaries = [projectChatSummaryFixture()]
        ..histories['chat-1'] = [];
      final app = await _pump(tester, chats: chats, needs: needs);
      app.read(appRouterProvider).go('/messages/chats/chat-1');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('project-needs-attention-callout')),
        findsOneWidget,
      );
      expect(needs.calls.where((call) => call.startsWith('ack:')), isEmpty);

      await tester.tap(find.byKey(const Key('project-needs-button')));
      await tester.pumpAndSettle();

      expect(needs.acknowledgedEventId, 'event-A');
      expect(
        find.byKey(const Key('project-needs-attention-callout')),
        findsNothing,
      );
    },
  );

  testWidgets('failed drawer coverage never acknowledges attention', (
    tester,
  ) async {
    final needs = FakeProjectNeedsGateway()
      ..coverageError = StateError('private diagnostic')
      ..attention = projectAttentionFixture(hasUnseen: true);
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final app = await _pump(tester, chats: chats, needs: needs);
    app.read(appRouterProvider).go('/messages/chats/chat-1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-needs-button')));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load current needs.'), findsOneWidget);
    expect(needs.calls.where((call) => call.startsWith('ack:')), isEmpty);
  });

  testWidgets('becoming former closes the drawer and hides live Needs', (
    tester,
  ) async {
    final needs = FakeProjectNeedsGateway()
      ..requirements = [projectRequirementFixture()];
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final app = await _pump(tester, chats: chats, needs: needs);
    app.read(appRouterProvider).go('/messages/chats/chat-1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-needs-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project-needs-drawer')), findsOneWidget);

    chats.summaries = [
      projectChatSummaryFixture(viewerRole: ProjectChatViewerRole.formerMember),
    ];
    await app
        .read(projectChatDetailProvider.notifier)
        .refresh(expectedProfileId: 'user-1', chatId: 'chat-1');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('project-needs-drawer')), findsNothing);
    expect(find.byKey(const Key('project-needs-button')), findsNothing);
    expect(find.byKey(const Key('project-chat-read-only')), findsOneWidget);
  });

  testWidgets(
    'creator info opens project, participation, and meeting details',
    (tester) async {
      final chats = FakeProjectChatGateway()
        ..summaries = [
          projectChatSummaryFixture(viewerRole: ProjectChatViewerRole.creator),
        ]
        ..histories['chat-1'] = [];
      final participation = FakeParticipationGateway()
        ..meetingDetails = meetingDetailsFixture();
      final app = await _pump(
        tester,
        chats: chats,
        participation: participation,
      );
      final router = app.read(appRouterProvider);
      router.go('/messages/chats/chat-1/info');
      await tester.pumpAndSettle();

      expect(find.text('Paint the square'), findsOneWidget);
      expect(find.text('Proposal'), findsOneWidget);
      expect(
        find.byKey(const Key('project-chat-manage-participation')),
        findsOneWidget,
      );
      expect(
        participation.calls.where((call) => call.startsWith('meeting:')),
        isEmpty,
      );
      await tester.tap(find.byKey(const Key('project-chat-load-meeting')));
      await tester.pumpAndSettle();
      expect(find.text('Meet beside the blue workshop door.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('project-chat-open-project')),
        -250,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await tester.tap(
        find.byKey(const Key('project-chat-open-project')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/proposals/proposal-1',
      );
    },
  );

  testWidgets('former member info never requests protected meeting details', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [
        projectChatSummaryFixture(
          viewerRole: ProjectChatViewerRole.formerMember,
        ),
      ]
      ..histories['chat-1'] = [];
    final participation = FakeParticipationGateway()
      ..meetingDetails = meetingDetailsFixture();
    final workspace = FakeProjectWorkspaceGateway()
      ..workspace = projectWorkspaceFixture();
    final app = await _pump(
      tester,
      chats: chats,
      participation: participation,
      workspace: workspace,
    );
    app.read(appRouterProvider).go('/messages/chats/chat-1/info');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('project-chat-load-meeting')), findsNothing);
    expect(
      find.byKey(const Key('project-chat-manage-participation')),
      findsNothing,
    );
    expect(
      participation.calls.where((call) => call.startsWith('meeting:')),
      isEmpty,
    );
    expect(
      find.byKey(const Key('project-workspace-info-section')),
      findsNothing,
    );
    expect(workspace.calls, isEmpty);
  });

  for (final viewerRole in [
    ProjectChatViewerRole.currentMember,
    ProjectChatViewerRole.delegate,
    ProjectChatViewerRole.creator,
  ]) {
    testWidgets(
      '$viewerRole info uses own current rejoin episode and can edit',
      (tester) async {
        final chats = FakeProjectChatGateway()
          ..summaries = [projectChatSummaryFixture(viewerRole: viewerRole)]
          ..histories['chat-1'] = [];
        final participation = FakeParticipationGateway()
          ..ownMemberships = [
            ownMembershipFixture(
              id: 'membership-old',
              status: MembershipStatus.left,
              joinedAt: DateTime.utc(2026, 9, 1),
            ),
            ownMembershipFixture(
              id: 'membership-current',
              joinedAt: DateTime.utc(2026, 9, 15),
            ),
          ];
        final commitments = FakeMembershipCommitmentGateway()
          ..commitments = [
            membershipCommitmentFixture(id: 'skill-stale', label: 'Old ladder'),
          ]
          ..options = [
            membershipCommitmentOptionFixture(
              id: 'skill-new',
              label: 'Painting',
            ),
          ];
        final app = await _pump(
          tester,
          chats: chats,
          participation: participation,
          commitments: commitments,
        );
        app.read(appRouterProvider).go('/messages/chats/chat-1/info');
        await tester.pumpAndSettle();

        expect(find.text('My commitments'), findsOneWidget);
        expect(find.text('Old ladder'), findsOneWidget);
        expect(
          find.byKey(const Key('project-chat-edit-commitments')),
          findsOneWidget,
        );
        expect(commitments.calls, contains('commitments:membership-current'));
        expect(commitments.calls, contains('options:membership-current'));
        expect(
          commitments.calls,
          isNot(contains('commitments:membership-old')),
        );

        await tester.ensureVisible(
          find.byKey(const Key('project-chat-edit-commitments')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('project-chat-edit-commitments')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Manage commitments'), findsOneWidget);
        expect(
          find.byKey(const Key('membership-commitment-save')),
          findsOneWidget,
        );
        expect(find.text('Old ladder · No longer requested'), findsOneWidget);
        expect(find.text('Painting'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('membership-commitment-save')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Painting'));
        await tester.pump();
        await tester.tap(find.byKey(const Key('membership-commitment-save')));
        await tester.pumpAndSettle();
        expect(find.text('Manage commitments'), findsNothing);
        expect(commitments.lastExpectedSkillIds, {'skill-stale'});
        expect(commitments.lastSkillIds, {'skill-stale', 'skill-new'});
      },
    );
  }

  testWidgets(
    'one-time participant actual contributions load only after View and stay read-only',
    (tester) async {
      final chats = FakeProjectChatGateway()
        ..summaries = [projectChatSummaryFixture()]
        ..histories['chat-1'] = [];
      final participation = FakeParticipationGateway()
        ..ownMemberships = [ownMembershipFixture(id: 'membership-current')];
      final actual = FakeActualContributionGateway()
        ..contributions = [
          actualContributionFixture(),
          substantialEffortFixture(),
        ];
      final app = await _pump(
        tester,
        chats: chats,
        participation: participation,
        actualContributions: actual,
      );
      app.read(appRouterProvider).go('/messages/chats/chat-1/info');
      await tester.pumpAndSettle();

      expect(find.text('Actual contributions'), findsOneWidget);
      expect(actual.calls, isEmpty);
      await tester.scrollUntilVisible(
        find.byKey(const Key('project-chat-actual-membership-current')),
        300,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -160));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('project-chat-actual-membership-current')),
      );
      await tester.pumpAndSettle();

      expect(actual.calls, ['contributions:membership-current']);
      expect(find.text('Carpentry'), findsOneWidget);
      expect(find.text('Substantial Effort / Energy'), findsOneWidget);
      expect(find.byKey(const Key('actual-contribution-save')), findsNothing);
    },
  );

  testWidgets(
    'rejoin episodes remain separate and opening one creates no fan-out',
    (tester) async {
      final chats = FakeProjectChatGateway()
        ..summaries = [projectChatSummaryFixture()]
        ..histories['chat-1'] = [];
      final participation = FakeParticipationGateway()
        ..ownMemberships = [
          ownMembershipFixture(
            id: 'membership-old',
            status: MembershipStatus.left,
            joinedAt: DateTime.utc(2026, 9, 1),
          ),
          ownMembershipFixture(
            id: 'membership-current',
            joinedAt: DateTime.utc(2026, 9, 12),
          ),
        ];
      final actual = FakeActualContributionGateway()
        ..contributions = [actualContributionFixture()];
      final app = await _pump(
        tester,
        chats: chats,
        participation: participation,
        actualContributions: actual,
      );
      app.read(appRouterProvider).go('/messages/chats/chat-1/info');
      await tester.pumpAndSettle();

      expect(find.text('Participation 2'), findsOneWidget);
      expect(find.text('Participation 1'), findsOneWidget);
      expect(find.textContaining('Left'), findsOneWidget);
      expect(
        tester
            .getTopLeft(
              find.byKey(
                const Key('actual-contribution-episode-membership-current'),
              ),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(
                  const Key('actual-contribution-episode-membership-old'),
                ),
              )
              .dy,
        ),
      );
      expect(actual.calls, isEmpty);
      await tester.scrollUntilVisible(
        find.byKey(const Key('project-chat-actual-membership-old')),
        300,
      );
      await tester.ensureVisible(
        find.byKey(const Key('project-chat-actual-membership-old')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('project-chat-actual-membership-old')),
      );
      await tester.pumpAndSettle();

      expect(actual.calls, ['contributions:membership-old']);
      expect(actual.calls, isNot(contains('contributions:membership-current')));
    },
  );

  testWidgets('former member info uses latest episode read-only', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [
        projectChatSummaryFixture(
          viewerRole: ProjectChatViewerRole.formerMember,
        ),
      ]
      ..histories['chat-1'] = [];
    final participation = FakeParticipationGateway()
      ..ownMemberships = [
        ownMembershipFixture(
          id: 'membership-older',
          status: MembershipStatus.removed,
          joinedAt: DateTime.utc(2026, 9, 1),
        ),
        ownMembershipFixture(
          id: 'membership-latest',
          status: MembershipStatus.left,
          joinedAt: DateTime.utc(2026, 9, 10),
        ),
      ];
    final commitments = FakeMembershipCommitmentGateway()
      ..commitments = [
        membershipCommitmentFixture(
          id: 'need-1',
          kind: MembershipCommitmentKind.resource,
          label: 'Wooden boards',
        ),
      ];
    final app = await _pump(
      tester,
      chats: chats,
      participation: participation,
      commitments: commitments,
    );
    app.read(appRouterProvider).go('/messages/chats/chat-1/info');
    await tester.pumpAndSettle();

    expect(find.text('Last commitments'), findsOneWidget);
    expect(find.text('Wooden boards'), findsOneWidget);
    expect(find.text('Read-only'), findsOneWidget);
    expect(
      find.byKey(const Key('project-chat-edit-commitments')),
      findsNothing,
    );
    expect(commitments.calls, contains('commitments:membership-latest'));
    expect(
      commitments.calls.where((call) => call.startsWith('options:')),
      isEmpty,
    );
  });

  testWidgets('current member zero state and option failure stay local', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final participation = FakeParticipationGateway()
      ..ownMemberships = [ownMembershipFixture()];
    final commitments = FakeMembershipCommitmentGateway()
      ..optionsError = StateError('private options diagnostic');
    final app = await _pump(
      tester,
      chats: chats,
      participation: participation,
      commitments: commitments,
    );
    app.read(appRouterProvider).go('/messages/chats/chat-1/info');
    await tester.pumpAndSettle();

    expect(find.text('Paint the square'), findsOneWidget);
    expect(find.text('No current commitments'), findsOneWidget);
    expect(
      find.byKey(const Key('project-chat-commitment-options-error')),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('private options diagnostic'), findsNothing);
    expect(
      find.byKey(const Key('project-chat-edit-commitments')),
      findsNothing,
    );
  });

  testWidgets('stale CAS keeps editor open with a safe live reload message', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final participation = FakeParticipationGateway()
      ..ownMemberships = [ownMembershipFixture()];
    final commitments = FakeMembershipCommitmentGateway()
      ..commitments = [membershipCommitmentFixture()]
      ..options = [
        membershipCommitmentOptionFixture(),
        membershipCommitmentOptionFixture(id: 'skill-2', label: 'Painting'),
      ]
      ..replaceErrors.add(
        const PostgrestException(
          message: 'private conflict diagnostic',
          code: 'PT409',
        ),
      );
    final app = await _pump(
      tester,
      chats: chats,
      participation: participation,
      commitments: commitments,
    );
    app.read(appRouterProvider).go('/messages/chats/chat-1/info');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-chat-edit-commitments')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Painting'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('membership-commitment-save')));
    await tester.pumpAndSettle();

    expect(find.text('Manage commitments'), findsOneWidget);
    expect(
      find.byKey(const Key('membership-commitment-action-error')),
      findsOneWidget,
    );
    expect(find.textContaining('changed elsewhere'), findsOneWidget);
    expect(find.textContaining('private conflict diagnostic'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('membership-commitment-save')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('55000 keeps current commitments visible without Edit', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final participation = FakeParticipationGateway()
      ..ownMemberships = [ownMembershipFixture()];
    final commitments = FakeMembershipCommitmentGateway()
      ..commitments = [membershipCommitmentFixture()]
      ..optionsError = const PostgrestException(
        message: 'private lifecycle diagnostic',
        code: '55000',
      );
    final app = await _pump(
      tester,
      chats: chats,
      participation: participation,
      commitments: commitments,
    );
    app.read(appRouterProvider).go('/messages/chats/chat-1/info');
    await tester.pumpAndSettle();

    expect(find.text('Carpentry'), findsOneWidget);
    expect(
      find.byKey(const Key('project-chat-commitments-read-only')),
      findsOneWidget,
    );
    expect(find.textContaining('can no longer be changed'), findsOneWidget);
    expect(
      find.byKey(const Key('project-chat-edit-commitments')),
      findsNothing,
    );
    expect(find.textContaining('private lifecycle diagnostic'), findsNothing);
  });

  testWidgets('membership resolution failure is local to group info', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final participation = FakeParticipationGateway()
      ..error = StateError('private participation diagnostic');
    final app = await _pump(tester, chats: chats, participation: participation);
    app.read(appRouterProvider).go('/messages/chats/chat-1/info');
    await tester.pumpAndSettle();

    expect(find.text('Paint the square'), findsOneWidget);
    expect(
      find.byKey(const Key('project-chat-commitments-error')),
      findsOneWidget,
    );
    expect(
      find.textContaining('private participation diagnostic'),
      findsNothing,
    );
  });

  testWidgets('Tavolo info maps to its canonical detail route', (tester) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [
        projectChatSummaryFixture(
          projectId: 'tavolo-1',
          projectKind: ProjectKind.recurring,
          projectTitle: 'Repair table',
        ),
      ]
      ..histories['chat-1'] = [];
    final participation = FakeParticipationGateway()
      ..ownMemberships = [
        ownMembershipFixture(
          id: 'tavolo-membership',
          projectId: 'tavolo-1',
          projectKind: ProjectKind.recurring,
        ),
      ];
    final app = await _pump(tester, chats: chats, participation: participation);
    final router = app.read(appRouterProvider);
    router.go('/messages/chats/chat-1/info');
    await tester.pumpAndSettle();

    expect(find.text('Tavolo'), findsOneWidget);
    expect(find.text('Actual contributions'), findsNothing);
    expect(
      find.byKey(const Key('project-chat-manage-participation')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('project-chat-open-project')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/tavoli/tavolo-1');
  });

  testWidgets('creator info maps to canonical Participation management', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [
        projectChatSummaryFixture(viewerRole: ProjectChatViewerRole.creator),
      ]
      ..histories['chat-1'] = [];
    final app = await _pump(tester, chats: chats);
    final router = app.read(appRouterProvider);
    router.go('/messages/chats/chat-1/info');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('project-chat-manage-participation')),
    );
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/proposals/proposal-1/participants',
    );
  });

  testWidgets('Group info exposes configured workspace to current users', (
    tester,
  ) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final workspace = FakeProjectWorkspaceGateway()
      ..workspace = projectWorkspaceFixture();
    final app = await _pump(tester, chats: chats, workspace: workspace);
    app.read(appRouterProvider).go('/messages/chats/chat-1/info');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('project-workspace-info-section')),
      findsOneWidget,
    );
    expect(find.text('drive.google.com'), findsOneWidget);
    expect(find.byKey(const Key('project-workspace-info-edit')), findsNothing);
  });

  testWidgets('Group info gives a manager Edit workspace', (tester) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [
        projectChatSummaryFixture(viewerRole: ProjectChatViewerRole.creator),
      ]
      ..histories['chat-1'] = [];
    final workspace = FakeProjectWorkspaceGateway()
      ..workspace = projectWorkspaceFixture();
    final app = await _pump(tester, chats: chats, workspace: workspace);
    app.read(appRouterProvider).go('/messages/chats/chat-1/info');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('project-workspace-info-edit')),
      findsOneWidget,
    );
  });

  testWidgets('delegate group info is labeled Co-organizer', (tester) async {
    final chats = FakeProjectChatGateway()
      ..summaries = [
        projectChatSummaryFixture(viewerRole: ProjectChatViewerRole.delegate),
      ]
      ..histories['chat-1'] = [];
    final app = await _pump(tester, chats: chats);
    app.read(appRouterProvider).go('/messages/chats/chat-1/info');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('project-chat-viewer-role')), findsOneWidget);
    expect(find.text('Co-organizer'), findsOneWidget);
    expect(find.text('Organizer'), findsNothing);
  });

  testWidgets('identity swap reconstructs the protected chat branch', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final chats = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final app = await _pump(tester, chats: chats, authGateway: auth);
    final router = app.read(appRouterProvider);
    router.go('/messages/chats/chat-1');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('project-chat-composer')),
      'Private draft from account A',
    );
    final oldSubscription = chats.subscriptions.last;

    auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'user-2')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/messages/chats/chat-1',
    );
    expect(find.text('Private draft from account A'), findsNothing);
    expect(oldSubscription.isClosed, isTrue);
    expect(chats.subscriptions.last.expectedProfileId, 'user-2');
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeProjectChatGateway chats,
  FakeProjectNeedsGateway? needs,
  FakeParticipationGateway? participation,
  FakeMembershipCommitmentGateway? commitments,
  FakeActualContributionGateway? actualContributions,
  FakeAuthGateway? authGateway,
  FakeMessageChatsGateway? unifiedChats,
  FakeProjectWorkspaceGateway? workspace,
  FakeProjectWorkspaceLauncher? workspaceLauncher,
}) async {
  final auth =
      authGateway ??
      FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'test-key',
          ),
        ),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = ProfileAnchorReadiness.complete,
        ),
        profileGatewayProvider.overrideWithValue(FakeProfileGateway()),
        messagesGatewayProvider.overrideWithValue(FakeMessagesGateway()),
        messageChatsGatewayProvider.overrideWithValue(
          unifiedChats ??
              (FakeMessageChatsGateway()
                ..items = [
                  for (final summary in chats.summaries)
                    projectMessageChatFixture(
                      chatId: summary.chatId,
                      projectId: summary.projectId,
                      title: summary.projectTitle,
                      projectKind: summary.projectKind,
                      viewerRole: summary.viewerRole,
                      isReadOnly: summary.isReadOnly,
                      messageId: summary.lastVisibleMessageId,
                      messageBody: summary.lastVisibleMessageBody,
                      activityAt: summary.activityAt,
                    ),
                ]),
        ),
        projectChatGatewayProvider.overrideWithValue(chats),
        resourceChatGatewayProvider.overrideWithValue(
          FakeResourceChatGateway(),
        ),
        projectNeedsGatewayProvider.overrideWithValue(
          needs ?? FakeProjectNeedsGateway(),
        ),
        projectWorkspaceGatewayProvider.overrideWithValue(
          workspace ?? FakeProjectWorkspaceGateway(),
        ),
        if (workspaceLauncher != null)
          projectWorkspaceLauncherProvider.overrideWithValue(workspaceLauncher),
        participationGatewayProvider.overrideWithValue(
          participation ?? FakeParticipationGateway(),
        ),
        membershipCommitmentGatewayProvider.overrideWithValue(
          commitments ?? FakeMembershipCommitmentGateway(),
        ),
        actualContributionGatewayProvider.overrideWithValue(
          actualContributions ?? FakeActualContributionGateway(),
        ),
        proposalGatewayProvider.overrideWithValue(
          FakeProposalGateway()..publicDetail = proposalDetailFixture(),
        ),
        recurringActivityGatewayProvider.overrideWithValue(
          FakeRecurringActivityGateway()
            ..publicDetail = publicRecurringDetailFixture(),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}
