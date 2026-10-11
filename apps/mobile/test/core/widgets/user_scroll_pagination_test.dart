import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/widgets/user_scroll_pagination.dart';

void main() {
  testWidgets(
    'one request per drag; build, jump, animation and resize stay inert',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var requests = 0;
      final pending = Completer<void>();
      Widget host({bool enabled = true, Object key = 'a'}) => MaterialApp(
        home: Scaffold(
          body: UserScrollPagination(
            enabled: enabled,
            requestKey: key,
            onLoad: () {
              requests++;
              return pending.future;
            },
            builder: (_, fallback) => ListView.builder(
              controller: scroll,
              itemExtent: 100,
              itemCount: 40,
              itemBuilder: (_, i) => Text('Row $i'),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(requests, 0);
      scroll.jumpTo(scroll.position.maxScrollExtent - 100);
      await tester.pumpAndSettle();
      expect(requests, 0);
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pump();
      expect(requests, 1);
      await tester.fling(find.byType(ListView), const Offset(0, -200), 2000);
      await tester.pump();
      expect(requests, 1);
      pending.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(enabled: false));
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(requests, 1);
      await tester.pumpWidget(host(key: 'new-query'));
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      final move = scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );
      await tester.pumpAndSettle();
      await move;
      expect(requests, 1);
    },
  );
  for (final accessible in [false, true]) {
    testWidgets(
      'short and accessible lists expose deliberate fallback $accessible',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: accessible),
              child: Scaffold(
                body: UserScrollPagination(
                  enabled: true,
                  onLoad: () async {
                    calls++;
                  },
                  builder: (_, fallback) => ListView(
                    children: [
                      const Text('Short feed'),
                      if (fallback)
                        TextButton(
                          onPressed: () {
                            calls++;
                          },
                          child: const Text('Load more'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(find.text('Load more'), findsOneWidget);
        await tester.tap(find.text('Load more'));
        expect(calls, 1);
      },
    );
  }
  testWidgets(
    'history requires upward user movement and never initial bottom scroll',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserScrollPagination(
              enabled: true,
              towardStart: true,
              onLoad: () async {
                calls++;
              },
              builder: (_, fallback) => ListView.builder(
                controller: scroll,
                itemExtent: 80,
                itemCount: 90,
                itemBuilder: (_, i) => Text('Message $i'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(calls, 0);
      scroll.jumpTo(200);
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.drag(find.byType(ListView), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(calls, 1);
    },
  );
}
