import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/messages/presentation/conversation_history_list.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  for (final accessible in [false, true]) {
    testWidgets('deliberate history fallback with accessible=$accessible', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(accessibleNavigation: accessible),
            child: Scaffold(
              body: ConversationHistoryList<int>(
                items: [for (var i = 0; i < (accessible ? 30 : 2); i++) i],
                itemKey: (item) => item,
                itemBuilder: (context, item) =>
                    SizedBox(height: 60, child: Text('$item')),
                controller: controller,
                enabled: true,
                hasMore: true,
                loading: false,
                failed: false,
                onLoadOlder: () async {
                  calls++;
                },
                fallbackLabel: 'Older',
                buttonKey: const Key('older'),
                empty: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byKey(const Key('older')), findsOneWidget);
      await tester.tap(find.byKey(const Key('older')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final size in [const Size(320, 800), const Size(1200, 1600)]) {
    testWidgets('variable-height history keeps its anchor at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var oldest = 100;
      var loading = false;
      var failed = false;
      var calls = 0;
      Completer<void>? pending;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: ConversationHistoryList<int>(
                  items: [for (var i = oldest; i < 130; i++) i],
                  itemKey: (item) => item,
                  itemBuilder: (context, item) => SizedBox(
                    key: ValueKey('row-$item'),
                    height: 60.0 + item % 5 * 27,
                    child: Text('Message $item'),
                  ),
                  controller: controller,
                  enabled: true,
                  hasMore: oldest > 0,
                  loading: loading,
                  failed: failed,
                  onLoadOlder: () async {
                    calls++;
                    update(() => loading = true);
                    if (pending case final wait?) await wait.future;
                    update(() {
                      loading = false;
                      if (!failed) oldest = (oldest - 30).clamp(0, 130);
                    });
                  },
                  fallbackLabel: 'Older',
                  buttonKey: const Key('older'),
                  empty: const SizedBox.shrink(),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byKey(const Key('older')), findsNothing);

      // Open/send, offset restoration, layout and keyboard are programmatic.
      unawaited(
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 1),
          curve: Curves.linear,
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(200);
      await tester.pumpAndSettle();
      update(() {});
      await tester.pumpAndSettle();
      expect(calls, 0);

      for (var page = 0; page < 4; page++) {
        controller.jumpTo(controller.position.minScrollExtent + 150);
        await tester.pumpAndSettle();
        pending = Completer<void>();
        final gesture = await tester.startGesture(const Offset(150, 350));
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
        expect(calls, page + 1);
        // More notifications in the same gesture must coalesce.
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump();
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 500));
        final anchor = oldest + 2;
        final before = tester
            .getTopLeft(find.byKey(ValueKey('row-$anchor')))
            .dy;
        final offset = controller.offset;
        pending.complete();
        await tester.pumpAndSettle();
        expect(controller.offset, closeTo(offset, .01));
        expect(
          tester.getTopLeft(find.byKey(ValueKey('row-$anchor'))).dy,
          closeTo(before, .01),
        );
        expect(calls, page + 1);
      }
      expect(oldest, 0);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 150));
      await tester.pumpAndSettle();
      expect(calls, 4);

      // A failed continuation cannot become a scroll-driven retry loop.
      update(() {
        oldest = 40;
        failed = true;
      });
      controller.jumpTo(controller.position.minScrollExtent);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(calls, 4);
      expect(find.text('Try again'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
