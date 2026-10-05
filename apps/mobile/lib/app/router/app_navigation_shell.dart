import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../devtools/demo/demo_tools.dart';
import '../../devtools/demo/demo_widgets.dart';
import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/notifications/application/notifications_controllers.dart';
import '../../features/moderation/presentation/moderation_evidence_session_prompt.dart';
import '../../l10n/generated/app_localizations.dart';
import 'draft_departure_coordinator.dart';

enum AppBranch { profile, home, browse }

class AppNavigationShell extends ConsumerWidget {
  const AppNavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final demoToolsEnabled = ref.watch(demoToolsEnabledProvider);
    // Imperative push history belongs to the branch Navigator even when the
    // shell route URI still names that branch's public root.
    final branchCanPop = navigationShell
        .route
        .branches[navigationShell.currentIndex]
        .navigatorKey
        .currentState
        ?.canPop();
    final path = GoRouterState.of(context).uri.path;
    final isSecondaryRoot =
        (navigationShell.currentIndex == AppBranch.profile.index &&
            path == '/profile') ||
        (navigationShell.currentIndex == AppBranch.browse.index &&
            (path == '/proposals' ||
                path == '/tavoli' ||
                path == '/resources'));
    final returnsHomeOnBack = branchCanPop != true && isSecondaryRoot;
    final scaffold = Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          navigationShell,
          if (demoToolsEnabled)
            const Positioned(
              right: AppSpacing.small,
              bottom: AppSpacing.small,
              child: IgnorePointer(child: DemoIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          if (ref.read(draftDepartureProvider).preparing) return;
          if (index == AppBranch.home.index) {
            FocusManager.instance.primaryFocus?.unfocus();
            navigationShell.goBranch(index, initialLocation: true);
            final session = ref.read(authSessionProvider);
            final profileId = session.phase == AuthSessionPhase.ready
                ? session.identity?.id
                : null;
            if (profileId != null) {
              unawaited(
                ref
                    .read(notificationsUnreadProvider.notifier)
                    .load(profileId, refresh: true),
              );
            }
          } else if (index != navigationShell.currentIndex) {
            // Profile and Browse retain their nested state across tab switches.
            FocusManager.instance.primaryFocus?.unfocus();
            navigationShell.goBranch(index);
          }
        },
        destinations: [
          NavigationDestination(
            key: const Key('nav-profile'),
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navigationProfile,
          ),
          NavigationDestination(
            key: const Key('nav-home'),
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navigationHome,
          ),
          NavigationDestination(
            key: const Key('nav-browse'),
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: l10n.navigationBrowse,
          ),
        ],
      ),
    );
    return PopScope(
      canPop: !returnsHomeOnBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && returnsHomeOnBack) {
          navigationShell.goBranch(AppBranch.home.index, initialLocation: true);
        }
      },
      child: ModerationEvidenceSessionPromptHost(child: scaffold),
    );
  }
}
