import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../settings/application/activities_split_preference_controller.dart';

import '../../../app/router/browse_activity_switcher.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/activity_examples.dart';
import '../domain/activity_example.dart';
import 'activity_example_widgets.dart';

/// Explicit fictional preview. The main route uses ExternalActivitiesScreen.
class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  ExampleCategory? _category;
  ExampleDiscipline? _discipline;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    FocusScope.of(context).unfocus();
    _scroll.jumpTo(0);
    _search.clear();
    _discipline = null;
    _category = null;
  });

  @override
  Widget build(BuildContext context) {
    // Retained inactive Browse pages must not expose fixtures while disabled.
    if (!ref.watch(activitiesSplitPreferenceProvider).enabled) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final items = filterActivityExamples(
      activityExamples,
      category: _category,
      discipline: _discipline,
      query: _search.text,
      languageCode: language,
    );
    final disciplines = activityExamples
        .where((item) => item.category == ExampleCategory.sports)
        .map((item) => item.discipline)
        .nonNulls
        .toSet();

    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(l.activitiesExamplesPreviewTitle),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: ListView(
              key: const PageStorageKey('activities-sandbox-list'),
              controller: _scroll,
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                const BrowseActivitySwitcher(
                  selected: BrowseActivityType.activities,
                ),
                const SizedBox(height: AppSpacing.medium),
                Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: AppSpacing.xSmall,
                  children: [
                    for (final category in [null, ...ExampleCategory.values])
                      ChoiceChip(
                        key: Key(
                          'activities-category-${category?.name ?? 'all'}',
                        ),
                        label: Text(
                          category == null
                              ? l.activitiesAll
                              : exampleCategoryLabel(l, category),
                        ),
                        selected: _category == category,
                        onSelected: (_) => setState(() {
                          _category = category;
                          _discipline = null;
                        }),
                      ),
                  ],
                ),
                if (_category != ExampleCategory.sports) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: const Key('activities-native-tavoli'),
                      leading: const Icon(Icons.autorenew),
                      title: Text(l.tavoliTitle),
                      subtitle: Text(l.activitiesNativeTavoliHelp),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/tavoli'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.large),
                Text(
                  l.activitiesCatalogueTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(l.activitiesExampleNotice),
                const SizedBox(height: AppSpacing.medium),
                TextField(
                  key: const Key('activities-example-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l.activitiesSearchExamples,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l.activitiesClearSearch,
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
                if (_category == ExampleCategory.sports) ...[
                  const SizedBox(height: AppSpacing.medium),
                  DropdownButtonFormField<ExampleDiscipline?>(
                    key: ValueKey(
                      'activities-discipline-${_discipline?.name ?? 'all'}',
                    ),
                    initialValue: _discipline,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: InputDecoration(
                      labelText: l.activitiesDiscipline,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l.activitiesAllDisciplines),
                      ),
                      for (final discipline in disciplines)
                        DropdownMenuItem(
                          value: discipline,
                          child: Text(discipline.label.inLanguage(language)),
                        ),
                    ],
                    onChanged: (value) => setState(() => _discipline = value),
                  ),
                ],
                const SizedBox(height: AppSpacing.medium),
                if (items.isEmpty) ...[
                  Text(
                    l.activitiesNoExamples,
                    key: const Key('activities-examples-empty'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('activities-reset-examples'),
                      onPressed: _reset,
                      child: Text(l.activitiesReset),
                    ),
                  ),
                ],
                for (final item in items)
                  ActivityExampleCard(
                    key: ValueKey(item.id),
                    item: item,
                    onTap: () =>
                        context.push('/activities/examples/${item.id}'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
