import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/activities_split_preference_controller.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/activity_examples.dart';
import 'activity_example_widgets.dart';

class ActivityExampleDetailScreen extends ConsumerWidget {
  const ActivityExampleDetailScreen({required this.exampleId, super.key});
  final String exampleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(activitiesSplitPreferenceProvider).enabled) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final item = activityExampleById(exampleId);
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l.activitiesExampleDetail)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: ListView(
              key: const Key('activity-example-detail'),
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: item == null
                  ? [Text(l.activitiesExampleUnavailable)]
                  : [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: ExampleBadge(),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        item.title.inLanguage(language),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Text(l.activitiesExampleDetailNotice),
                      const SizedBox(height: AppSpacing.large),
                      Text(
                        item.discipline?.label.inLanguage(language) ??
                            exampleCategoryLabel(l, item.category),
                      ),
                      Text(exampleFormatLabel(l, item.format)),
                      Text(item.city),
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        item.schedule?.inLanguage(language) ??
                            l.activitiesScheduleUnknown,
                      ),
                      if (item.level != null)
                        Text(item.level!.inLanguage(language)),
                      if (item.cost != null)
                        Text(item.cost!.inLanguage(language)),
                      const SizedBox(height: AppSpacing.large),
                      Text(item.description.inLanguage(language)),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
