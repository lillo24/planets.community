import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Built content belongs to its nearest scrollable, which may be the bounded
/// notices area rather than the chat history. Center oversized content so its
/// hit-test point is reachable; only search other scrollables for absent rows.
Future<void> revealMemberContactContent(
  WidgetTester tester,
  Finder finder, {
  Future<void> Function()? onFailure,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  ScrollPosition? searched;
  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) {
      final element = tester.element(finder.first);
      final owner = Scrollable.maybeOf(element);
      final target = element.findRenderObject();
      if (owner != null && target != null) {
        await owner.position.ensureVisible(target, alignment: .5);
      }
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.hitTestable().evaluate().isNotEmpty) return;
      // A built target is not a missing lazy row. In particular, searching the
      // last page scrollable here would move history instead of its notice.
      continue;
    }
    // Retain the existing bounded search to build below-fold lazy rows.
    // EditableText has an inner viewport that cannot reveal page actions.
    final elements = find
        .byType(Scrollable)
        .evaluate()
        .where(
          (element) =>
              ModalRoute.of(element)?.isCurrent != false &&
              element.findAncestorWidgetOfExactType<EditableText>() == null,
        );
    if (elements.isNotEmpty) {
      final position =
          ((elements.last as StatefulElement).state as ScrollableState)
              .position;
      if (position.hasContentDimensions) {
        if (searched != position) {
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
    await tester.pump(const Duration(milliseconds: 200));
  }
  debugPrint('M native missing visible content: $finder');
  await onFailure?.call();
  expect(
    finder.hitTestable(),
    findsWidgets,
    reason: 'Real native content must load and become visible.',
  );
}
