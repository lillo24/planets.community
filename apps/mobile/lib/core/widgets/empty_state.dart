import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_tokens.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({this.title, this.message, this.icon, super.key});

  final String? title;
  final String? message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon ?? Icons.inbox_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                title ?? l10n.emptyStateTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                message ?? l10n.emptyStateMessage,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
