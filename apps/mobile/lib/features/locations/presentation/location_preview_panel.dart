import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../geographic_discovery/application/shared_basemap_tiles.dart';
import '../../geographic_discovery/presentation/read_only_basemap.dart';
import '../../participation/application/participation_controllers.dart';
import '../../project_delegates/application/project_delegate_controllers.dart';
import '../application/public_preview_batch.dart';
import '../data/location_preview_gateway.dart';
import '../domain/location_preview.dart';
import 'location_attribution.dart';

/// A location panel with validated tiles or explicitly selected static imagery.
/// All outbound Maps actions perform a fresh canonical read.
class LocationPreviewPanel extends ConsumerStatefulWidget {
  const LocationPreviewPanel({
    required this.item,
    required this.legacy,
    required this.publicLabel,
    this.detail = false,
    this.allowLegacyAreaSearch = true,
    this.contentVersion,
    this.labelKey,
    super.key,
  });
  final PreviewItem item;
  final LegacyPreviewArea legacy;
  final String publicLabel;
  final bool detail;

  /// City-only Projects opt out; existing manual precise records and other
  /// kinds keep canonical broad-area search without inventing coordinates.
  final bool allowLegacyAreaSearch;
  final Key? labelKey;
  final Object? contentVersion;
  @override
  ConsumerState<LocationPreviewPanel> createState() =>
      _LocationPreviewPanelState();
}

class _LocationPreviewPanelState extends ConsumerState<LocationPreviewPanel>
    with WidgetsBindingObserver {
  final _box = GlobalKey();
  var _bitmap = GlobalKey<_UncachedPreviewImageState>();
  var _tiles = GlobalKey<ReadOnlyBasemapState>();
  ScrollPosition? _scroll;
  Timer? _lease;
  Completer<void>? _abort;
  LocationPreview? _preview;
  Uint8List? _bytes;
  String? _imageKey;
  int? _imageRevision;
  bool _imageProtected = false;
  int _epoch = 0;
  bool _visible = false, _foreground = true, _loading = false, _opening = false;
  bool _failed = false, _frameScheduled = false;
  bool _needsRefresh = true;
  String? get _actor {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lease = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_visible && _foreground) {
        if (!widget.detail) {
          ref.read(publicPreviewBatchProvider).expire(widget.item);
        }
        if (_preview?.isProtected != false) {
          // Private pixels/buffers cannot outlive their authorization lease.
          _revoke();
          _scheduleVisibility();
        } else if (!_opening) {
          // Renew canonical public status without destroying unchanged pixels.
          unawaited(_load());
        }
      }
    });
  }

  void _eraseImage() {
    _revokeBitmap();
    if (_imageProtected) {
      _bytes?.fillRange(0, _bytes!.length, 0);
    }
    _bytes = null;
    _imageKey = null;
    _imageRevision = null;
    _imageProtected = false;
  }

  void _revokeBitmap() {
    _bitmap.currentState?.revoke();
    _bitmap = GlobalKey<_UncachedPreviewImageState>();
  }

  void _interruptRead() {
    ++_epoch;
    if (_abort?.isCompleted == false) _abort!.complete();
    _abort = null;
    _loading = false;
    _opening = false;
    _needsRefresh = true;
  }

  void _revoke() {
    _interruptRead();
    _tiles.currentState?.revoke();
    _tiles = GlobalKey<ReadOnlyBasemapState>();
    _eraseImage();
    _preview = null;
    _failed = false;
    if (mounted) setState(() {});
  }

  void _suspend() {
    if (_preview?.isProtected != false) {
      _revoke();
    } else {
      // A retained public view is bounded by this widget, not a new cache/TTL.
      // Cancel canonical/launch work; revalidate when it becomes visible again.
      _interruptRead();
      _failed = false;
      if (mounted) setState(() {});
    }
  }

  void _invalidate() {
    _revoke();
    ref.read(publicPreviewBatchProvider).clear();
    _scheduleVisibility();
  }

  void _entitlementChanged() {
    if (_preview?.isProtected != false) {
      _invalidate();
    } else {
      _interruptRead();
      _failed = false;
      _scheduleVisibility();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (_scroll != position) {
      _scroll?.removeListener(_scheduleVisibility);
      _scroll = position;
      _scroll?.addListener(_scheduleVisibility);
    }
    if ((ModalRoute.isCurrentOf(context) ?? true) == false ||
        !TickerMode.valuesOf(context).enabled) {
      if (_visible) _suspend();
      _visible = false;
    }
    _scheduleVisibility();
  }

  @override
  void didUpdateWidget(LocationPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.key != widget.item.key ||
        oldWidget.detail != widget.detail ||
        oldWidget.allowLegacyAreaSearch != widget.allowLegacyAreaSearch ||
        oldWidget.publicLabel != widget.publicLabel ||
        oldWidget.contentVersion != widget.contentVersion) {
      _invalidate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.inactive) {
      _suspend();
    } else if (!_foreground) {
      _revoke();
      ref.read(publicPreviewBatchProvider).clear();
    } else {
      _needsRefresh = true;
      _scheduleVisibility();
    }
  }

  void _scheduleVisibility() {
    if (_frameScheduled || !mounted) return;
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted) return;
      final render = _box.currentContext?.findRenderObject();
      var visible = false;
      if (_foreground &&
          TickerMode.valuesOf(context).enabled &&
          (ModalRoute.isCurrentOf(context) ?? true) &&
          render is RenderBox &&
          render.hasSize &&
          render.attached) {
        final rect = render.localToGlobal(Offset.zero) & render.size;
        var viewport = Offset.zero & MediaQuery.sizeOf(context);
        final scrollRender = _scroll?.context.notificationContext
            ?.findRenderObject();
        if (scrollRender is RenderBox && scrollRender.hasSize) {
          viewport = viewport.intersect(
            scrollRender.localToGlobal(Offset.zero) & scrollRender.size,
          );
        }
        visible = rect.overlaps(viewport);
      }
      if (!visible && _visible) _suspend();
      _visible = visible;
      if (visible &&
          (_needsRefresh || _preview == null) &&
          !_loading &&
          !_failed) {
        unawaited(_load());
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _current(int epoch, String? actor) =>
      mounted && epoch == _epoch && _foreground && _visible && _actor == actor;
  bool _safe(LocationPreview value) =>
      value.item.key == widget.item.key &&
      (!value.isProtected ||
          (_actor != null &&
              widget.detail &&
              widget.item.kind != 'resource')) &&
      (widget.detail ||
          (!value.isProtected &&
              (widget.item.kind == 'resource' ||
                  value.place?.isArea != false)));
  Future<void> _load() async {
    if (_loading) return;
    var epoch = _epoch;
    final actor = _actor;
    _loading = true;
    _needsRefresh = false;
    try {
      final value = widget.detail
          ? await ref
                .read(locationPreviewGatewayProvider)
                .read(widget.item, actor: actor)
          : await ref.read(publicPreviewBatchProvider).read(widget.item);
      if (!_current(epoch, actor)) return;
      if (value != null && !_safe(value)) throw const PreviewUnavailable(true);
      if (value == null) {
        _revoke();
        _failed = true;
        return;
      }
      if (_preview != null &&
          (!_preview!.sameLocationAs(value) ||
              _preview!.isProtected != value.isProtected)) {
        _revoke();
        epoch = _epoch;
        _loading = true;
        _needsRefresh = false;
      }
      // Authorized text/action need not wait for optional image rendering.
      setState(() {
        _preview = value;
        _failed = false;
      });
      if (_imageKey != value.imageKey ||
          _imageRevision != value.revision ||
          _imageProtected != value.isProtected) {
        _eraseImage();
      }
      final renderer = ref.read(staticPreviewGatewayProvider);
      if (!(widget.detail && ref.read(detailBasemapEnabledProvider)) &&
          renderer.enabled &&
          value.place != null &&
          _bytes == null) {
        final abort = Completer<void>();
        _abort = abort;
        try {
          final batch = ref.read(publicPreviewBatchProvider);
          final bytes = await batch.loadImage(
            value,
            () => renderer.image(
              value,
              view: widget.detail
                  ? value.isProtected
                        ? 'protected_detail'
                        : 'public_detail'
                  : 'card',
              actor: actor,
              cancellation: abort.future,
            ),
          );
          if (!_current(epoch, actor)) {
            if (value.isProtected) bytes.fillRange(0, bytes.length, 0);
            return;
          }
          if (!validPreviewPng(bytes)) throw const PreviewUnavailable();
          _bytes = bytes;
          _imageKey = value.imageKey;
          _imageRevision = value.revision;
          _imageProtected = value.isProtected;
        } on PreviewUnavailable catch (error) {
          // Optional imagery failure preserves the authorized place. A known
          // denial/stale authorization must instead erase the whole projection.
          if (error.denied) {
            rethrow;
          }
          if (!_current(epoch, actor)) return;
          _eraseImage();
          _failed = true;
        }
      }
    } catch (_) {
      if (!_current(epoch, actor)) return;
      _revoke();
      _failed = true;
    } finally {
      if (_current(epoch, actor)) setState(() => _loading = false);
    }
  }

  Uri? _mapsDestination(LocationPreview value) {
    // A typed city is discovery text, not a chosen meeting destination. Other
    // item kinds keep their existing canonical-locality search behavior.
    if (!widget.allowLegacyAreaSearch && value.place == null) return null;
    return googleMapsPreviewUrl(value, value.legacy);
  }

  Future<void> _open() async {
    if (_opening || !_foreground || !_visible) return;
    var epoch = _epoch;
    final actor = _actor;
    setState(() => _opening = true);
    try {
      final current = await ref
          .read(locationPreviewGatewayProvider)
          .read(
            widget.item,
            card: !widget.detail,
            actor: widget.detail ? actor : null,
          );
      if (!_current(epoch, actor)) return;
      if (current == null || !_safe(current)) {
        throw const PreviewUnavailable(true);
      }
      // A fresh tap can observe departure/visibility changes before the lease.
      // Cancel older reads/renders so they cannot restore the prior projection.
      if (_preview?.sameLocationAs(current) != true ||
          _preview?.isProtected != current.isProtected) {
        _revoke();
        epoch = _epoch;
      }
      setState(() {
        _preview = current;
        _opening = true;
      });
      final url = _mapsDestination(current);
      if (url == null ||
          !await ref.read(previewMapsLauncherProvider).open(url)) {
        throw const PreviewUnavailable();
      }
    } catch (_) {
      if (mounted && _current(epoch, actor)) {
        _revoke();
        epoch = _epoch;
        _failed = true;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).locationMapsLaunchFailed,
            ),
          ),
        );
      }
    } finally {
      if (_current(epoch, actor)) setState(() => _opening = false);
    }
  }

  Widget _mapAction(Widget canvas, LocationPreview value) {
    final l10n = AppLocalizations.of(context);
    final place = value.place!;
    final enabled = !_opening && _foreground && _visible;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.small),
      child: Semantics(
        key: Key('location-map-action-${widget.item.id}'),
        link: true,
        button: true,
        enabled: enabled,
        label:
            '${l10n.locationOpenGoogleMaps}: ${place.label}'
            '${place.isArea ? '. ${l10n.locationPreviewApproximate}' : ''}',
        onTap: enabled ? _open : null,
        excludeSemantics: true,
        child: ClipRRect(
          borderRadius: AppRadii.medium,
          child: Stack(
            children: [
              canvas,
              Positioned.fill(
                // Paint focus/press ink ABOVE the opaque tile/image pixels.
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: enabled ? _open : null,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.open_in_new, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackAction() => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      key: Key('location-open-maps-${widget.item.id}'),
      onPressed: _opening ? null : _open,
      style: widget.detail
          ? TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      icon: const Icon(Icons.open_in_new, size: 20),
      label: Text(
        _opening
            ? AppLocalizations.of(context).locationLoading
            : AppLocalizations.of(context).locationOpenGoogleMaps,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authSessionProvider.select((s) => (s.phase, s.identity?.id)),
      (_, _) => _invalidate(),
    );
    if (widget.detail && widget.item.kind != 'resource') {
      ref.listen(ownParticipationProvider, (_, _) => _entitlementChanged());
      ref.listen(
        projectManagementRoleProvider,
        (_, _) => _entitlementChanged(),
      );
      ref.listen(
        participantMeetingDetailsProvider,
        (_, _) => _entitlementChanged(),
      );
    }
    final l10n = AppLocalizations.of(context);
    final value = _preview, place = value?.place;
    final tiled = widget.detail && ref.watch(detailBasemapEnabledProvider);
    final tileStore = tiled ? ref.watch(sharedBasemapTilesProvider) : null;
    final label = place?.label ?? widget.publicLabel;
    // Only a current canonical projection can offer an outbound destination.
    // Revocation removes the action together with protected labels and pixels.
    final hasDestination = value != null && _mapsDestination(value) != null;
    final fallback = hasDestination ? _fallbackAction() : null;
    final showTiles =
        tiled && tileStore!.enabled && value != null && place != null;
    final showStatic = !tiled && value != null && _bytes != null;
    return Padding(
      key: _box,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            key: Key('location-preview-${widget.item.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(child: Icon(Icons.location_on_outlined)),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Text(
                  label.isEmpty ? l10n.locationPreviewUnavailable : label,
                  key: widget.labelKey,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          if (place?.isArea == true)
            Text(
              l10n.locationPreviewApproximate,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (showTiles)
            ReadOnlyBasemap(
              key: _tiles,
              store: tileStore,
              latitude: place.latitude,
              longitude: place.longitude,
              protected: value.isProtected,
              approximate: place.isArea,
              semanticLabel: place.isArea
                  ? '${place.label}. ${l10n.locationPreviewApproximate}'
                  : place.label,
              failureLabel: l10n.locationPreviewImageFailed,
              imageBuilder: (canvas) => _mapAction(canvas, value),
              fallback: fallback,
            ),
          // Disabled imagery has no reserved space or availability boilerplate.
          if (showStatic)
            _UncachedPreviewImage(
              key: _bitmap,
              bytes: _bytes!,
              failureLabel: l10n.locationPreviewImageFailed,
              fallback: fallback,
              imageBuilder: (image) => _mapAction(
                SizedBox(
                  height: widget.detail ? 144 : 80,
                  width: double.infinity,
                  child: image,
                ),
                value,
              ),
            ),
          if (_failed) Text(l10n.locationPreviewImageFailed),
          if (!showTiles && !showStatic) ?fallback,
          // Text may remain provider-derived after clear or template reuse.
          LocationAttribution(centered: widget.detail),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lease?.cancel();
    _scroll?.removeListener(_scheduleVisibility);
    ++_epoch;
    if (_abort?.isCompleted == false) _abort!.complete();
    _tiles.currentState?.revoke();
    _eraseImage();
    super.dispose();
  }
}

/// Avoid Flutter's GLOBAL ImageCache for protected bytes. Own/dispose the decoded
/// bitmap and discard any decode completing after replacement/disposal.
class _UncachedPreviewImage extends StatefulWidget {
  const _UncachedPreviewImage({
    required this.bytes,
    required this.failureLabel,
    required this.imageBuilder,
    this.fallback,
    super.key,
  });
  final Uint8List bytes;
  final String failureLabel;
  final Widget Function(Widget image) imageBuilder;
  final Widget? fallback;
  @override
  State<_UncachedPreviewImage> createState() => _UncachedPreviewImageState();
}

class _UncachedPreviewImageState extends State<_UncachedPreviewImage> {
  ui.Image? _image;
  int _epoch = 0;
  bool _failed = false;

  // Revoke synchronously even when backgrounding prevents another UI frame.
  void revoke() {
    ++_epoch;
    _image?.dispose();
    _image = null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_decode());
  }

  @override
  void didUpdateWidget(_UncachedPreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      ++_epoch;
      _image?.dispose();
      _image = null;
      unawaited(_decode());
    }
  }

  Future<void> _decode() async {
    final epoch = _epoch;
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted || epoch != _epoch) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _image = frame.image;
        _failed = false;
      });
    } catch (_) {
      if (mounted && epoch == _epoch) setState(() => _failed = true);
    } finally {
      codec?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(widget.failureLabel), ?widget.fallback],
      );
    }
    if (_image == null) return widget.fallback ?? const SizedBox.shrink();
    return widget.imageBuilder(
      ExcludeSemantics(
        child: RawImage(image: _image, fit: BoxFit.contain),
      ),
    );
  }

  @override
  void dispose() {
    ++_epoch;
    _image?.dispose();
    super.dispose();
  }
}

// Independent opt-in. Fixtures override this provider and the tile gateway;
// enabling tiles never enables static fallback, including guests and failures.
final detailBasemapEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('LOCATION_DETAIL_TILES_ENABLED'),
);
