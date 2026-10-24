import 'dart:io';

import 'package:flutter/services.dart';

/// Use the pinned Flutter SDK's Android text metrics for whole-form layout
/// checks. Ahem can overflow unrelated toolbars even when Android text fits.
/// This is a widget test font, never evidence of native execution.
Future<void> loadAndroidTextFont() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) {
    throw StateError(
      'Run these widget tests through flutter test (FLUTTER_ROOT).',
    );
  }
  // Preserve the SDK artifact's exact case for Linux CI.
  final font = File(
    '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  );
  await (FontLoader(
    'Roboto',
  )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
}
