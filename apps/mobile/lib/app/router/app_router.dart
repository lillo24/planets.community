import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_command_controller.dart';
import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/application/return_destination.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/drafts/domain/draft_entry.dart';
import '../../features/drafts/presentation/drafts_screen.dart';
import '../../features/auth/presentation/request_code_screen.dart';
import '../../features/auth/presentation/account_suspension_screen.dart';
import '../../features/auth/presentation/verify_code_screen.dart';
import '../../features/blocking/presentation/blocked_users_screen.dart';
import '../../features/messages/presentation/messages_routes.dart';
import '../../features/messages/presentation/messages_landing_screen.dart';
import '../../features/messages/presentation/participation_request_message_screen.dart';
import '../../features/moderation/domain/moderation_models.dart';
import '../../features/moderation/presentation/counterstatement_screen.dart';
import '../../features/moderation/presentation/own_reports_screen.dart';
import '../../features/moderation/presentation/own_consequences_screen.dart';
import '../../features/moderation/presentation/corroboration_screens.dart';
import '../../features/moderation/presentation/moderation_evidence_requests_screen.dart';
import '../../features/moderation/presentation/moderation_routes.dart';
import '../../features/moderation/presentation/report_form_screen.dart';
import '../../features/notifications/presentation/notification_preferences_screen.dart';
import '../../features/notifications/presentation/notification_routes.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_edit_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/project_chat/presentation/project_chat_info_screen.dart';
import '../../features/project_chat/presentation/project_chat_screen.dart';
import '../../features/project_delegates/presentation/project_coorganizers_screen.dart';
import '../../features/project_delegates/presentation/project_delegate_routes.dart';
import '../../features/project_delegates/presentation/project_invite_screen.dart';
import '../../features/project_delegates/presentation/project_manage_screen.dart';
import '../../features/project_participant_invites/presentation/participant_invitation_routes.dart';
import '../../features/project_participant_invites/presentation/participant_invite_screen.dart';
import '../../features/project_participant_invites/presentation/participant_link_management_screen.dart';
import '../../features/project_request_chat/presentation/project_request_chat_screen.dart';
import '../../features/project_resource_needs/presentation/project_resource_need_routes.dart';
import '../../features/project_resource_needs/presentation/project_resource_matches_screen.dart';
import '../../features/project_resource_needs/presentation/project_resource_needs_screen.dart';
import '../../features/project_workspace/presentation/project_workspace_routes.dart';
import '../../features/project_workspace/presentation/project_workspace_screen.dart';
import '../../features/participation/domain/participation_models.dart';
import '../../features/participation/presentation/creator_participation_screen.dart';
import '../../features/participation/presentation/join_request_screen.dart';
import '../../features/participation/presentation/participation_routes.dart';
import '../../features/proposals/presentation/own_proposals_screen.dart';
import '../../features/proposals/presentation/proposal_editor_screen.dart';
import '../../features/proposals/presentation/proposal_creation_choice.dart';
import '../../features/proposals/presentation/public_proposals_screen.dart';
import '../../features/template_workshop/presentation/template_workshop_screens.dart';
import '../../features/recurring_activities/presentation/own_recurring_activities_screen.dart';
import '../../features/recurring_activities/presentation/public_recurring_activities_screen.dart';
import '../../features/recurring_activities/presentation/recurring_activity_editor_screen.dart';
import '../../features/resource_listings/presentation/own_resource_listings_screen.dart';
import '../../features/resource_listings/presentation/public_resource_listings_screen.dart';
import '../../features/resource_listings/presentation/resource_listing_editor_screen.dart';
import '../../features/resource_loans/presentation/resource_loan_schedule_screen.dart';
import '../../features/resource_chat/presentation/resource_chat_screen.dart';
import '../../features/resource_requests/presentation/resource_request_screen.dart';
import '../../features/resource_saved_searches/presentation/resource_saved_search_routes.dart';
import '../../features/resource_saved_searches/presentation/resource_saved_searches_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/navigation_selection_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../foundation_screen.dart';
import '../startup/startup_flow.dart';
import '../startup/welcome_screen.dart';
import '../startup/tutorial_screen.dart';
import '../startup/tutorial_routes.dart';
import 'app_navigation_shell.dart';
import 'native_project_links.dart';
import 'draft_departure_coordinator.dart';

typedef AuthSessionReader = AuthSessionState Function();
typedef PendingEmailOtpReader = PendingEmailOtp? Function();

GoRouter createAppRouter({
  String initialLocation = '/',
  AuthSessionReader? readAuthSession,
  PendingEmailOtpReader? readPendingEmailOtp,
  DraftDepartureCoordinator? draftDeparture,
  StartupFlow? startupFlow,
}) {
  final configuration = _NativeRoutingConfig(
    _routingConfig(
      readAuthSession,
      readPendingEmailOtp,
      draftDeparture,
      null,
      startupFlow,
    ),
    draftDeparture,
  );
  final router = GoRouter.routingConfig(
    routingConfig: configuration,
    initialLocation: initialLocation,
    errorBuilder: (context, state) => const _UnknownRouteScreen(),
  );
  configuration.readIncomingUri = () =>
      router.routeInformationProvider.value.uri;
  return router;
}

RoutingConfig _routingConfig(
  AuthSessionReader? readAuthSession,
  PendingEmailOtpReader? readPendingEmailOtp,
  DraftDepartureCoordinator? draftDeparture, [
  VoidCallback? cancelExternalAuth,
  StartupFlow? startupFlow,
]) {
  final sessionReader =
      readAuthSession ?? () => const AuthSessionState.signedOut();
  final pendingReader = readPendingEmailOtp ?? () => null;

  return RoutingConfig(
    onEnter: (context, current, next, router) async {
      VoidCallback? committedNativeCancellation;
      if (next.uri.hasScheme || next.uri.hasAuthority) {
        final destination = nativeProjectDestination(next.uri);
        final continuation = current.uri.path == '/auth/verify'
            ? pendingReader()?.returnTo
            : current.uri.queryParameters['returnTo'];
        if (destination != null &&
            (current.uri.toString() == destination ||
                ((current.uri.path == '/auth' ||
                        current.uri.path == '/auth/verify' ||
                        current.uri.path == '/profile/edit') &&
                    continuation == destination))) {
          startupFlow?.deferForExternalJourney();
          return const Block.stop(); // Preserve the existing match list/form.
        }
        if (cancelExternalAuth != null &&
            (pendingReader() != null ||
                current.uri.path == '/auth' ||
                current.uri.path == '/auth/verify')) {
          committedNativeCancellation = cancelExternalAuth;
        }
      }
      final decision =
          await (draftDeparture?.onEnter(context, current, next, router) ??
              const Allow());
      if (decision is Block ||
          (committedNativeCancellation == null &&
              !next.uri.hasScheme &&
              !next.uri.hasAuthority)) {
        return decision;
      }
      return Allow(
        then: () async {
          await decision.then?.call();
          startupFlow?.deferForExternalJourney();
          committedNativeCancellation?.call();
        },
      );
    },
    redirect: (context, state) {
      if (state.uri.hasScheme || state.uri.hasAuthority) {
        return nativeProjectDestination(state.uri) ?? '/link-unavailable';
      }
      final session = sessionReader();
      final pending = pendingReader();
      final path = state.uri.path;
      if (startupFlow != null) {
        // Only the ordinary root is gated. Explicit links/continuations own
        // their journey, including during Auth restoration.
        if (path != '/' &&
            path != '/welcome' &&
            path != '/intro' &&
            path != '/auth' &&
            path != '/auth/verify' &&
            !startupFlow.hasEntered) {
          startupFlow.deferForExternalJourney();
        }
        if (path == '/' &&
            !startupFlow.hasEntered &&
            session.identity == null) {
          return '/welcome';
        }
        if (path == '/welcome' &&
            (startupFlow.hasEntered || session.identity != null)) {
          return '/';
        }
        if (path == '/intro' &&
            !startupFlow.needsTutorial &&
            state.extra is! TutorialReplayRequest) {
          return startupReturnDestination(
            state.uri.queryParameters['returnTo'],
          );
        }
      }
      final isRequestRoute = path == '/auth';
      final isVerifyRoute = path == '/auth/verify';
      final isAuthRoute = isRequestRoute || isVerifyRoute;
      final isModerationRoute =
          path == ModerationRoutes.ownNotices ||
          path.startsWith('/profile/reports') ||
          path.startsWith('/profile/review-requests');
      final isProfileEditRoute = path == '/profile/edit';
      final isProposalManagementRoute =
          path == DraftRoutes.path ||
          path == WorkshopRoutes.catalog ||
          path.startsWith('${WorkshopRoutes.catalog}/') ||
          path == '/proposals/mine' ||
          path == '/proposals/create' ||
          path == '/proposals/create/scratch' ||
          (path.startsWith('/proposals/') && path.endsWith('/edit'));
      final isTavoliManagementRoute =
          path == '/tavoli/mine' ||
          path == '/tavoli/create' ||
          (path.startsWith('/tavoli/') && path.endsWith('/edit'));
      final isResourceManagementRoute = _isResourceManagementPath(path);
      final isParticipationRoute = ParticipationRoutes.isParticipationPath(
        path,
      );
      final isProjectResourceNeedManagementRoute =
          ProjectResourceNeedRoutes.isManagementPath(path);
      final isProjectDelegateManagementRoute =
          ProjectDelegateRoutes.isManagementPath(path) ||
          ParticipantInvitationRoutes.isManagementPath(path);
      final isProjectWorkspaceManagementRoute =
          ProjectWorkspaceRoutes.isManagementPath(path);
      final isMessagesRoute = isMessagesPath(path) && path != '/messages';
      final isNotificationsRoute = isNotificationsPath(path);
      final isActivityManagementRoute =
          isProposalManagementRoute ||
          isTavoliManagementRoute ||
          isResourceManagementRoute ||
          isProjectResourceNeedManagementRoute ||
          isProjectDelegateManagementRoute ||
          isProjectWorkspaceManagementRoute ||
          isParticipationRoute ||
          isMessagesRoute ||
          isNotificationsRoute ||
          isModerationRoute;

      const accountStatusPath = '/account/suspended';
      // Welcome owns unresolved signed-out restoration and its retry UI. Once
      // an identity is known, all routes obey the canonical account gate.
      if (path == '/welcome' &&
          (session.phase == AuthSessionPhase.restoring ||
              session.phase == AuthSessionPhase.restorationFailed)) {
        return null;
      }
      if (session.phase == AuthSessionPhase.restoring ||
          session.phase == AuthSessionPhase.restorationFailed ||
          session.phase == AuthSessionPhase.checkingAccount ||
          session.phase == AuthSessionPhase.accountCheckFailed ||
          session.phase == AuthSessionPhase.checkingProfile ||
          session.phase == AuthSessionPhase.suspended) {
        if (path == accountStatusPath) return null;
        final returnTo = isAuthRoute
            ? pending?.returnTo ??
                  sanitizeReturnDestination(
                    state.uri.queryParameters['returnTo'],
                  )
            : state.uri.toString();
        return Uri(
          path: accountStatusPath,
          queryParameters: {'returnTo': returnTo},
        ).toString();
      }
      if (path == accountStatusPath) {
        return sanitizeReturnDestination(state.uri.queryParameters['returnTo']);
      }

      if (session.phase == AuthSessionPhase.signedOut &&
          (isProfileEditRoute || isActivityManagementRoute)) {
        return Uri(
          path: '/auth',
          queryParameters: {'returnTo': state.uri.toString()},
        ).toString();
      }

      if (session.phase == AuthSessionPhase.profileSetupRequired &&
          (isParticipationRoute ||
              isProjectResourceNeedManagementRoute ||
              isProjectDelegateManagementRoute ||
              isProjectWorkspaceManagementRoute ||
              isMessagesRoute ||
              isNotificationsRoute)) {
        return Uri(
          path: '/profile/edit',
          queryParameters: {'returnTo': state.uri.toString()},
        ).toString();
      }

      if (session.phase == AuthSessionPhase.profileSetupRequired &&
          isResourceManagementRoute) {
        return Uri(
          path: '/profile/edit',
          queryParameters: {'returnTo': state.uri.toString()},
        ).toString();
      }

      if (session.phase == AuthSessionPhase.profileSetupRequired &&
          isActivityManagementRoute) {
        return Uri(
          path: '/profile/edit',
          queryParameters: {'returnTo': state.uri.toString()},
        ).toString();
      }

      if (session.phase == AuthSessionPhase.profileSetupRequired &&
          session.hasProfileAnchor &&
          path == '/profile') {
        return '/profile/edit';
      }

      if (session.phase == AuthSessionPhase.ready && isAuthRoute) {
        final destination =
            pending?.returnTo ??
            sanitizeReturnDestination(state.uri.queryParameters['returnTo']);
        return startupFlow?.continueTo(destination) ?? destination;
      }

      if (session.phase == AuthSessionPhase.profileSetupRequired &&
          isAuthRoute) {
        final returnTo =
            pending?.returnTo ??
            sanitizeReturnDestination(state.uri.queryParameters['returnTo']);
        if (ParticipationRoutes.isParticipationPath(returnTo) ||
            ProjectResourceNeedRoutes.isManagementPath(returnTo) ||
            ProjectDelegateRoutes.isManagementPath(returnTo) ||
            ProjectWorkspaceRoutes.isManagementPath(returnTo) ||
            ProjectDelegateRoutes.isInvitePath(returnTo) ||
            ParticipantInvitationRoutes.isInvitePath(returnTo) ||
            (isMessagesPath(returnTo) &&
                Uri.parse(returnTo).path != '/messages') ||
            isNotificationsPath(returnTo) ||
            _isResourceManagementPath(returnTo)) {
          return Uri(
            path: '/profile/edit',
            queryParameters: {'returnTo': returnTo},
          ).toString();
        }
      }

      if ((session.phase == AuthSessionPhase.checkingProfile ||
              session.phase == AuthSessionPhase.profileSetupRequired) &&
          isAuthRoute &&
          !(isVerifyRoute && pending != null)) {
        if (session.phase == AuthSessionPhase.checkingProfile) return null;
        final destination =
            pending?.returnTo ??
            sanitizeReturnDestination(state.uri.queryParameters['returnTo']);
        return startupFlow?.continueTo(destination) ?? destination;
      }

      if (isVerifyRoute && pending == null) {
        final returnTo = sanitizeReturnDestination(
          state.uri.queryParameters['returnTo'],
        );
        return Uri(
          path: '/auth',
          queryParameters: returnTo == '/' ? null : {'returnTo': returnTo},
        ).toString();
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/intro',
        builder: (context, state) => TutorialScreen(
          returnTo: state.extra is TutorialReplayRequest
              ? (state.extra! as TutorialReplayRequest).returnTo
              : startupReturnDestination(state.uri.queryParameters['returnTo']),
          replay: state.extra is TutorialReplayRequest,
        ),
      ),
      GoRoute(
        path: '/link-unavailable',
        builder: (context, state) => const _UnknownRouteScreen(),
      ),
      GoRoute(
        path: '/account/suspended',
        builder: (context, state) => const AccountSuspensionScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => RequestCodeScreen(
          returnTo: sanitizeReturnDestination(
            state.uri.queryParameters['returnTo'],
          ),
        ),
      ),
      GoRoute(
        path: '/auth/verify',
        builder: (context, state) => const VerifyCodeScreen(),
      ),
      GoRoute(
        path: '/invite/project/:token',
        builder: (context, state) => ProjectInviteScreen(
          key: state.pageKey,
          token: state.pathParameters['token']!,
        ),
      ),
      GoRoute(
        path: '/join/project/:token',
        builder: (context, state) => ParticipantInviteScreen(
          key: state.pageKey,
          token: state.pathParameters['token']!,
        ),
      ),
      GoRoute(
        path: '/profile/reports/review-requests/corroboration/:requestId',
        redirect: (context, state) => ModerationRoutes.corroborationDetail(
          state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/profile/reports/review-requests/counterstatement/:requestId',
        redirect: (context, state) => ModerationRoutes.counterstatementDetail(
          state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/profile/reports/review-requests',
        redirect: (context, state) => ModerationRoutes.reviewRequests,
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AppNavigationShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    // Explicit Flutter page preserves the iOS edge detector;
                    // go_router 18's app-type adapter otherwise uses a page
                    // without transitions for this Flutter MaterialApp.
                    pageBuilder: (context, state) => MaterialPage<void>(
                      key: state.pageKey,
                      child: ProfileEditScreen(
                        returnTo: state.uri.queryParameters['returnTo'] == null
                            ? '/profile'
                            : sanitizeReturnDestination(
                                state.uri.queryParameters['returnTo'],
                              ),
                        cancelTo: profileEditCancelDestination(
                          state.uri.queryParameters['returnTo'],
                          profileReady:
                              sessionReader().phase == AuthSessionPhase.ready,
                        ),
                        returnByPop: canPopToProfileCancel(
                          context,
                          profileEditCancelDestination(
                            state.uri.queryParameters['returnTo'],
                            profileReady:
                                sessionReader().phase == AuthSessionPhase.ready,
                          ),
                        ),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'blocked-users',
                    builder: (context, state) => const BlockedUsersScreen(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (context, state) => const OwnReportsScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) {
                          final target = state.extra;
                          if (target is! ModerationReportTarget) {
                            return const _UnknownRouteScreen();
                          }
                          return ReportFormScreen(target: target);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'review-requests',
                    builder: (context, state) =>
                        const ModerationEvidenceRequestsScreen(),
                    routes: [
                      GoRoute(
                        path: 'corroboration/:requestId',
                        builder: (context, state) => CorroborationDetailScreen(
                          requestId: state.pathParameters['requestId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'counterstatement/:requestId',
                        builder: (context, state) =>
                            CounterstatementDetailScreen(
                              requestId: state.pathParameters['requestId']!,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const FoundationScreen(),
              ),
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'notices',
                    builder: (context, state) => const OwnConsequencesScreen(),
                  ),
                  GoRoute(
                    path: 'language',
                    builder: (context, state) =>
                        const LanguageSelectionScreen(),
                  ),
                  GoRoute(
                    path: 'navigation',
                    builder: (context, state) =>
                        const NavigationSelectionScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/messages',
                builder: (context, state) => const MessagesLandingScreen(),
                routes: [
                  GoRoute(
                    path: 'requests/resource/:requestId',
                    builder: (context, state) => ResourceRequestScreen(
                      key: state.pageKey,
                      requestId: state.pathParameters['requestId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'requests/:requestId',
                    builder: (context, state) =>
                        ParticipationRequestMessageScreen(
                          key: state.pageKey,
                          requestId: state.pathParameters['requestId']!,
                        ),
                  ),
                  GoRoute(
                    path: 'chats/resource/:chatId',
                    builder: (context, state) => ResourceChatScreen(
                      key: state.pageKey,
                      chatId: state.pathParameters['chatId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'chats/request/:requestId',
                    builder: (context, state) => ProjectRequestChatScreen(
                      key: state.pageKey,
                      requestId: state.pathParameters['requestId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'chats/:chatId',
                    builder: (context, state) => ProjectChatScreen(
                      key: state.pageKey,
                      chatId: state.pathParameters['chatId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'info',
                        builder: (context, state) => ProjectChatInfoScreen(
                          key: state.pageKey,
                          chatId: state.pathParameters['chatId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
                routes: [
                  GoRoute(
                    path: 'preferences',
                    builder: (context, state) =>
                        const NotificationPreferencesScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: '/proposals',
            routes: [
              GoRoute(
                path: DraftRoutes.path,
                pageBuilder: (context, state) => MaterialPage<void>(
                  key: state.pageKey,
                  child: DraftsScreen(
                    initialTypes: DraftRoutes.parse(
                      state.uri.queryParameters['types'],
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/proposals',
                // Family roots switch without a slide/fade. Detail/editor pages retain
                // native transitions and the existing departure guard.
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const PublicProposalsScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'workshop',
                    pageBuilder: (context, state) => MaterialPage<void>(
                      key: state.pageKey,
                      child: const TemplateWorkshopScreen(),
                    ),
                    routes: [
                      GoRoute(
                        path: ':templateId',
                        pageBuilder: (context, state) => MaterialPage<void>(
                          key: state.pageKey,
                          child: TemplateWorkshopDetailScreen(
                            templateId: state.pathParameters['templateId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'mine',
                    builder: (context, state) => const OwnProposalsScreen(),
                  ),
                  GoRoute(
                    path: 'create',
                    pageBuilder: (context, state) => MaterialPage<void>(
                      key: state.pageKey,
                      child: const ProposalCreationChoice(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'scratch',
                        onExit: draftDeparture?.onExit,
                        pageBuilder: (context, state) => MaterialPage<void>(
                          key: state.pageKey,
                          child: const ProposalEditorScreen(),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ProposalDetailScreen(
                      proposalId: state.pathParameters['id']!,
                      joinIntent: ParticipantInvitationRoutes.hasOrdinaryIntent(
                        state.uri,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'participant-links',
                        builder: (context, state) =>
                            ParticipantLinkManagementScreen(
                              projectId: state.pathParameters['id']!,
                              kind: ProjectKind.oneTime,
                            ),
                      ),
                      GoRoute(
                        path: 'edit',
                        onExit: draftDeparture?.onExit,
                        pageBuilder: (context, state) => MaterialPage<void>(
                          key: state.pageKey,
                          child: ProposalEditorScreen(
                            proposalId: state.pathParameters['id'],
                            returnToHub: state.extra == DraftEditorOrigin.hub,
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'resources',
                        builder: (context, state) => ProjectResourceNeedsScreen(
                          projectId: state.pathParameters['id']!,
                          projectKind: ProjectKind.oneTime,
                        ),
                        routes: [
                          GoRoute(
                            path: ':resourceNeedId/matches',
                            builder: (context, state) =>
                                ProjectResourceMatchesScreen(
                                  projectId: state.pathParameters['id']!,
                                  resourceNeedId:
                                      state.pathParameters['resourceNeedId']!,
                                ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'join',
                        builder: (context, state) => JoinRequestScreen(
                          projectId: state.pathParameters['id']!,
                          projectKind: ProjectKind.oneTime,
                        ),
                      ),
                      GoRoute(
                        path: 'participants',
                        builder: (context, state) => CreatorParticipationScreen(
                          projectId: state.pathParameters['id']!,
                          projectKind: ProjectKind.oneTime,
                        ),
                      ),
                      GoRoute(
                        path: 'manage',
                        builder: (context, state) => ProjectManageScreen(
                          projectId: state.pathParameters['id']!,
                          projectKind: ProjectKind.oneTime,
                        ),
                      ),
                      GoRoute(
                        path: 'co-organizers',
                        builder: (context, state) => ProjectTeamScreen(
                          projectId: state.pathParameters['id']!,
                          projectKind: ProjectKind.oneTime,
                        ),
                      ),
                      GoRoute(
                        path: 'workspace',
                        builder: (context, state) => ProjectWorkspaceScreen(
                          projectId: state.pathParameters['id']!,
                          projectKind: ProjectKind.oneTime,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/tavoli',
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const PublicRecurringActivitiesScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'mine',
                    builder: (context, state) =>
                        const OwnRecurringActivitiesScreen(),
                  ),
                  GoRoute(
                    path: 'create',
                    builder: (context, state) =>
                        const RecurringActivityEditorScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        PublicRecurringActivityDetailScreen(
                          activityId: state.pathParameters['id']!,
                          joinIntent:
                              ParticipantInvitationRoutes.hasOrdinaryIntent(
                                state.uri,
                              ),
                        ),
                    routes: [
                      GoRoute(
                        path: 'participant-links',
                        builder: (context, state) =>
                            ParticipantLinkManagementScreen(
                              projectId: state.pathParameters['id']!,
                              kind: ProjectKind.recurring,
                            ),
                      ),
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) =>
                            RecurringActivityEditorScreen(
                              activityId: state.pathParameters['id'],
                            ),
                      ),
                      GoRoute(
                        path: 'resources',
                        builder: (context, state) => ProjectResourceNeedsScreen(
                          projectId: state.pathParameters['id']!,
                          projectKind: ProjectKind.recurring,
                        ),
                        routes: [
                          GoRoute(
                            path: ':resourceNeedId/matches',
                            builder: (context, state) =>
                                ProjectResourceMatchesScreen(
                                  projectId: state.pathParameters['id']!,
                                  resourceNeedId:
                                      state.pathParameters['resourceNeedId']!,
                                ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'join',
                        builder: (context, state) => JoinRequestScreen(
                          projectId: state.pathParameters['id']!,
                          projectKind: ProjectKind.recurring,
                        ),
                      ),
                      GoRoute(
                        path: 'participants',
                        builder: (context, state) => CreatorParticipationScreen(
                          projectId: state.pathParameters['id']!,
                          projectKind: ProjectKind.recurring,
                        ),
                      ),
                      GoRoute(
                        path: 'manage',
                        builder: (context, state) => ProjectManageScreen(
                          projectId: state.pathParameters['id']!,
                          projectKind: ProjectKind.recurring,
                        ),
                      ),
                      GoRoute(
                        path: 'co-organizers',
                        builder: (context, state) => ProjectTeamScreen(
                          projectId: state.pathParameters['id']!,
                          projectKind: ProjectKind.recurring,
                        ),
                      ),
                      GoRoute(
                        path: 'workspace',
                        builder: (context, state) => ProjectWorkspaceScreen(
                          projectId: state.pathParameters['id']!,
                          projectKind: ProjectKind.recurring,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/resources',
                builder: (context, state) =>
                    const PublicResourceListingsScreen(),
                routes: [
                  GoRoute(
                    path: 'mine',
                    builder: (context, state) =>
                        const OwnResourceListingsScreen(),
                  ),
                  GoRoute(
                    path: 'create',
                    builder: (context, state) =>
                        const ResourceListingEditorScreen(),
                  ),
                  GoRoute(
                    path: 'saved-searches',
                    builder: (context, state) =>
                        const ResourceSavedSearchesScreen(),
                  ),
                  GoRoute(
                    path: ':listingId',
                    builder: (context, state) =>
                        PublicResourceListingDetailScreen(
                          listingId: state.pathParameters['listingId']!,
                        ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) =>
                            ResourceListingEditorScreen(
                              listingId: state.pathParameters['listingId'],
                            ),
                      ),
                      GoRoute(
                        path: 'loan-schedule',
                        builder: (context, state) => ResourceLoanScheduleScreen(
                          listingId: state.pathParameters['listingId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

bool _isResourceManagementPath(String destination) {
  final path = Uri.tryParse(destination)?.path;
  if (path == null) return false;
  if (ResourceSavedSearchRoutes.isManagementPath(path)) return true;
  if (path == '/resources/mine' || path == '/resources/create') return true;
  final segments = Uri(path: path).pathSegments;
  return segments.length == 3 &&
      segments.first == 'resources' &&
      (segments.last == 'edit' || segments.last == 'loan-schedule');
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final startup = ref.read(startupFlowProvider);
  RoutingConfig configuration() => _routingConfig(
    () => ref.read(authSessionProvider),
    () => ref.read(pendingEmailOtpProvider),
    ref.read(draftDepartureProvider),
    () => ref.read(authCommandProvider.notifier).cancelFlow(),
    startup,
  );
  final routes = _NativeRoutingConfig(
    configuration(),
    ref.read(draftDepartureProvider),
  );
  final router = GoRouter.routingConfig(
    routingConfig: routes,
    initialLocation: '/',
    errorBuilder: (context, state) => const _UnknownRouteScreen(),
  );
  routes.readIncomingUri = () => router.routeInformationProvider.value.uri;
  ref.listen(authSessionProvider, (previous, next) {
    if (next.identity != null) startup.enter();
    if ((previous?.identity?.id != next.identity?.id ||
            previous?.accountAccessIdentityId !=
                next.accountAccessIdentityId) &&
        router.routerDelegate.currentConfiguration.uri.path.isNotEmpty) {
      // Native entry may still be parsing when restored Auth arrives. There are
      // no retained stacks yet, and GoRouter cannot reparse its initial empty URI.
      // New shell/branch keys discard all retained forms and private stacks.
      // Reparse the current URL instead of losing an in-flight OTP returnTo.
      routes.value = configuration();
    }
    router.refresh();
  });
  ref.listen(pendingEmailOtpProvider, (_, _) => router.refresh());
  ref.listen(authCommandProvider, (previous, next) {
    if (next.didSignOut &&
        previous?.didSignOut != true &&
        ref.read(authSessionProvider).phase == AuthSessionPhase.signedOut) {
      startup.returnToWelcomeAfterSignOut();
      router.go('/welcome');
    }
  });
  startup.addListener(router.refresh);
  ref.onDispose(() => startup.removeListener(router.refresh));
  ref.onDispose(router.dispose);
  ref.onDispose(routes.dispose);
  return router;
}, dependencies: [startupFlowProvider]);

/// External deliveries compose native validation with draft departure. Ordinary
/// routes retain the draft hook while an editor owns it; startup without an
/// editor keeps main's synchronous path for restored Auth/loading UI.
/// This reads the existing provider; it registers no second platform listener.
class _NativeRoutingConfig extends ValueNotifier<RoutingConfig> {
  _NativeRoutingConfig(super.value, this.draftDeparture);

  final DraftDepartureCoordinator? draftDeparture;

  Uri Function()? readIncomingUri;

  @override
  RoutingConfig get value {
    final configuration = super.value;
    final incoming = readIncomingUri?.call();
    if (incoming != null && (incoming.hasScheme || incoming.hasAuthority)) {
      return configuration;
    }
    return RoutingConfig(
      onEnter: draftDeparture?.activeOwner == null
          ? null
          : draftDeparture?.onEnter,
      routes: configuration.routes,
      redirect: configuration.redirect,
      redirectLimit: configuration.redirectLimit,
    );
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.routeNotFound,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }
}
