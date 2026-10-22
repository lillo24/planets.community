import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/activities_split_preference_controller.dart';
import '../data/external_activity_gateway.dart';
import '../domain/external_activity.dart';

class ExternalActivitiesState {
  const ExternalActivitiesState({
    this.filter = const ExternalActivityFilter(),
    this.page,
    this.loading = false,
    this.failed = false,
    this.moreFailed = false,
  });
  final ExternalActivityFilter filter;
  final ExternalActivityPage? page;
  final bool loading, failed, moreFailed;
}

class ExternalActivitiesController extends Notifier<ExternalActivitiesState> {
  var _active = false;
  var _generation = 0;

  @override
  ExternalActivitiesState build() {
    ref.onDispose(() {
      _generation++;
      _active = false;
    });
    return const ExternalActivitiesState();
  }

  bool get _canRead =>
      _active && ref.read(activitiesSplitPreferenceProvider).enabled;

  void setActive(bool value) {
    if (_active == value) return;
    _active = value;
    if (!value) {
      _generation++;
      if (state.loading) {
        state = ExternalActivitiesState(
          filter: state.filter,
          page: state.page,
          failed: state.failed,
          moreFailed: state.moreFailed,
        );
      }
    } else if (state.page == null && !state.failed) {
      refresh();
    }
  }

  Future<void> filter(ExternalActivityFilter value) async {
    if (state.filter == value) return;
    _generation++;
    state = ExternalActivitiesState(filter: value);
    await refresh();
  }

  Future<void> refresh() => _load(false);
  Future<void> loadMore() => _load(true);

  Future<void> _load(bool append) async {
    if (!_canRead ||
        (state.loading && append) ||
        (append && state.page?.nextCursor == null)) {
      return;
    }
    final generation = ++_generation;
    final old = state.page;
    final filter = state.filter;
    final cursor = append ? old!.nextCursor : null;
    state = ExternalActivitiesState(filter: filter, page: old, loading: true);
    try {
      final page = await ref
          .read(externalActivityGatewayProvider)
          .list(filter, cursor: cursor);
      if (!ref.mounted || generation != _generation || !_canRead) return;
      if (page.health == ExternalCatalogueHealth.unconfigured) {
        // An explicit server disable replaces the retained public snapshot,
        // including when it arrives while continuing an older cursor.
        state = ExternalActivitiesState(filter: filter, page: page);
        return;
      }
      if (filter.discipline != null &&
          !page.disciplines.contains(filter.discipline)) {
        await this.filter(
          ExternalActivityFilter(
            category: filter.category,
            query: filter.query,
          ),
        );
        return;
      }
      if (append &&
          (jsonEncode(cursor) == jsonEncode(page.nextCursor) ||
              page.items.any(
                (item) => old!.items.any((previous) => previous.id == item.id),
              ))) {
        throw const FormatException('Nonadvancing external catalogue page.');
      }
      state = ExternalActivitiesState(
        filter: filter,
        page: ExternalActivityPage(
          health: page.health,
          asOf: page.asOf,
          items: [if (append) ...old!.items, ...page.items],
          disciplines: page.disciplines,
          nextCursor: page.nextCursor,
          lastSuccessAt: page.lastSuccessAt,
        ),
      );
    } on ExternalActivityCursorExpired {
      if (!ref.mounted || generation != _generation || !_canRead) return;
      await refresh();
    } catch (_) {
      // This is the request/UI boundary: keep a visible failure, including when
      // retaining a previous public snapshot. Never replace failure with empty.
      if (!ref.mounted || generation != _generation || !_canRead) return;
      state = ExternalActivitiesState(
        filter: filter,
        page: old,
        failed: !append,
        moreFailed: append,
      );
    }
  }
}

final externalActivitiesControllerProvider =
    NotifierProvider.autoDispose<
      ExternalActivitiesController,
      ExternalActivitiesState
    >(
      ExternalActivitiesController.new,
      dependencies: [activitiesSplitPreferenceProvider],
    );

final externalActivityDetailProvider = FutureProvider.autoDispose
    .family<ExternalActivity?, String>((ref, id) {
      if (!ref.watch(activitiesSplitPreferenceProvider).enabled) return null;
      return ref.read(externalActivityGatewayProvider).get(id);
    }, dependencies: [activitiesSplitPreferenceProvider]);
