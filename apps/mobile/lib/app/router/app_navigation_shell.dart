import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../devtools/demo/demo_tools.dart';
import '../../devtools/demo/demo_widgets.dart';
import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/messages/presentation/messages_routes.dart';
import '../../features/messages/presentation/message_unread_badge.dart';
import '../../features/notifications/application/notifications_controllers.dart';
import '../../features/moderation/presentation/moderation_evidence_session_prompt.dart';
import '../../features/settings/application/navigation_preference_controller.dart';
import '../../features/settings/domain/navigation_preference.dart';
import '../../l10n/generated/app_localizations.dart';

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
    final path = GoRouter.of(context).routerDelegate.state.uri.path;
    final preference = ref.watch(navigationPreferenceProvider).destination;
    final isMessages = isMessagesPath(path);
    // Cross-branch pushes can keep the originating Navigator's branch index.
    // The active URI identifies the screen actually visible above that stack.
    final routeRoot = Uri(path: path).pathSegments.firstOrNull;
    final isBrowse = switch (routeRoot) {
      'proposals' || 'tavoli' || 'resources' => true,
      _ => false,
    };
    // The visible slot follows direct/pushed routes while active. Elsewhere it
    // uses the device preference; the shell's three branches never change.
    final rightDestination = isBrowse
        ? BottomTabDestination.browse
        : isMessages
        ? BottomTabDestination.messages
        : preference;
    final selectedIndex = isBrowse || isMessages
        ? 2
        : routeRoot == 'profile'
        ? 0
        : 1;
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
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
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
          } else if (index == 2) {
            if (selectedIndex == 2) return;
            FocusManager.instance.primaryFocus?.unfocus();
            if (rightDestination == BottomTabDestination.messages) {
              context.go('/messages');
            } else {
              navigationShell.goBranch(AppBranch.browse.index);
            }
          } else if (index != selectedIndex) {
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
            key: Key(
              rightDestination == BottomTabDestination.messages
                  ? 'nav-messages'
                  : 'nav-browse',
            ),
            icon: rightDestination == BottomTabDestination.messages
                ? const MessageUnreadBadge(child: Icon(Icons.forum_outlined))
                : const Icon(Icons.explore_outlined),
            selectedIcon: rightDestination == BottomTabDestination.messages
                ? const MessageUnreadBadge(child: Icon(Icons.forum))
                : const Icon(Icons.explore),
            label: rightDestination == BottomTabDestination.messages
                ? l10n.messagesTitle
                : l10n.navigationBrowse,
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
