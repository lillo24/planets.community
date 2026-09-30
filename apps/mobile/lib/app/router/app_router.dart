import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_command_controller.dart';
import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/application/return_destination.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/request_code_screen.dart';
import '../../features/auth/presentation/verify_code_screen.dart';
import '../../features/messages/presentation/messages_routes.dart';
import '../../features/messages/presentation/messages_screen.dart';
import '../../features/messages/presentation/participation_request_message_screen.dart';
import '../../features/notifications/presentation/notification_preferences_screen.dart';
import '../../features/notifications/presentation/notification_routes.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_edit_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/project_chat/presentation/project_chat_info_screen.dart';
import '../../features/project_chat/presentation/project_chat_screen.dart';
import '../../features/project_resource_needs/presentation/project_resource_need_routes.dart';
import '../../features/project_resource_needs/presentation/project_resource_matches_screen.dart';
import '../../features/project_resource_needs/presentation/project_resource_needs_screen.dart';
import '../../features/participation/domain/participation_models.dart';
import '../../features/participation/presentation/creator_participation_screen.dart';
import '../../features/participation/presentation/join_request_screen.dart';
import '../../features/participation/presentation/participation_routes.dart';
import '../../features/proposals/presentation/own_proposals_screen.dart';
import '../../features/proposals/presentation/proposal_editor_screen.dart';
import '../../features/proposals/presentation/public_proposals_screen.dart';
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
import '../../l10n/generated/app_localizations.dart';
import '../foundation_screen.dart';
import 'app_navigation_shell.dart';

typedef AuthSessionReader = AuthSessionState Function();
typedef PendingEmailOtpReader = PendingEmailOtp? Function();

GoRouter createAppRouter({
  String initialLocation = '/',
  AuthSessionReader? readAuthSession,
  PendingEmailOtpReader? readPendingEmailOtp,
}) {
  final configuration = _routingConfig(readAuthSession, readPendingEmailOtp);
  return GoRouter(
    initialLocation: initialLocation,
    routes: configuration.routes,
    redirect: configuration.redirect,
    errorBuilder: (context, state) => const _UnknownRouteScreen(),
  );
}

RoutingConfig _routingConfig(
  AuthSessionReader? readAuthSession,
  PendingEmailOtpReader? readPendingEmailOtp,
) {
  final sessionReader =
      readAuthSession ?? () => const AuthSessionState.signedOut();
  final pendingReader = readPendingEmailOtp ?? () => null;

  return RoutingConfig(
    redirect: (context, state) {
      final session = sessionReader();
      final pending = pendingReader();
      final path = state.uri.path;
      final isRequestRoute = path == '/auth';
      final isVerifyRoute = path == '/auth/verify';
      final isAuthRoute = isRequestRoute || isVerifyRoute;
      final isProfileRoute = path == '/profile' || path == '/profile/edit';
      final isProposalManagementRoute =
          path == '/proposals/mine' ||
          path == '/proposals/create' ||
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
      final isMessagesRoute = isMessagesPath(path);
      final isNotificationsRoute = isNotificationsPath(path);
      final isActivityManagementRoute =
          isProposalManagementRoute ||
          isTavoliManagementRoute ||
          isResourceManagementRoute ||
          isProjectResourceNeedManagementRoute ||
          isParticipationRoute ||
          isMessagesRoute ||
          isNotificationsRoute;

      if (session.phase == AuthSessionPhase.restoring) {
        return null;
      }

      if (session.phase == AuthSessionPhase.signedOut &&
          (isProfileRoute || isActivityManagementRoute)) {
        return Uri(
          path: '/auth',
          queryParameters: {'returnTo': state.uri.toString()},
        ).toString();
      }

      if (session.phase == AuthSessionPhase.profileSetupRequired &&
          (isParticipationRoute ||
              isProjectResourceNeedManagementRoute ||
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
        return '/profile/edit';
      }

      if (session.phase == AuthSessionPhase.profileSetupRequired &&
          session.hasProfileAnchor &&
          path == '/profile') {
        return '/profile/edit';
      }

      if (session.phase == AuthSessionPhase.ready && isAuthRoute) {
        return pending?.returnTo ??
            sanitizeReturnDestination(state.uri.queryParameters['returnTo']);
      }

      if (session.phase == AuthSessionPhase.profileSetupRequired &&
          isAuthRoute) {
        final returnTo =
            pending?.returnTo ??
            sanitizeReturnDestination(state.uri.queryParameters['returnTo']);
        if (ParticipationRoutes.isParticipationPath(returnTo) ||
            ProjectResourceNeedRoutes.isManagementPath(returnTo) ||
            isMessagesPath(returnTo) ||
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
        return '/';
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
                    builder: (context, state) => ProfileEditScreen(
                      returnTo: state.uri.queryParameters['returnTo'] == null
                          ? '/profile'
                          : sanitizeReturnDestination(
                              state.uri.queryParameters['returnTo'],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/proposals',
                builder: (context, state) => const PublicProposalsScreen(),
                routes: [
                  GoRoute(
                    path: 'mine',
                    builder: (context, state) => const OwnProposalsScreen(),
                  ),
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const ProposalEditorScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ProposalDetailScreen(
                      proposalId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => ProposalEditorScreen(
                          proposalId: state.pathParameters['id'],
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
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/tavoli',
                builder: (context, state) =>
                    const PublicRecurringActivitiesScreen(),
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
                        ),
                    routes: [
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
                path: '/messages',
                builder: (context, state) => const MessagesScreen(),
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
  RoutingConfig configuration() => _routingConfig(
    () => ref.read(authSessionProvider),
    () => ref.read(pendingEmailOtpProvider),
  );
  final routes = ValueNotifier(configuration());
  final router = GoRouter.routingConfig(
    routingConfig: routes,
    initialLocation: '/',
    errorBuilder: (context, state) => const _UnknownRouteScreen(),
  );
  ref.listen(authSessionProvider, (previous, next) {
    if (previous?.identity?.id != next.identity?.id) {
      // New shell/branch keys discard all retained forms and private stacks.
      // Reparse the current URL instead of losing an in-flight OTP returnTo.
      routes.value = configuration();
    }
    router.refresh();
  });
  ref.listen(pendingEmailOtpProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  ref.onDispose(routes.dispose);
  return router;
});

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
