import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/profile_photo/presentation/profile_photo_crop_view.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('cancel crop returns without a selection', (tester) async {
    await tester.pumpWidget(_CropHost(cropper: (bytes) async => bytes));
    await tester.tap(find.text('Open crop'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-photo-crop-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('No crop'), findsOneWidget);
  });

  testWidgets('successful square crop returns processed source bytes', (
    tester,
  ) async {
    final cropped = Uint8List.fromList([9, 8, 7]);
    await tester.pumpWidget(_CropHost(cropper: (_) async => cropped));
    await tester.tap(find.text('Open crop'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-photo-crop-use')));
    await tester.pumpAndSettle();

    expect(find.text('Crop length 3'), findsOneWidget);
  });

  testWidgets('Use photo is disabled while crop submission is pending', (
    tester,
  ) async {
    final pending = Completer<Uint8List>();
    var calls = 0;
    await tester.pumpWidget(
      _CropHost(
        cropper: (_) {
          calls++;
          return pending.future;
        },
      ),
    );
    await tester.tap(find.text('Open crop'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-photo-crop-use')));
    await tester.pump();
    final useButton = tester.widget<FilledButton>(
      find.byKey(const Key('profile-photo-crop-use')),
    );
    expect(useButton.onPressed, isNull);
    expect(calls, 1);
    pending.complete(Uint8List.fromList([1]));
    await tester.pumpAndSettle();
  });

  testWidgets('crop failure is safe and allows retry', (tester) async {
    await tester.pumpWidget(
      _CropHost(cropper: (_) async => throw StateError('raw decoder details')),
    );
    await tester.tap(find.text('Open crop'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-photo-crop-use')));
    await tester.pumpAndSettle();

    expect(find.text('Unable to prepare this photo.'), findsOneWidget);
    expect(find.textContaining('raw decoder'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('profile-photo-crop-use')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('crop controls adapt to small screen and high text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _CropHost(cropper: (bytes) async => bytes, textScale: 2.5),
    );
    await tester.tap(find.text('Open crop'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Use photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _CropHost extends StatefulWidget {
  const _CropHost({required this.cropper, this.textScale = 1});

  final TestCropper cropper;
  final double textScale;

  @override
  State<_CropHost> createState() => _CropHostState();
}

class _CropHostState extends State<_CropHost> {
  Uint8List? _result;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(widget.textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              Text(
                _result == null ? 'No crop' : 'Crop length ${_result!.length}',
              ),
              FilledButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<Uint8List>(
                    MaterialPageRoute(
                      builder: (_) => ProfilePhotoCropView(
                        sourceBytes: Uint8List.fromList([1, 2, 3]),
                        cropForTesting: widget.cropper,
                      ),
                    ),
                  );
                  if (mounted) setState(() => _result = result);
                },
                child: const Text('Open crop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
