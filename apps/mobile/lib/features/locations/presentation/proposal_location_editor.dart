import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'location_editor_section.dart';

/// One-time Project editor only. Query text is private transient input until a
/// verified receipt is committed or the author explicitly confirms a broad city.
/// The parent continues to own ordinary content/directions and draft departure.
class ProposalLocationEditor extends ConsumerStatefulWidget {
  const ProposalLocationEditor({
    super.key,
    required this.actorId,
    required this.itemId,
    required this.savePending,
    required this.onCanonical,
    required this.publicLabel,
    required this.onManualCity,
    required this.handle,
    required this.contentControllers,
    required this.contentVersion,
    required this.enabled,
    required this.exactIsPublic,
    required this.directions,
    required this.hasDirections,
    required this.onClearDirections,
  });
  final String actorId;
  final String? Function() itemId;
  final Future<String?> Function() savePending;
  final void Function(ItemLocation) onCanonical;
  final String Function() publicLabel;
  final void Function(String) onManualCity;
  final LocationEditorHandle handle;
  final List<TextEditingController> contentControllers;
  final Object contentVersion;
  final bool enabled, exactIsPublic, hasDirections;
  final Widget directions;
  final VoidCallback onClearDirections;

  @override
  ConsumerState<ProposalLocationEditor> createState() =>
      _ProposalLocationEditorState();
}

class _ProposalLocationEditorState extends ConsumerState<ProposalLocationEditor>
    with WidgetsBindingObserver {
  late final LocationEditorSession _session;
  late final EditorPlaceGatewayFactory _factory;
  late final TextEditingController _query;
  late List<String> _lastText;
  ItemLocation? _location;
  bool _dirty = false, _preparing = false, _applying = false;
  bool _manualPendingSave = false, _settingQuery = false;
  bool _denied = false;
  late String _lastQueryText;
  bool? _directionsExpanded;
  Timer? _debounce;
  Future<bool>? _starting;
  int _generation = 0;
  String? _knownId;
  bool? _routeCurrent;

  String? _actor() {
    final auth = ref.read(authSessionProvider);
    return widget.enabled &&
            auth.phase == AuthSessionPhase.ready &&
            auth.identity?.id == widget.actorId
        ? widget.actorId
        : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _factory = ref.read(editorPlaceGatewayFactoryProvider);
    _query = TextEditingController(text: widget.publicLabel());
    _directionsExpanded = widget.hasDirections;
    _lastQueryText = _query.text;
    _query.addListener(_queryChanged);
    _lastText = widget.contentControllers.map((c) => c.text).toList();
    _knownId = widget.itemId();
    _session = LocationEditorSession(
      actor: _actor,
      kind: 'one_time',
      itemId: widget.itemId,
      gateway: ref.read(itemLocationGatewayProvider),
      factory: _factory,
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
      onCanonical: (value) {
        _applying = true;
        try {
          _location = value;
          _dirty = false;
          _manualPendingSave = false;
          _setQuery(
            value.exactPlace?.label ??
                value.publicLabel ??
                value.publicPlace?.label ??
                widget.publicLabel(),
          );
          widget.onCanonical(value);
        } finally {
          _applying = false;
        }
      },
    );
    _session.addListener(_changed);
    widget.handle.bind(() {
      if (!_preparing) _cancel();
    });
    widget.handle.pendingQuery = () => _dirty && !_preparing ? _query.text : '';
    widget.handle.contentSaved = () => _manualPendingSave = false;
    widget.handle.restoreQuery = () {
      _cancel();
      _dirty = false;
      _setQuery(_location?.exactPlace?.label ?? widget.publicLabel());
      setState(() {});
    };
    for (final c in widget.contentControllers) {
      c.addListener(_contentChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_session.reload());
    });
  }

  void _changed() {
    if (!mounted) return;
    final canonical = _session.canonical;
    if (canonical != null && !_dirty && !_preparing && !_manualPendingSave) {
      _denied = false;
      _location = canonical;
      _setQuery(
        canonical.exactPlace?.label ??
            canonical.publicLabel ??
            canonical.publicPlace?.label ??
            widget.publicLabel(),
      );
    }
    if (_session.problem == PlaceSearchProblem.unauthorized) {
      _denied = true;
      _location = null;
      _setQuery(widget.publicLabel());
      _dirty = false;
    }
    setState(() {});
  }

  void _cancel() {
    ++_generation;
    _debounce?.cancel();
    _session.invalidateContent();
  }

  void _contentChanged() {
    final next = widget.contentControllers.map((c) => c.text).toList();
    final different = !listEquals(_lastText, next);
    _lastText = next;
    if (different && !_applying && !_preparing) _cancel();
  }

  @override
  void didUpdateWidget(ProposalLocationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentVersion != widget.contentVersion &&
        !_applying &&
        !_preparing) {
      _cancel();
    }
    if (oldWidget.enabled && !widget.enabled) _revoke();
    final id = widget.itemId();
    if (_knownId != id) {
      _knownId = id;
      if (!_session.busy) {
        _cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_session.reload());
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (_routeCurrent == true && !current) _cancel();
    if (_routeCurrent == false && current) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_session.reload());
      });
    }
    _routeCurrent = current;
  }

  void _revoke() {
    _cancel();
    _denied = true;
    _location = null;
    _setQuery(widget.publicLabel());
    _dirty = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_session.reload());
    } else {
      _revoke();
    }
  }

  void _setQuery(String value) {
    _settingQuery = true;
    try {
      _query.text = value;
      _lastQueryText = value;
    } finally {
      _settingQuery = false;
    }
  }

  void _queryChanged() {
    if (_settingQuery || _lastQueryText == _query.text) return;
    _lastQueryText = _query.text;
    _edit(_query.text);
  }

  void _edit(String value) {
    _dirty = true;
    if (value.trim().isEmpty && _location?.exactPlace == null) {
      _applying = true;
      try {
        widget.onManualCity('');
      } finally {
        _applying = false;
      }
      _location = null;
      _dirty = false;
      _manualPendingSave = true;
    }
    final generation = ++_generation;
    _debounce?.cancel();
    // Any earlier resolve/retry is revoked as soon as the text changes.
    _session.cancel();
    setState(() {});
    if (!_factory.available ||
        value.trim().length < 2 ||
        value.trim().length > 160) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final earlier = _starting;
      if (earlier != null) await earlier;
      if (!mounted || generation != _generation) return;
      final start = _session.begin('place');
      _starting = start;
      try {
        if (!await start || !mounted || generation != _generation) return;
        _session.search!.edit(
          _query.text,
          language: AppLocalizations.of(context).localeName,
        );
      } finally {
        if (identical(_starting, start)) _starting = null;
      }
    });
  }

  Future<void> _select(PlaceSuggestion value) async {
    final generation = _generation;
    await _session.search?.select(value);
    if (!mounted || generation != _generation) return;
    if (_session.search?.selection != null) await _session.confirm();
  }

  Future<void> _manualCity() async {
    final value = _query.text.trim();
    // Public city confirmation is deliberate, and obvious precise text stays
    // private even offline. This is a guard, not a geocoding claim.
    if (!manualCityTextIsBroad(value)) return;
    _debounce?.cancel();
    final generation = ++_generation;
    final selected =
        _location?.exactPlace != null || _location?.publicPlace != null;
    if (widget.itemId() != null && selected && !await _session.clear('place')) {
      return;
    }
    if (!mounted || generation != _generation) return;
    _applying = true;
    try {
      widget.onManualCity(value);
      _location = null;
      _dirty = false;
      _manualPendingSave = true;
      _setQuery(value);
    } finally {
      _applying = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      _,
      next,
    ) {
      _revoke();
      if (next.$1 == AuthSessionPhase.ready && next.$2 == widget.actorId) {
        unawaited(_session.reload());
      }
    });
    final l10n = AppLocalizations.of(context);
    final search = _session.search;
    final exact = !_dirty ? _location?.exactPlace : null;
    final expanded = _directionsExpanded ?? widget.hasDirections;
    return ListenableBuilder(
      listenable: search ?? _session,
      builder: (context, _) => Column(
        key: const Key('location-section-one_time'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            key: const Key('proposal-public-location'),
            controller: _query,
            enabled: widget.enabled && !_session.canRetry,
            maxLength: 180,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.proposalPlaceLabel,
              helperText: l10n.proposalPlaceHint,
              helperMaxLines: 12,
              counterText: '',
            ),
            validator: (_) => _query.text.trim().length > 180
                ? l10n.proposalMaximumLength(180)
                : _dirty && !_preparing
                ? l10n.proposalPlaceConfirm
                : null,
          ),
          if (_session.busy ||
              search?.phase == PlaceSearchPhase.waiting ||
              search?.phase == PlaceSearchPhase.searching ||
              search?.phase == PlaceSearchPhase.resolving)
            Semantics(
              label: l10n.locationLoading,
              child: const LinearProgressIndicator(),
            ),
          if (search?.phase == PlaceSearchPhase.results &&
              search!.suggestions.isEmpty)
            Text(l10n.locationNoMatches),
          for (final suggestion in search?.suggestions ?? <PlaceSuggestion>[])
            TextButton(
              key: Key('location-result-${suggestion.id}'),
              onPressed: _session.busy || _session.canRetry
                  ? null
                  : () => _select(suggestion),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${suggestion.label}\n${placeKindLabel(l10n, suggestion.kind)}',
                ),
              ),
            ),
          if (_dirty) ...[
            Text(
              l10n.proposalManualCityOnly,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            OutlinedButton(
              key: const Key('proposal-confirm-manual-city'),
              onPressed:
                  widget.enabled &&
                      !_session.busy &&
                      manualCityTextIsBroad(_query.text.trim())
                  ? _manualCity
                  : null,
              child: Text(l10n.proposalUsePublicCity),
            ),
            TextButton(
              key: const Key('proposal-cancel-place-edit'),
              onPressed: widget.handle.restoreQuery,
              child: Text(l10n.locationCancel),
            ),
          ] else if (exact != null) ...[
            Text(
              placeKindLabel(l10n, exact.kind),
              key: const Key('proposal-place-precision'),
            ),
            SwitchListTile(
              key: const Key('proposal-exact-visibility'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.proposalShowExactPublic),
              value: _location?.exactIsPublic ?? widget.exactIsPublic,
              onChanged: widget.enabled && !_session.busy
                  ? (value) => _session.setProposalVisibility(value)
                  : null,
            ),
            Text(
              widget.publicLabel(),
              key: const Key('proposal-public-city-preview'),
            ),
            TextButton.icon(
              key: const Key('proposal-remove-exact'),
              onPressed: widget.enabled && !_session.busy
                  ? () => _session.clear('exact')
                  : null,
              icon: const Icon(Icons.clear),
              label: Text(l10n.proposalRemovePlace),
            ),
          ],
          if (_session.problem ?? search?.problem case final problem?)
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
          Semantics(
            expanded: expanded,
            child: ListTile(
              key: const Key('proposal-optional-exact'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.proposalArrivalDirections),
              trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => _directionsExpanded = !expanded),
            ),
          ),
          if (expanded && !_denied) ...[
            Text(
              l10n.proposalDirectionsPrivate,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            widget.directions,
            if (widget.hasDirections)
              TextButton.icon(
                key: const Key('proposal-clear-directions'),
                onPressed: widget.enabled ? widget.onClearDirections : null,
                icon: const Icon(Icons.clear),
                label: Text(l10n.proposalClearDirections),
              ),
          ],
          const SizedBox(height: AppSpacing.small),
          const LocationAttribution(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    for (final c in widget.contentControllers) {
      c.removeListener(_contentChanged);
    }
    widget.handle.unbind();
    _session.dispose();
    _query.dispose();
    super.dispose();
  }
}

/// Manual fallback creates no geometry. Precise-looking text must use verified
/// search or stay in protected arrival instructions, never the public city label.
bool manualCityTextIsBroad(String text) =>
    text.trim().isNotEmpty &&
    text.trim().length <= 120 &&
    !RegExp(r'[0-9\n\r<>]').hasMatch(text) &&
    !RegExp(
      r'\b(via|viale|vicolo|piazza|corso|strada|street|road|avenue|lane|address|indirizzo)\b',
      caseSensitive: false,
    ).hasMatch(text);
