import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_command_controller.dart';
import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/application/return_destination.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/request_code_screen.dart';
import '../../features/auth/presentation/verify_code_screen.dart';
import '../../features/profile/presentation/profile_edit_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/proposals/presentation/own_proposals_screen.dart';
import '../../features/proposals/presentation/proposal_editor_screen.dart';
import '../../features/proposals/presentation/public_proposals_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../foundation_screen.dart';

typedef AuthSessionReader = AuthSessionState Function();
typedef PendingEmailOtpReader = PendingEmailOtp? Function();

GoRouter createAppRouter({
  String initialLocation = '/',
  AuthSessionReader? readAuthSession,
  PendingEmailOtpReader? readPendingEmailOtp,
}) {
  final sessionReader =
      readAuthSession ?? () => const AuthSessionState.signedOut();
  final pendingReader = readPendingEmailOtp ?? () => null;

  return GoRouter(
    initialLocation: initialLocation,
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

      if (session.phase == AuthSessionPhase.restoring) {
        return null;
      }

      if (session.phase == AuthSessionPhase.signedOut &&
          (isProfileRoute || isProposalManagementRoute)) {
        return Uri(
          path: '/auth',
          queryParameters: {'returnTo': state.uri.toString()},
        ).toString();
      }

      if (session.phase == AuthSessionPhase.profileSetupRequired &&
          isProposalManagementRoute) {
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
      GoRoute(path: '/', builder: (context, state) => const FoundationScreen()),
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
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/proposals',
        builder: (context, state) => const PublicProposalsScreen(),
      ),
      GoRoute(
        path: '/proposals/mine',
        builder: (context, state) => const OwnProposalsScreen(),
      ),
      GoRoute(
        path: '/proposals/create',
        builder: (context, state) => const ProposalEditorScreen(),
      ),
      GoRoute(
        path: '/proposals/:id/edit',
        builder: (context, state) =>
            ProposalEditorScreen(proposalId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/proposals/:id',
        builder: (context, state) =>
            ProposalDetailScreen(proposalId: state.pathParameters['id']!),
      ),
    ],
    errorBuilder: (context, state) => const _UnknownRouteScreen(),
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter(
    readAuthSession: () => ref.read(authSessionProvider),
    readPendingEmailOtp: () => ref.read(pendingEmailOtpProvider),
  );
  ref.listen(authSessionProvider, (_, _) => router.refresh());
  ref.listen(pendingEmailOtpProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
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
