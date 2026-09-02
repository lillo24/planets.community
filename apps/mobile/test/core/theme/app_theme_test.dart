import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';

void main() {
  test('provides Material 3 light and dark themes', () {
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.useMaterial3, isTrue);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.materialTapTargetSize, MaterialTapTargetSize.padded);
  });
}
