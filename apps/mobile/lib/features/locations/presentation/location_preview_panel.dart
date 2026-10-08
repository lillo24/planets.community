import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../participation/application/participation_controllers.dart';
import '../../project_delegates/application/project_delegate_controllers.dart';
import '../application/public_preview_batch.dart';
import '../data/location_preview_gateway.dart';
import '../domain/location_preview.dart';
import 'location_attribution.dart';

/// A location panel, not an illustrated/fabricated map. Only a validated bitmap
/// becomes a map. All outbound Maps actions perform a fresh canonical read.
class LocationPreviewPanel extends ConsumerStatefulWidget {
  const LocationPreviewPanel({
    required this.item,
    required this.legacy,
    required this.publicLabel,
    this.detail = false,
    this.contentVersion,
    this.labelKey,
    super.key,
  });
  final PreviewItem item;
  final LegacyPreviewArea legacy;
  final String publicLabel;
  final bool detail;
  final Key? labelKey;
  final Object? contentVersion;
  @override
  ConsumerState<LocationPreviewPanel> createState() =>
      _LocationPreviewPanelState();
}

class _LocationPreviewPanelState extends ConsumerState<LocationPreviewPanel>
    with WidgetsBindingObserver {
  final _box = GlobalKey();
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
        // Hide exact content while reauthorizing. The same widget-owned bitmap
        // can be reused only after the fresh read confirms its key/revision.
        _revoke(keepImage: true);
        _scheduleVisibility();
      }
    });
  }

  void _eraseImage() {
    if (_imageProtected) {
      _bytes?.fillRange(0, _bytes!.length, 0);
    }
    _bytes = null;
    _imageKey = null;
    _imageRevision = null;
    _imageProtected = false;
  }

  void _revoke({bool keepImage = false}) {
    ++_epoch;
    if (_abort?.isCompleted == false) _abort!.complete();
    _abort = null;
    if (!keepImage) _eraseImage();
    _preview = null;
    _loading = false;
    _opening = false;
    _failed = false;
    if (mounted) setState(() {});
  }

  void _invalidate() {
    _revoke();
    ref.read(publicPreviewBatchProvider).clear();
    _scheduleVisibility();
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
      _visible = false;
      _revoke();
    }
    _scheduleVisibility();
  }

  @override
  void didUpdateWidget(LocationPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.key != widget.item.key ||
        oldWidget.detail != widget.detail ||
        oldWidget.publicLabel != widget.publicLabel ||
        oldWidget.contentVersion != widget.contentVersion) {
      _invalidate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _revoke();
    ref.read(publicPreviewBatchProvider).clear();
    if (_foreground) _scheduleVisibility();
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
      if (!visible && _visible) _revoke();
      _visible = visible;
      if (visible && _preview == null && !_loading && !_failed) {
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
    final epoch = _epoch, actor = _actor;
    _loading = true;
    final abort = Completer<void>();
    _abort = abort;
    try {
      final value = widget.detail
          ? await ref
                .read(locationPreviewGatewayProvider)
                .read(widget.item, actor: actor)
          : await ref.read(publicPreviewBatchProvider).read(widget.item);
      if (!_current(epoch, actor)) return;
      if (value != null && !_safe(value)) throw const PreviewUnavailable(true);
      _preview = value;
      if (value == null) {
        _eraseImage();
        _failed = true;
        return;
      }
      if (_imageKey != value.imageKey || _imageRevision != value.revision) {
        _eraseImage();
      }
      final renderer = ref.read(staticPreviewGatewayProvider);
      if (renderer.enabled && value.place != null && _bytes == null) {
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
      _eraseImage();
      _preview = null;
      _failed = true;
    } finally {
      if (_current(epoch, actor)) setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    if (_opening || !_foreground || !_visible) return;
    final epoch = _epoch, actor = _actor;
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
      final url = googleMapsPreviewUrl(current, current.legacy);
      if (url == null ||
          !await ref.read(previewMapsLauncherProvider).open(url)) {
        throw const PreviewUnavailable();
      }
    } catch (_) {
      if (mounted && _current(epoch, actor)) {
        _eraseImage();
        _preview = null;
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

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authSessionProvider.select((s) => (s.phase, s.identity?.id)),
      (_, _) => _invalidate(),
    );
    if (widget.detail && widget.item.kind != 'resource') {
      ref.listen(ownParticipationProvider, (_, _) => _invalidate());
      ref.listen(projectManagementRoleProvider, (_, _) => _invalidate());
      ref.listen(participantMeetingDetailsProvider, (_, _) => _invalidate());
    }
    final l10n = AppLocalizations.of(context),
        scheme = Theme.of(context).colorScheme;
    final value = _preview, place = value?.place;
    final label = place?.label ?? widget.publicLabel;
    final hasDestination = place != null || widget.legacy.query != null;
    return Padding(
      key: _box,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: AppRadii.medium,
            child: Semantics(
              button: true,
              child: InkWell(
                key: Key('location-preview-${widget.item.id}'),
                borderRadius: AppRadii.medium,
                onTap: hasDestination && !_opening ? _open : null,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.small),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const ExcludeSemantics(
                            child: Icon(Icons.location_on_outlined),
                          ),
                          const SizedBox(width: AppSpacing.small),
                          Expanded(
                            child: Text(
                              label.isEmpty
                                  ? l10n.locationPreviewUnavailable
                                  : label,
                              key: widget.labelKey,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          if (hasDestination)
                            const ExcludeSemantics(
                              child: Icon(Icons.open_in_new, size: 20),
                            ),
                        ],
                      ),
                      Text(
                        place == null
                            ? l10n.locationPreviewTextOnly
                            : place.isArea
                            ? l10n.locationPreviewApproximate
                            : l10n.locationPreviewVerified,
                      ),
                      if (value != null && _bytes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.small),
                          child: SizedBox(
                            height: widget.detail ? 160 : 80,
                            child: _UncachedPreviewImage(
                              bytes: _bytes!,
                              failureLabel: l10n.locationPreviewImageFailed,
                            ),
                          ),
                        ),
                      if (_failed) Text(l10n.locationPreviewImageFailed),
                      if (hasDestination)
                        Text(
                          _opening
                              ? l10n.locationLoading
                              : l10n.locationOpenGoogleMaps,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Text may remain provider-derived after clear or template reuse.
          const LocationAttribution(),
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
  });
  final Uint8List bytes;
  final String failureLabel;
  @override
  State<_UncachedPreviewImage> createState() => _UncachedPreviewImageState();
}

class _UncachedPreviewImageState extends State<_UncachedPreviewImage> {
  ui.Image? _image;
  int _epoch = 0;
  bool _failed = false;
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
  Widget build(BuildContext context) => _failed
      ? Text(widget.failureLabel)
      : ExcludeSemantics(
          child: RawImage(image: _image, fit: BoxFit.contain),
        );
  @override
  void dispose() {
    ++_epoch;
    _image?.dispose();
    super.dispose();
  }
}
