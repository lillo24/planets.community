import 'dart:async';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:planets_mobile/features/cover_media/presentation/cover_crop_view.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('real crop surface is interactive and fixed to 16:9', (
    tester,
  ) async {
    await tester.pumpWidget(_launcher(sourceBytes: _sourceBytes()));
    await tester.tap(find.byKey(const Key('open-cover-crop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final crop = tester.widget<Crop>(find.byType(Crop));
    expect(crop.aspectRatio, closeTo(16 / 9, 0.0001));
    expect(crop.interactive, isTrue);
    expect(crop.fixCropRect, isTrue);
  });

  testWidgets('cancel closes the crop without returning image bytes', (
    tester,
  ) async {
    Uint8List? result;
    await tester.pumpWidget(
      _launcher(
        sourceBytes: _sourceBytes(),
        cropForTesting: (bytes) async => bytes,
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.byKey(const Key('open-cover-crop')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cover-crop-cancel')));
    await tester.pumpAndSettle();

    expect(find.byType(CoverCropView), findsNothing);
    expect(result, isNull);
  });

  testWidgets('successful crop returns bytes and disables actions in flight', (
    tester,
  ) async {
    final pending = Completer<Uint8List>();
    Uint8List? result;
    await tester.pumpWidget(
      _launcher(
        sourceBytes: _sourceBytes(),
        cropForTesting: (_) => pending.future,
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.byKey(const Key('open-cover-crop')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cover-crop-use')));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('cover-crop-cancel')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('cover-crop-use')))
          .onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final cropped = Uint8List.fromList([9, 8, 7]);
    pending.complete(cropped);
    await tester.pumpAndSettle();

    expect(result, same(cropped));
    expect(find.byType(CoverCropView), findsNothing);
  });

  testWidgets('crop failure stays local, safe, and retryable', (tester) async {
    await tester.pumpWidget(
      _launcher(
        sourceBytes: _sourceBytes(),
        cropForTesting: (_) => throw StateError('crop internals'),
      ),
    );
    await tester.tap(find.byKey(const Key('open-cover-crop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cover-crop-use')));
    await tester.pumpAndSettle();

    expect(find.text('Cover could not be prepared.'), findsOneWidget);
    expect(find.textContaining('crop internals'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('cover-crop-use')))
          .onPressed,
      isNotNull,
    );
  });
}

Widget _launcher({
  required Uint8List sourceBytes,
  TestCoverCropper? cropForTesting,
  ValueChanged<Uint8List?>? onResult,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => FilledButton(
          key: const Key('open-cover-crop'),
          onPressed: () async {
            final result = await Navigator.of(context).push<Uint8List>(
              MaterialPageRoute(
                builder: (_) => CoverCropView(
                  sourceBytes: sourceBytes,
                  cropForTesting: cropForTesting,
                ),
              ),
            );
            onResult?.call(result);
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

Uint8List _sourceBytes() {
  final source = image.Image(width: 32, height: 18);
  image.fill(source, color: image.ColorRgb8(60, 120, 180));
  return image.encodePng(source);
}
