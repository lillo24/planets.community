import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/browse_activity_switcher.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/application/activities_split_preference_controller.dart';
import '../../activity_interest/application/activity_interest_tracker.dart';
import '../../activity_interest/domain/activity_interest_event.dart';
import '../application/external_activities_controller.dart';
import '../domain/external_activity.dart';
import 'external_activity_widgets.dart';
import 'external_activity_filters.dart';

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
  final _openingActivities = <String>{};

  Future<void> _openActivity(ExternalActivity activity) async {
    if (!_openingActivities.add(activity.id)) return;
    final item = PublicActivityInterestItem.importedActivity(activity.id);
    if (item != null) {
      recordActivityInterest(ref, ActivityInterestEvent.cardOpened(item));
    }
    try {
      await context.push<void>('/activities/external/${activity.id}');
    } finally {
      _openingActivities.remove(activity.id);
    }
  }

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _search.text = ref.read(externalActivitiesControllerProvider).filter.query;
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

  void _apply(ExternalActivityFilter value) {
    _debounce?.cancel();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_search.text != value.query) _search.text = value.query;
    ref.read(externalActivitiesControllerProvider.notifier).filter(value);
  }

  void _searchChanged() {
    final filter = ref.read(externalActivitiesControllerProvider).filter;
    _apply(
      ExternalActivityFilter(
        category: filter.category,
        area: filter.area,
        discipline: filter.discipline,
        kind: filter.kind,
        from: filter.from,
        to: filter.to,
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
                  ExternalActivityFilters(
                    filter: state.filter,
                    disciplines: page?.disciplines ?? const [],
                    onChanged: _apply,
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(l.activitiesExternalScope),
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
                                _searchChanged();
                              },
                            ),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          _searchChanged();
                        }
                      });
                    },
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
                      onTap: () => _openActivity(item),
                    ),
                  TextButton.icon(
                    key: const Key('activities-preview-examples'),
                    onPressed: () => context.push('/activities/examples'),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(l.activitiesPreviewExamples),
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
