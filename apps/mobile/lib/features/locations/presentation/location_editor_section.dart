import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/location_editor_session.dart';
import '../application/place_search_controller.dart';
import '../data/item_location_gateway.dart';
import '../domain/item_location.dart';
import '../domain/place_search.dart';
import 'location_fallbacks.dart';
import 'location_attribution.dart';
export 'location_attribution.dart' show LocationAttribution;

/// An ordinary Save/Publish revokes any earlier location mutation intent. The
/// section suppresses this hook only for its own save-before-search operation.
class LocationEditorHandle {
  VoidCallback? _beforeSave;
  void beforeContentSave() => _beforeSave?.call();
}

/// Manual fields stay functional while registration is disabled. An injected
/// factory exercises the same receipt transaction used by future activation.
class LocationEditorSection extends ConsumerStatefulWidget {
  const LocationEditorSection({
    super.key,
    required this.actorId,
    required this.itemKind,
    required this.itemId,
    required this.savePending,
    required this.onCanonical,
    required this.manualChildren,
    required this.contentControllers,
    required this.contentVersion,
    this.manualPublicLabel,
    this.handle,
    this.enabled = true,
    this.exactIsPublic = false,
  });
  final String actorId, itemKind;
  final String Function()? manualPublicLabel;
  final LocationEditorHandle? handle;
  final String? Function() itemId;
  final Future<String?> Function() savePending;
  final void Function(ItemLocation) onCanonical;
  final List<Widget> manualChildren;
  final List<TextEditingController> contentControllers;
  final Object contentVersion;
  final bool enabled, exactIsPublic;
  @override
  ConsumerState<LocationEditorSection> createState() =>
      _LocationEditorSectionState();
}

class _LocationEditorSectionState extends ConsumerState<LocationEditorSection>
    with WidgetsBindingObserver {
  late final LocationEditorSession _session;
  late final EditorPlaceGatewayFactory _factory;
  DialogRoute<void>? _route;
  bool _manual = false, _applyingCanonical = false;
  bool _preparing = false, _hasOperation = false;
  bool? _routeCurrent;
  late List<String> _lastText;
  String? _knownId;
  final _returnFocus = FocusNode();
  String? _actor() {
    final auth = ref.read(authSessionProvider);
    return auth.phase == AuthSessionPhase.ready &&
            auth.identity?.id == widget.actorId &&
            widget.enabled
        ? widget.actorId
        : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _factory = ref.read(editorPlaceGatewayFactoryProvider);
    _knownId = widget.itemId();
    _lastText = widget.contentControllers.map((c) => c.text).toList();
    _session = LocationEditorSession(
      actor: _actor,
      kind: widget.itemKind,
      itemId: () => widget.itemId(),
      prepare: () async {
        _preparing = true;
        try {
          final id = await widget.savePending();
          if (id != null) _knownId = id;
          return id;
        } finally {
          _preparing = false;
        }
      },
      gateway: ref.read(itemLocationGatewayProvider),
      factory: _factory,
      onCanonical: (value) {
        _applyingCanonical = true;
        try {
          widget.onCanonical(value);
        } finally {
          _applyingCanonical = false;
        }
      },
    );
    widget.handle?._beforeSave = () {
      if (!_preparing) {
        _session.invalidateContent();
        _dismiss();
      }
    };
    _session.addListener(() {
      if (_session.problem == PlaceSearchProblem.unauthorized ||
          _session.problem == PlaceSearchProblem.stale ||
          _session.problem == PlaceSearchProblem.expired) {
        _dismiss();
      }
    });
    for (final controller in widget.contentControllers) {
      controller.addListener(_contentChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_session.reload());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (_routeCurrent != null && _routeCurrent != current && _route == null) {
      _session.invalidateContent();
      if (current) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _route == null) unawaited(_session.reload());
        });
      }
    }
    _routeCurrent = current;
  }

  void _dismiss() {
    final route = _route;
    _route = null;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
  }

  void _contentChanged({bool nonText = false}) {
    final text = widget.contentControllers.map((c) => c.text).toList();
    final changed = nonText || !listEquals(_lastText, text);
    _lastText = text;
    if (!changed) return;
    if (_applyingCanonical) return;
    // Saves/edits cannot retain a receipt issued for preceding content.
    if (_session.scope != null) {
      _session.invalidateContent();
      _dismiss();
    } else if (!_session.busy && _session.canonical != null) {
      _session.invalidateContent();
    }
  }

  @override
  void didUpdateWidget(LocationEditorSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actorId != widget.actorId ||
        oldWidget.itemKind != widget.itemKind ||
        (!widget.enabled && oldWidget.enabled)) {
      _session.invalidateContent();
      _dismiss();
    } else if (oldWidget.contentVersion != widget.contentVersion) {
      _contentChanged(nonText: true);
    }
    final id = widget.itemId();
    if (_knownId != id) {
      _knownId = id;
      // Bootstrap itself binds the new ID after saving; don't interrupt it.
      if (!_session.busy) {
        _session.invalidateContent();
        _dismiss();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_session.reload());
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_session.reload());
    } else {
      _session.cancel(eraseCanonical: true);
      _dismiss();
    }
  }

  Future<void> _choose(String slot) async {
    _hasOperation = true;
    FocusManager.instance.primaryFocus?.unfocus();
    final before = widget.contentControllers.map((c) => c.text).toList();
    final version = widget.contentVersion;
    if (!await _session.begin(slot) || !mounted) return;
    if (version != widget.contentVersion ||
        !listEquals(
          before,
          widget.contentControllers.map((c) => c.text).toList(),
        )) {
      _session.cancel(eraseCanonical: true);
      return;
    }
    _manual = false;
    final route = DialogRoute<void>(
      context: context,
      builder: (_) => _PlaceSearchDialog(session: _session),
    );
    _route = route;
    await Navigator.of(context).push(route);
    if (!mounted) return;
    _route = null;
    _session.cancel();
    _returnFocus.requestFocus();
  }

  Future<void> _clear(String slot) async {
    _hasOperation = true;
    FocusManager.instance.primaryFocus?.unfocus();
    await _session.clear(slot);
  }

  Future<void> _useManual() async {
    final slot = widget.itemKind == 'resource' ? 'public' : 'area';
    if (_session.canonical?.publicPlace != null &&
        !await _session.clear(slot)) {
      return;
    }
    if (mounted) setState(() => _manual = true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      _,
      next,
    ) {
      _session.cancel(eraseCanonical: true);
      _dismiss();
      if (next.$1 == AuthSessionPhase.ready && next.$2 == widget.actorId) {
        unawaited(_session.reload());
      }
    });
    final l10n = AppLocalizations.of(context);
    final resource = widget.itemKind == 'resource';
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) => Column(
        key: Key('location-section-${widget.itemKind}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resource ? l10n.locationWhereResource : l10n.locationWhereProject,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.small),
          if (resource) Text(l10n.locationResourcePublic),
          if (!_factory.available) const ManualLocationNotice(),
          if (_factory.available) ...[
            Text(l10n.locationDraftCue),
            _slot(
              resource ? 'public' : 'area',
              l10n.locationChooseArea,
              _session.canonical?.publicPlace,
            ),
            if (!resource) ...[
              const SizedBox(height: AppSpacing.medium),
              Text(
                l10n.locationExactTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                widget.exactIsPublic
                    ? l10n.locationExactPublic
                    : l10n.locationExactPrivate,
              ),
              _slot(
                'exact',
                l10n.locationChooseExact,
                _session.canonical?.exactPlace,
              ),
            ],
            TextButton(
              key: const Key('location-use-manual'),
              onPressed: _session.busy || !widget.enabled ? null : _useManual,
              child: Text(l10n.locationUseManual),
            ),
          ] else ...[
            if (_session.canonical?.publicPlace case final place?)
              _slot(resource ? 'public' : 'area', '', place),
            if (!resource && _session.canonical?.exactPlace != null) ...[
              Text(l10n.locationExactTitle),
              Text(
                widget.exactIsPublic
                    ? l10n.locationExactPublic
                    : l10n.locationExactPrivate,
              ),
              _slot('exact', '', _session.canonical!.exactPlace),
            ],
          ],
          if (!_factory.available || _manual) ...widget.manualChildren,
          if (_session.busy) const LinearProgressIndicator(),
          if (_factory.available || _hasOperation)
            if (_session.problem case final problem?)
              Semantics(
                liveRegion: true,
                child: Text(
                  locationProblemLabel(l10n, problem),
                  key: const Key('location-operation-error'),
                ),
              ),
          if (_session.canRetry)
            TextButton(
              key: const Key('location-retry'),
              onPressed: _session.retry,
              child: Text(l10n.locationRetry),
            ),
          // Credits also cover provider-derived manual text retained after clear.
          const LocationAttribution(),
        ],
      ),
    );
  }

  Widget _slot(String slot, String label, StoredPlace? place) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          place == null
              ? '${slot == 'exact' ? '' : widget.manualPublicLabel?.call() ?? ''}\n${l10n.locationNoVerifiedPlace}'
              : '${place.label} · ${placeKindLabel(l10n, place.kind)}',
          key: Key('location-stored-$slot'),
        ),
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          children: [
            if (_factory.available)
              OutlinedButton(
                key: Key('location-choose-$slot'),
                focusNode: slot == 'exact' ? null : _returnFocus,
                onPressed: _session.busy || !widget.enabled
                    ? null
                    : () => _choose(slot),
                child: Text(place == null ? label : l10n.locationChange),
              ),
            if (place != null)
              TextButton(
                key: Key('location-clear-$slot'),
                onPressed: _session.busy || !widget.enabled
                    ? null
                    : () => _clear(slot),
                child: Text(l10n.locationClear),
              ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in widget.contentControllers) {
      controller.removeListener(_contentChanged);
    }
    _dismiss();
    widget.handle?._beforeSave = null;
    _session.dispose();
    _returnFocus.dispose();
    super.dispose();
  }
}

class _PlaceSearchDialog extends StatefulWidget {
  const _PlaceSearchDialog({required this.session});
  final LocationEditorSession session;
  @override
  State<_PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends State<_PlaceSearchDialog> {
  final _query = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final session = widget.session, l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        session,
        if (session.search != null) session.search!,
      ]),
      builder: (context, _) {
        final search = session.search;
        final eligible =
            search?.suggestions
                .where(
                  (p) => session.scope?.slot == 'area'
                      ? p.kind == PlaceKind.locality
                      : session.scope?.slot == 'exact'
                      ? p.kind != PlaceKind.locality
                      : true,
                )
                .toList() ??
            [];
        return AlertDialog(
          scrollable: true,
          title: Text(
            session.scope?.slot == 'exact'
                ? l10n.locationExactTitle
                : l10n.locationSearchTitle,
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('location-query'),
                  controller: _query,
                  autofocus: true,
                  maxLength: 160,
                  enabled: !session.busy && !session.canRetry,
                  decoration: InputDecoration(
                    labelText: l10n.locationQueryLabel,
                  ),
                  onChanged: (value) =>
                      search?.edit(value, language: l10n.localeName),
                ),
                if (search?.phase == PlaceSearchPhase.waiting ||
                    search?.phase == PlaceSearchPhase.searching ||
                    search?.phase == PlaceSearchPhase.resolving ||
                    session.busy)
                  Semantics(
                    label: l10n.locationLoading,
                    child: const LinearProgressIndicator(),
                  ),
                if (search?.phase == PlaceSearchPhase.results &&
                    eligible.isEmpty)
                  Text(
                    l10n.locationNoMatches,
                    key: const Key('location-no-matches'),
                  ),
                for (final suggestion in eligible)
                  TextButton(
                    key: Key('location-result-${suggestion.id}'),
                    onPressed: session.busy || session.canRetry
                        ? null
                        : () => search?.select(suggestion),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${suggestion.label}\n${placeKindLabel(l10n, suggestion.kind)}',
                      ),
                    ),
                  ),
                if (search?.selection case final selected?) ...[
                  Text(
                    '${selected.suggestion.label} · ${placeKindLabel(l10n, selected.suggestion.kind)}',
                    key: const Key('location-selected-receipt'),
                  ),
                  Text(l10n.locationSelectionPending),
                ],
                if (session.problem ?? search?.problem case final problem?)
                  Semantics(
                    liveRegion: true,
                    child: Text(locationProblemLabel(l10n, problem)),
                  ),
                const LocationAttribution(),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('location-cancel'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.locationCancel),
            ),
            if (session.canRetry)
              TextButton(
                key: const Key('location-retry-confirm'),
                onPressed: () async {
                  if (await session.retry() && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(l10n.locationRetry),
              ),
            FilledButton(
              key: const Key('location-confirm'),
              onPressed:
                  search?.selection == null || session.busy || session.canRetry
                  ? null
                  : () async {
                      FocusManager.instance.primaryFocus?.unfocus();
                      if (await session.confirm() && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              child: Text(l10n.locationSavePlace),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _query.clear();
    _query.dispose();
    super.dispose();
  }
}

String placeKindLabel(AppLocalizations l10n, PlaceKind kind) => switch (kind) {
  PlaceKind.locality => l10n.locationKindLocality,
  PlaceKind.address => l10n.locationKindAddress,
  PlaceKind.amenity => l10n.locationKindAmenity,
};
String locationProblemLabel(
  AppLocalizations l10n,
  PlaceSearchProblem problem,
) => switch (problem) {
  PlaceSearchProblem.disabled ||
  PlaceSearchProblem.unconfigured => l10n.locationManualEntryNotice,
  PlaceSearchProblem.offline => l10n.locationErrorOffline,
  PlaceSearchProblem.timeout => l10n.locationErrorTimeout,
  PlaceSearchProblem.quota => l10n.locationErrorQuota,
  PlaceSearchProblem.expired => l10n.locationErrorExpired,
  PlaceSearchProblem.stale => l10n.locationErrorStale,
  PlaceSearchProblem.unauthorized => l10n.locationErrorUnauthorized,
  PlaceSearchProblem.unsupported => l10n.locationErrorUnsupported,
  _ => l10n.locationErrorProvider,
};
