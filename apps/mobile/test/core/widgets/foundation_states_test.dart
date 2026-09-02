import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/widgets/empty_state.dart';
import 'package:planets_mobile/core/widgets/error_state.dart';
import 'package:planets_mobile/core/widgets/loading_state.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('loading state has a live-region semantic label', (tester) async {
    await tester.pumpWidget(const _LocalizedTestApp(child: LoadingState()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
  });

  testWidgets('empty state uses localized safe defaults', (tester) async {
    await tester.pumpWidget(const _LocalizedTestApp(child: EmptyState()));

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(
      find.text('New information will appear here when it is available.'),
      findsOneWidget,
    );
  });

  testWidgets('error state hides exception details and retries', (
    tester,
  ) async {
    var retryCount = 0;
    const secretException = 'DatabaseException secret=do-not-render';

    await tester.pumpWidget(
      _LocalizedTestApp(child: ErrorState(onRetry: () => retryCount += 1)),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining(secretException), findsNothing);
    await tester.tap(find.text('Try again'));
    expect(retryCount, 1);
  });
}

class _LocalizedTestApp extends StatelessWidget {
  const _LocalizedTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }
}
