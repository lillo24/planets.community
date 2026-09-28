import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/notifications/application/notifications_controllers.dart';
import '../../features/moderation/presentation/corroboration_session_prompt.dart';
import '../../l10n/generated/app_localizations.dart';

enum AppBranch { profile, browse, home }

class AppNavigationShell extends ConsumerWidget {
  const AppNavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final path = GoRouterState.of(context).uri.path;
    final isBrowseRoot =
        navigationShell.currentIndex == AppBranch.browse.index &&
        (path == '/proposals' || path == '/tavoli');
    final scaffold = Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          // Retapping a tab must not pop an editor or discard unsaved input.
          if (index != navigationShell.currentIndex) {
            FocusManager.instance.primaryFocus?.unfocus();
            navigationShell.goBranch(index);
            if (index == AppBranch.home.index) {
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
            }
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
            key: const Key('nav-browse'),
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: l10n.navigationBrowse,
          ),
          NavigationDestination(
            key: const Key('nav-home'),
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navigationHome,
          ),
        ],
      ),
    );
    return PopScope(
      canPop: !isBrowseRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isBrowseRoot) {
          navigationShell.goBranch(AppBranch.home.index);
        }
      },
      child: CorroborationSessionPromptHost(child: scaffold),
    );
  }
}
