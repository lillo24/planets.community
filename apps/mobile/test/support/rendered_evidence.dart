import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opt-in actual Flutter renders; normal CI does no filesystem/font work.
class RenderedEvidence {
  static const directory = String.fromEnvironment('UI_POLISH_CAPTURE_DIR');
  static const key = Key('ui-polish-render');

  static Future<void> loadFonts() async {
    if (directory.isEmpty) return;
    final fonts =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          File('$fonts/${entry.value}')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  }

  static Widget wrap(Widget child) =>
      directory.isEmpty ? child : RepaintBoundary(key: key, child: child);

  static Future<void> capture(WidgetTester tester, String name) async {
    if (directory.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    await tester.runAsync(() async {
      final frame = await boundary.toImage(pixelRatio: 1);
      try {
        final data = await frame.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('Flutter PNG encoding failed: $name');
        }
        await Directory(directory).create(recursive: true);
        await File('$directory/$name.png')
            .writeAsBytes(data.buffer.asUint8List());
      } finally {
        frame.dispose();
      }
    });
  }
}
