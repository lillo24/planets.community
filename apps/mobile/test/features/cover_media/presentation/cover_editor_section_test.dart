import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/cover_media/application/cover_media_processor.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_picker.dart';
import 'package:planets_mobile/features/cover_media/domain/cover_media_models.dart';
import 'package:planets_mobile/features/cover_media/presentation/cover_editor_section.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_cover_media.dart';

const _owner = 'c1000000-0000-4000-8000-000000000001';
const _project = 'c2000000-0000-4000-8000-000000000001';
const _path =
    '$_owner/projects/$_project/c3000000-0000-4000-8000-000000000001.webp';

void main() {
  testWidgets(
    'selection, crop, and processing remain local until parent save',
    (tester) async {
      final gateway = FakeCoverMediaGateway();
      CoverChange? change;
      await tester.pumpWidget(
        _host(
          gateway: gateway,
          picker: _Picker(Uint8List.fromList([1, 2, 3])),
          processor: _Processor(processedCoverFixture()),
          onChanged: (value) => change = value,
        ),
      );

      await tester.tap(find.byKey(const Key('cover-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('test-crop-use')));
      await tester.pumpAndSettle();

      expect(change?.kind, CoverChangeKind.replacement);
      expect(find.byKey(const Key('cover-change')), findsOneWidget);
      expect(gateway.calls, isEmpty);
    },
  );

  testWidgets('cancelling crop keeps canonical state unchanged', (
    tester,
  ) async {
    CoverChange? change;
    await tester.pumpWidget(
      _host(
        gateway: FakeCoverMediaGateway(),
        picker: _Picker(Uint8List.fromList([1])),
        processor: _Processor(processedCoverFixture()),
        onChanged: (value) => change = value,
      ),
    );

    await tester.tap(find.byKey(const Key('cover-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-crop-cancel')));
    await tester.pumpAndSettle();

    expect(change, isNull);
    expect(find.byKey(const Key('cover-add')), findsOneWidget);
  });

  testWidgets('gallery cancel creates no local change or media operation', (
    tester,
  ) async {
    final gateway = FakeCoverMediaGateway();
    CoverChange? change;
    await tester.pumpWidget(
      _host(
        gateway: gateway,
        picker: const _Picker(null),
        processor: _Processor(processedCoverFixture()),
        onChanged: (value) => change = value,
      ),
    );

    await tester.tap(find.byKey(const Key('cover-add')));
    await tester.pumpAndSettle();

    expect(change, isNull);
    expect(gateway.calls, isEmpty);
    expect(find.byKey(const Key('cover-add')), findsOneWidget);
  });

  testWidgets('gallery read failure is local and hides raw details', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        gateway: FakeCoverMediaGateway(),
        picker: const _ThrowingPicker(),
        processor: _Processor(processedCoverFixture()),
        onChanged: (_) {},
      ),
    );

    await tester.tap(find.byKey(const Key('cover-add')));
    await tester.pumpAndSettle();

    expect(find.text('Cover could not be prepared.'), findsOneWidget);
    expect(find.textContaining('gallery internals'), findsNothing);
  });

  testWidgets('removing an existing cover emits local removal only', (
    tester,
  ) async {
    final gateway = FakeCoverMediaGateway();
    CoverChange? change;
    await tester.pumpWidget(
      _host(
        gateway: gateway,
        picker: _Picker(null),
        processor: _Processor(processedCoverFixture()),
        canonicalPath: _path,
        onChanged: (value) => change = value,
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('cover-remove')));
    await tester.pump();

    expect(change?.kind, CoverChangeKind.removal);
    expect(find.byKey(const Key('cover-add')), findsOneWidget);
    expect(gateway.calls, isEmpty);
  });

  testWidgets('processor failure shows safe localized copy', (tester) async {
    await tester.pumpWidget(
      _host(
        gateway: FakeCoverMediaGateway(),
        picker: _Picker(Uint8List.fromList([1])),
        processor: _ThrowingProcessor(),
        onChanged: (_) {},
      ),
    );

    await tester.tap(find.byKey(const Key('cover-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-crop-use')));
    await tester.pumpAndSettle();

    expect(find.text('Cover could not be prepared.'), findsOneWidget);
    expect(find.textContaining('decoder internals'), findsNothing);
  });

  testWidgets('typed oversize failure uses specific safe copy', (tester) async {
    await tester.pumpWidget(
      _host(
        gateway: FakeCoverMediaGateway(),
        picker: _Picker(Uint8List.fromList([1])),
        processor: const _TooLargeProcessor(),
        onChanged: (_) {},
      ),
    );

    await tester.tap(find.byKey(const Key('cover-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-crop-use')));
    await tester.pumpAndSettle();

    expect(find.text('Cover is too large.'), findsOneWidget);
  });
}

Widget _host({
  required CoverMediaGateway gateway,
  required CoverMediaPicker picker,
  required CoverMediaProcessor processor,
  required ValueChanged<CoverChange> onChanged,
  String? canonicalPath,
}) {
  return ProviderScope(
    overrides: [
      coverMediaGatewayProvider.overrideWithValue(gateway),
      coverMediaPickerProvider.overrideWithValue(picker),
      coverMediaProcessorProvider.overrideWithValue(processor),
      coverCropPageBuilderProvider.overrideWithValue(
        (bytes) => _CropPage(bytes: bytes),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CoverEditorSection(
            ownerProfileId: _owner,
            title: 'Draft',
            canonicalObjectPath: canonicalPath,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
}

class _Picker implements CoverMediaPicker {
  const _Picker(this.result);

  final Uint8List? result;

  @override
  Future<Uint8List?> pickFromGallery() async => result;
}

class _ThrowingPicker implements CoverMediaPicker {
  const _ThrowingPicker();

  @override
  Future<Uint8List?> pickFromGallery() {
    throw StateError('gallery internals');
  }
}

class _Processor implements CoverMediaProcessor {
  const _Processor(this.result);

  final ProcessedCoverImage result;

  @override
  Future<ProcessedCoverImage> process(Uint8List croppedBytes) async => result;
}

class _ThrowingProcessor implements CoverMediaProcessor {
  @override
  Future<ProcessedCoverImage> process(Uint8List croppedBytes) {
    throw StateError('decoder internals');
  }
}

class _TooLargeProcessor implements CoverMediaProcessor {
  const _TooLargeProcessor();

  @override
  Future<ProcessedCoverImage> process(Uint8List croppedBytes) {
    throw const CoverMediaTooLargeException();
  }
}

class _CropPage extends StatelessWidget {
  const _CropPage({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          TextButton(
            key: const Key('test-crop-cancel'),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('test-crop-use'),
            onPressed: () => Navigator.pop(context, bytes),
            child: const Text('Use'),
          ),
        ],
      ),
    );
  }
}
