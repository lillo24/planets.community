import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../core/theme/app_tokens.dart';
import '../core/widgets/planets_hero.dart';
import '../features/help/presentation/help_routes.dart';
import '../features/notifications/presentation/home_notification_button.dart';
import '../l10n/generated/app_localizations.dart';

class FoundationScreen extends StatelessWidget {
  const FoundationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(l10n.appTitle),
        ),
        actions: [
          IconButton(
            key: const Key('open-help-button'),
            tooltip: l10n.helpTitle,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              context.push(HelpRoutes.path);
            },
            icon: const Icon(Icons.help_outline),
          ),
          const HomeNotificationButton(),
          IconButton(
            key: const Key('open-settings-button'),
            tooltip: l10n.settingsOpenTooltip,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale =
                    MediaQuery.textScalerOf(context).scale(14) / 14;
                // Give space back to the naturally sized cards before decoration.
                final heroHeight = (constraints.maxHeight * .42 / textScale)
                    .clamp(64.0, 240.0);
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  child: Stack(
                    // Let decoration use the scroll view's top padding while
                    // the viewport still clips it away from the app bar.
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        top: -heroHeight * .06,
                        child: RepaintBoundary(
                          child: PlanetsHero.home(logoAreaHeight: heroHeight),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: heroHeight),
                          _HomePillarCard(
                            key: const Key('browse-proposals-button'),
                            icon: Icons.explore_outlined,
                            title: l10n.homeProjectsTitle,
                            message: l10n.homeProjectsMessage,
                            onTap: () => context.go('/proposals'),
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
                    ],
                  ),
                );
              },
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
    color: Theme.of(context).colorScheme.surfaceContainerLow,
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
