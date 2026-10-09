import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/widgets/page_app_bar.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  test('every page header uses the arrow-free convention', () {
    final files = Directory('lib').listSync(recursive: true).whereType<File>();
    for (final file in files.where((file) => file.path.endsWith('.dart'))) {
      if (file.path.endsWith('page_app_bar.dart')) continue;
      expect(
        RegExp(r'\b(?:AppBar|SliverAppBar|BackButton)\(')
            .hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
  });

  for (final locale in ['en', 'it']) {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('Close and system Back share the guard ($locale/$platform)', (
        tester,
      ) async {
        final navigator = GlobalKey<NavigatorState>();
        var allowPop = false;
        var blocked = 0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => Scaffold(
                appBar: pageAppBar(context, title: const Text('Root')),
              ),
            ),
          ),
        );
        expect(find.byKey(const Key('page-close')), findsNothing);
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (context) => StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return PopScope(
                  canPop: allowPop,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop) blocked++;
                  },
                  child: Scaffold(
                    appBar: pageAppBar(
                      context,
                      title: const Text('Nested editor'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsNothing);
        final close = find.byKey(const Key('page-close'));
        final label = MaterialLocalizations.of(tester.element(close))
            .closeButtonTooltip;
        expect(
          find.descendant(of: close, matching: find.text(label)),
          findsOneWidget,
        );
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(blocked, 1);
        expect(find.text('Nested editor'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(blocked, 2);
        update(() => allowPop = true);
        await tester.pump();
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(find.text('Root'), findsOneWidget);
        expect(find.text('Nested editor'), findsNothing);
      });
    }

    testWidgets(
      'textual exit and existing actions fit 320px at 200% ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var closed = false;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                appBar: pageAppBar(
                  context,
                  title: const Text('A long localized page title'),
                  onClose: () => closed = true,
                  actions: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.edit)),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final semantics = tester.ensureSemantics();
        final close = find.byKey(const Key('page-close'));
        final label = MaterialLocalizations.of(tester.element(close))
            .closeButtonTooltip;
        expect(tester.getSemantics(close).label, label);
        await tester.tap(close);
        expect(closed, isTrue);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets('tutorial preview does not borrow the enclosing route exit', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox()),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => PageAppBarScope(
          child: Builder(
            builder: (context) => Scaffold(
              appBar: pageAppBar(context, title: const Text('Preview')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page-close')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Preview'), findsNothing);
  });
}
