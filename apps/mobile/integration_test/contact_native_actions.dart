import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reveal and tap one current D action, including a lazy child moved by refresh.
/// Readiness and the gesture share a frame: no extra pump may follow the final
/// visible/enabled check. The post-gesture pump only lets its real handler run.
Future<void> tapContactNativeAction(
  WidgetTester tester,
  String key, {
  Future<void> Function(String diagnostics)? onFailure,
}) async {
  final finder = find.byKey(Key(key));
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  ScrollPosition? searched;
  var diagnostics = 'No current action has rendered.';
  for (
    var frame = 0;
    frame < 225 && DateTime.now().isBefore(deadline);
    frame++
  ) {
    final matches = finder.evaluate().toList();
    final visible = finder.hitTestable().evaluate().length;
    final widget = matches.length == 1 ? matches.single.widget : null;
    final enabled =
        widget != null &&
        (widget is! ButtonStyleButton || widget.onPressed != null);
    diagnostics =
        'Action $key: matches=${matches.length}, visible=$visible, '
        'enabled=$enabled.';
    if (matches.length == 1 && visible == 1 && enabled) {
      // An awaited readiness helper used to pump another 300ms here. A neutral
      // access refresh could then dispose this lazy child before tester.tap.
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    if (matches.length > 1) break;
    if (matches.length == 1 && visible == 0) {
      await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    } else if (matches.isEmpty) {
      // Re-find the current route's ListView after every awaited frame. Never
      // retain a disposed route's scrollable or scroll an EditableText instead.
      final scrolls = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      final elements = scrolls.evaluate().where(
        (element) =>
            ModalRoute.of(element)?.isCurrent != false &&
            element.findAncestorWidgetOfExactType<EditableText>() == null,
      );
      if (elements.isNotEmpty) {
        final state =
            (elements.last as StatefulElement).state as ScrollableState;
        final position = state.position;
        if (position.hasContentDimensions) {
          if (searched != position || position.extentAfter <= 0) {
            searched = position;
            position.jumpTo(position.minScrollExtent);
          } else {
            position.jumpTo(
              (position.pixels + 180).clamp(
                position.minScrollExtent,
                position.maxScrollExtent,
              ),
            );
          }
        }
      }
    }
    // Every asynchronous reveal, disabled wait or refresh returns to the same
    // visibility/enablement check. An absent action always times out as failure.
    await tester.pump(const Duration(milliseconds: 200));
  }
  await onFailure?.call(diagnostics);
  fail('Native action must become uniquely visible and enabled. $diagnostics');
}
