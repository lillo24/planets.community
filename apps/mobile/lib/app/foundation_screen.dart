import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_tokens.dart';
import '../features/auth/presentation/auth_status.dart';
import '../features/notifications/presentation/home_notification_button.dart';
import '../l10n/generated/app_localizations.dart';
import 'router/app_navigation_shell.dart';

class FoundationScreen extends StatelessWidget {
  const FoundationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          const HomeNotificationButton(),
          IconButton(
            key: const Key('open-messages-button'),
            tooltip: l10n.messagesOpenTooltip,
            onPressed: () => context.push('/messages'),
            icon: const Icon(Icons.mail_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    l10n.foundationTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    l10n.foundationMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.large),
                  const AuthStatus(),
                  const SizedBox(height: AppSpacing.medium),
                  _HomePillarCard(
                    key: const Key('browse-proposals-button'),
                    icon: Icons.explore_outlined,
                    title: l10n.homeProjectsTitle,
                    message: l10n.homeProjectsMessage,
                    onTap: () =>
                        StatefulNavigationShell.of(context)
                            .goBranch(AppBranch.browse.index),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  _HomePillarCard(
                    key: const Key('browse-resources-button'),
                    icon: Icons.inventory_2_outlined,
                    title: l10n.resourceTitle,
                    message: l10n.homeResourcesMessage,
                    onTap: () => context.go('/resources'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePillarCard extends StatelessWidget {
  const _HomePillarCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(message),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
