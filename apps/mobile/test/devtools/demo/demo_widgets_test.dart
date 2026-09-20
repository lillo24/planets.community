import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/devtools/demo/demo_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('indicator is semantic and fill action mutates only on tap', (
    tester,
  ) async {
    var fillCount = 0;
    await _pump(
      tester,
      enableDemoTools: 'true',
      child: Column(
        children: [
          const DemoIndicator(),
          DemoFillSampleAction(
            buttonKey: const Key('fill-sample'),
            onPressed: () => fillCount += 1,
          ),
        ],
      ),
    );

    expect(find.byKey(const Key('demo-indicator')), findsOneWidget);
    expect(find.bySemanticsLabel('Demo tools enabled'), findsOneWidget);
    expect(find.byKey(const Key('fill-sample')), findsOneWidget);
    expect(fillCount, 0);
    await tester.tap(find.byKey(const Key('fill-sample')));
    expect(fillCount, 1);
  });

  testWidgets('fill action is absent when demo tools are disabled', (
    tester,
  ) async {
    await _pump(
      tester,
      enableDemoTools: 'false',
      child: DemoFillSampleAction(
        buttonKey: const Key('fill-sample'),
        onPressed: () {},
      ),
    );

    expect(find.byKey(const Key('fill-sample')), findsNothing);
    expect(find.text('Fill sample data'), findsNothing);
  });

  testWidgets('fill action disables while its form is busy', (tester) async {
    await _pump(
      tester,
      enableDemoTools: 'true',
      child: const DemoFillSampleAction(
        buttonKey: Key('fill-sample'),
        onPressed: null,
      ),
    );

    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('fill-sample')))
          .onPressed,
      isNull,
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required String enableDemoTools,
  required Widget child,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.fromValues(
          appEnvironment: 'local',
          supabaseUrl: 'http://127.0.0.1:54321',
          supabasePublishableKey: 'test-key',
          enableDemoTools: enableDemoTools,
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  ),
);
