import 'dart:async';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

typedef TestCropper = Future<Uint8List> Function(Uint8List sourceBytes);

class ProfilePhotoCropView extends StatefulWidget {
  const ProfilePhotoCropView({
    required this.sourceBytes,
    this.cropForTesting,
    super.key,
  });

  final Uint8List sourceBytes;
  final TestCropper? cropForTesting;

  @override
  State<ProfilePhotoCropView> createState() => _ProfilePhotoCropViewState();
}

class _ProfilePhotoCropViewState extends State<ProfilePhotoCropView> {
  final _controller = CropController();
  var _ready = false;
  var _cropping = false;
  var _failed = false;

  Future<void> _usePhoto() async {
    if (_cropping || (!_ready && widget.cropForTesting == null)) return;
    setState(() {
      _cropping = true;
      _failed = false;
    });
    final testCropper = widget.cropForTesting;
    if (testCropper == null) {
      _controller.crop();
      return;
    }
    try {
      _complete(await testCropper(widget.sourceBytes));
    } catch (_) {
      _fail();
    }
  }

  void _onCropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        _complete(croppedImage);
      case CropFailure():
        _fail();
    }
  }

  void _complete(Uint8List bytes) {
    if (!mounted) return;
    Navigator.of(context).pop(bytes);
  }

  void _fail() {
    if (!mounted) return;
    setState(() {
      _cropping = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: pageAppBar(
        context,
        automaticallyImplyClose: false,
        title: Text(l10n.profilePhotoAdjust),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Semantics(
                label: l10n.profilePhotoAdjust,
                child: widget.cropForTesting == null
                    ? Crop(
                        key: const Key('profile-photo-crop'),
                        image: widget.sourceBytes,
                        controller: _controller,
                        onCropped: _onCropped,
                        onStatusChanged: (status) {
                          if (!mounted) return;
                          setState(() {
                            _ready = status == CropStatus.ready;
                            if (status != CropStatus.cropping) {
                              _cropping = false;
                            }
                          });
                        },
                        aspectRatio: 1,
                        interactive: true,
                        fixCropRect: true,
                        filterQuality: FilterQuality.high,
                        progressIndicator: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : const ColoredBox(
                        color: Colors.black12,
                        child: Center(child: Icon(Icons.crop, size: 72)),
                      ),
              ),
            ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.large,
                  AppSpacing.small,
                  AppSpacing.large,
                  0,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.profilePhotoPrepareError,
                    key: const Key('profile-photo-crop-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.small,
                children: [
                  TextButton(
                    key: const Key('profile-photo-crop-cancel'),
                    onPressed: _cropping
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.profilePhotoCancel),
                  ),
                  FilledButton.icon(
                    key: const Key('profile-photo-crop-use'),
                    onPressed:
                        (_ready || widget.cropForTesting != null) && !_cropping
                        ? _usePhoto
                        : null,
                    icon: _cropping
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(l10n.profilePhotoUse),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
