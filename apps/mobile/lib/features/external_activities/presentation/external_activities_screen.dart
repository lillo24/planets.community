import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/browse_activity_switcher.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/application/activities_split_preference_controller.dart';
import '../application/external_activities_controller.dart';
import '../domain/external_activity.dart';
import 'external_activity_widgets.dart';

class ExternalActivitiesScreen extends ConsumerStatefulWidget {
  const ExternalActivitiesScreen({super.key});

  @override
  ConsumerState<ExternalActivitiesScreen> createState() =>
      _ExternalActivitiesScreenState();
}

class _ExternalActivitiesScreenState
    extends ConsumerState<ExternalActivitiesScreen>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  var _desiredActive = false;
  var _foreground = true;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state != AppLifecycleState.resumed) {
      _desiredActive = false;
      ref.read(externalActivitiesControllerProvider.notifier).setActive(false);
    }
    setState(() => _foreground = state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _filter({String? category, String? discipline}) {
    _debounce?.cancel();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    ref
        .read(externalActivitiesControllerProvider.notifier)
        .filter(
          ExternalActivityFilter(
            category: category,
            discipline: discipline,
            query: _search.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(activitiesSplitPreferenceProvider).enabled;
    final state = ref.watch(externalActivitiesControllerProvider);
    final active =
        enabled &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (active != _desiredActive) {
      _desiredActive = active;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _desiredActive == active) {
          ref
              .read(externalActivitiesControllerProvider.notifier)
              .setActive(active);
        }
      });
    }
    if (!enabled) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final controller = ref.read(externalActivitiesControllerProvider.notifier);
    final page = state.page;
    final healthMessage = externalHealthMessage(page?.health, l);
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l.activitiesTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                key: const PageStorageKey('external-activities-list'),
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
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
                      for (final category in [null, 'sports', 'culture'])
                        ChoiceChip(
                          key: Key('activities-category-${category ?? 'all'}'),
                          selected: state.filter.category == category,
                          label: Text(switch (category) {
                            'sports' => l.activitiesSports,
                            'culture' => l.activitiesCulture,
                            _ => l.activitiesAll,
                          }),
                          onSelected: (_) => _filter(category: category),
                        ),
                    ],
                  ),
                  if (state.filter.category != 'sports') ...[
                    const SizedBox(height: AppSpacing.medium),
                    Card(
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
                    l.activitiesExternalTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(l.activitiesExternalScope),
                  TextButton.icon(
                    key: const Key('activities-preview-examples'),
                    onPressed: () => context.push('/activities/examples'),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(l.activitiesPreviewExamples),
                  ),
                  TextField(
                    key: const Key('activities-external-search'),
                    controller: _search,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: l.activitiesSearchExternal,
                      counterText: '',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l.activitiesClearSearch,
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _search.clear();
                                _filter(
                                  category: state.filter.category,
                                  discipline: state.filter.discipline,
                                );
                              },
                            ),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          _filter(
                            category: state.filter.category,
                            discipline: state.filter.discipline,
                          );
                        }
                      });
                    },
                  ),
                  if (page != null &&
                      page.disciplines.isNotEmpty &&
                      state.filter.category == 'sports')
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'external-discipline-${state.filter.discipline}',
                      ),
                      initialValue: state.filter.discipline,
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
                        for (final discipline in page.disciplines)
                          DropdownMenuItem(
                            value: discipline,
                            child: Text(discipline),
                          ),
                      ],
                      onChanged: (value) => _filter(
                        category: state.filter.category,
                        discipline: value,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.medium),
                  if (state.loading) ...[
                    Text(l.activitiesExternalLoading),
                    const LinearProgressIndicator(
                      key: Key('external-activities-loading'),
                    ),
                  ],
                  if (state.failed) ...[
                    Text(
                      l.activitiesExternalReadFailed,
                      key: const Key('external-activities-read-error'),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: controller.refresh,
                        child: Text(l.retryAction),
                      ),
                    ),
                  ],
                  if (healthMessage != null)
                    Text(
                      healthMessage,
                      key: const Key('external-activities-health'),
                    ),
                  if (!state.loading &&
                      !state.failed &&
                      page != null &&
                      page.items.isEmpty &&
                      {
                        ExternalCatalogueHealth.healthy,
                        ExternalCatalogueHealth.empty,
                      }.contains(page.health))
                    Text(
                      l.activitiesExternalEmpty,
                      key: const Key('external-activities-empty'),
                    ),
                  for (final item in page?.items ?? <ExternalActivity>[])
                    ExternalActivityCard(
                      key: ValueKey('external-${item.id}'),
                      item: item,
                      onTap: () =>
                          context.push('/activities/external/${item.id}'),
                    ),
                  if (state.moreFailed) Text(l.activitiesExternalReadFailed),
                  if (page?.nextCursor != null)
                    TextButton(
                      key: const Key('external-activities-load-more'),
                      onPressed: state.loading ? null : controller.loadMore,
                      child: Text(
                        state.moreFailed
                            ? l.retryAction
                            : l.activitiesExternalLoadMore,
                      ),
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
