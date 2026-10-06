import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/moderation/presentation/moderation_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/moderation/application/moderation_controllers.dart';
import 'package:planets_mobile/features/moderation/data/moderation_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_models.dart';
import 'package:planets_mobile/features/moderation/presentation/own_reports_screen.dart';
import 'package:planets_mobile/features/moderation/presentation/report_form_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_moderation.dart';

void main() {
  for (final locale in ['en', 'it']) {
    testWidgets(
      'template self-report uses shared route and manual receipt in $locale',
      (tester) async {
        final gateway = FakeModerationGateway();
        final container = _container(gateway);
        addTearDown(container.dispose);
        final target = proposalTemplateReportTarget(
          '00000000-0000-4000-8000-000000000101',
          'My completed template',
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      ModerationRoutes.openReport<void>(context, target),
                  child: const Text('Report template'),
                ),
              ),
            ),
            GoRoute(
              path: ModerationRoutes.newReport,
              builder: (context, state) => ReportFormScreen(
                target: state.extra! as ModerationReportTarget,
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              locale: Locale(locale),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.tap(find.text('Report template'));
        await tester.pumpAndSettle();
        expect(find.text('My completed template'), findsOneWidget);
        expect(
          find.byKey(const Key('moderation-group-disclosure')),
          findsNothing,
        );
        expect(
          find.textContaining(
            locale == 'en'
                ? 'Staff review reports manually'
                : 'Lo staff valuta',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('moderation-category')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'en' ? 'Other' : 'Altro').last);
        await tester.enterText(
          find.byKey(const Key('moderation-explanation')),
          'A sufficiently clear self-report explanation.',
        );
        gateway.submitError = StateError('ambiguous delivery');
        await tester.tap(find.byKey(const Key('moderation-submit')));
        await tester.pumpAndSettle();
        final retryId = gateway.clientSubmissionId;
        gateway.submitError = null;
        await tester.tap(find.byKey(const Key('moderation-submit')));
        await tester.pumpAndSettle();
        expect(gateway.clientSubmissionId, retryId);
        expect(gateway.target?.kind, ModerationTargetKind.proposalTemplate);
        expect(gateway.target?.contextKind, isNull);
        expect(find.byKey(const Key('moderation-received')), findsOneWidget);
        expect(
          find.text(locale == 'en' ? 'Received' : 'Ricevuto'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('validates category and explanation and shows group disclosure', (
    tester,
  ) async {
    final gateway = FakeModerationGateway();
    final container = _container(gateway);
    addTearDown(container.dispose);
    await _pump(
      tester,
      container,
      const ReportFormScreen(
        target: ModerationReportTarget(
          kind: ModerationTargetKind.projectChatMessage,
          id: '00000000-0000-4000-8000-000000000101',
          label: 'Project chat message',
        ),
      ),
    );

    expect(
      find.byKey(const Key('moderation-group-disclosure')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('moderation-submit')));
    await tester.pump();
    expect(find.text('Choose a reason.'), findsOneWidget);
    expect(find.textContaining('10 and 4,000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('moderation-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.enterText(
      find.byKey(const Key('moderation-explanation')),
      'A sufficiently clear explanation.',
    );
    await tester.tap(find.byKey(const Key('moderation-submit')));
    await tester.pumpAndSettle();

    expect(gateway.submitCount, 1);
    expect(gateway.target?.kind, ModerationTargetKind.projectChatMessage);
    expect(find.byKey(const Key('moderation-received')), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(
      tester,
      container,
      const ReportFormScreen(
        target: ModerationReportTarget(
          kind: ModerationTargetKind.projectChatMessage,
          id: '00000000-0000-4000-8000-000000000101',
          label: 'Project chat message',
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('moderation-received')), findsNothing);
    expect(find.byKey(const Key('moderation-submit')), findsOneWidget);
  });

  testWidgets('shows normal disclosure and safe retryable failure', (
    tester,
  ) async {
    final gateway = FakeModerationGateway()
      ..submitError = StateError('private');
    final container = _container(gateway);
    addTearDown(container.dispose);
    await _pump(
      tester,
      container,
      const ReportFormScreen(
        target: ModerationReportTarget(
          kind: ModerationTargetKind.resourceListing,
          id: '00000000-0000-4000-8000-000000000102',
          label: 'Shared ladder',
        ),
      ),
    );
    expect(
      find.byKey(const Key('moderation-standard-disclosure')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('moderation-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spam').last);
    await tester.enterText(
      find.byKey(const Key('moderation-explanation')),
      'A sufficiently clear explanation.',
    );
    await tester.tap(find.byKey(const Key('moderation-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moderation-submit-error')), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);
    expect(find.byKey(const Key('moderation-submit')), findsOneWidget);
  });

  testWidgets('renders only neutral reporter-facing review statuses', (
    tester,
  ) async {
    final gateway = FakeModerationGateway()
      ..items = [
        ownModerationReportFixture(),
        ownModerationReportFixture(
          reportId: '00000000-0000-4000-8000-000000000903',
          state: ModerationReviewState.underReview,
        ),
        ownModerationReportFixture(
          reportId: '00000000-0000-4000-8000-000000000904',
          state: ModerationReviewState.completed,
        ),
      ];
    final container = _container(gateway);
    addTearDown(container.dispose);
    await _pump(tester, container, const OwnReportsScreen());
    await tester.pumpAndSettle();

    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Under review'), findsOneWidget);
    expect(find.text('Review completed'), findsOneWidget);
    expect(find.textContaining('sanction'), findsNothing);
  });

  testWidgets('does not hide a refresh failure behind cached reports', (
    tester,
  ) async {
    final gateway = FakeModerationGateway()
      ..items = [ownModerationReportFixture()];
    final container = _container(gateway);
    addTearDown(container.dispose);
    await _pump(tester, container, const OwnReportsScreen());
    await tester.pumpAndSettle();

    gateway.listError = StateError('private');
    await container
        .read(ownModerationReportsProvider.notifier)
        .load('00000000-0000-4000-8000-000000000001');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('moderation-reports-refresh-error')), findsOne);
    expect(
      find.byKey(
        const Key('moderation-report-00000000-0000-4000-8000-000000000901'),
      ),
      findsOne,
    );
    expect(find.textContaining('private'), findsNothing);
  });
}

ProviderContainer _container(FakeModerationGateway gateway) {
  final container = ProviderContainer(
    overrides: [moderationGatewayProvider.overrideWithValue(gateway)],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(
        const AuthIdentity(id: '00000000-0000-4000-8000-000000000001'),
      );
  return container;
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget home,
) => tester.pumpWidget(
  UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  ),
);
