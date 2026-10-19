import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/activity_example.dart';

String exampleFormatLabel(AppLocalizations l, ExampleFormat format) =>
    switch (format) {
      ExampleFormat.event => l.activitiesSingleEvent,
      ExampleFormat.recurring => l.activitiesRecurring,
      ExampleFormat.course => l.activitiesCourse,
    };

String exampleCategoryLabel(AppLocalizations l, ExampleCategory category) =>
    switch (category) {
      ExampleCategory.sports => l.activitiesSports,
      ExampleCategory.culture => l.activitiesCulture,
    };

class ExampleBadge extends StatelessWidget {
  const ExampleBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: AppRadii.medium,
    ),
    child: Text(
      AppLocalizations.of(context).activitiesExample,
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSecondaryContainer),
    ),
  );
}

class ActivityExampleCard extends StatelessWidget {
  const ActivityExampleCard({
    required this.item,
    required this.onTap,
    super.key,
  });
  final ActivityExample item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.xSmall,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const ExampleBadge(),
                  Text(
                    item.discipline?.label.inLanguage(language) ??
                        exampleCategoryLabel(l, item.category),
                  ),
                  Text(exampleFormatLabel(l, item.format)),
                ],
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                item.title.inLanguage(language),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xSmall),
              Text(
                item.schedule?.inLanguage(language) ??
                    l.activitiesScheduleUnknown,
              ),
              const SizedBox(height: AppSpacing.xSmall),
              Text(item.city, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
