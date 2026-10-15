import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';
import 'package:planets_mobile/features/template_workshop/application/template_controllers.dart';
import 'package:planets_mobile/features/template_workshop/presentation/template_application_feedback.dart';
import 'package:planets_mobile/features/template_workshop/presentation/template_workshop_screens.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_template.dart';
import '../../../support/fake_proposal.dart';
import 'template_workshop_test.dart' as workshop;

void main() {
  testWidgets(
    'a covered Workshop keeps a late receipt without stealing navigation',
    (tester) async {
      final app = await workshop.pumpWorkshop(
        tester,
        initial: WorkshopRoutes.detail(templateId),
      );
      final pending = Completer<void>();
      app.templates.applyLoader = (attempt) async {
        await pending.future;
        return templateReceiptFixture(attempt);
      };
      await workshop.reveal(tester, find.byKey(const Key('template-use')));
      await tester.tap(find.byKey(const Key('template-use')));
      await tester.pump();
      app.router.push('/origin');
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Origin'), findsOneWidget);
      expect(find.byType(ProposalEditorScreen), findsNothing);
      app.router.pop();
      await tester.pumpAndSettle();
      final attempt = app.container
          .read(templateApplicationsProvider.notifier)
          .latest(templateActor, templateId)!;
      expect(attempt.destinationId, templateDestination);
      expect(
        app.container.read(templateFeedbackProvider).acknowledged,
        isEmpty,
      );
      app.router.go(WorkshopRoutes.catalog);
      await tester.pumpAndSettle();
      expect(find.text('Draft created'), findsOneWidget);
      expect(app.templates.commands, hasLength(1));
    },
  );
  testWidgets(
    'an unrelated owner projection never acknowledges the destination',
    (tester) async {
      final app = await workshop.pumpWorkshop(tester);
      final controller = app.container.read(
        templateApplicationsProvider.notifier,
      );
      await controller.use(templateActor, app.templates.value!, false);
      final attempt = controller.latest(templateActor, templateId)!;
      app.proposals.ownResult = Future.value(
        ownProposalFixture(id: needId(99)),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(Key('template-attempt-open-${attempt.requestId}')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(
        app.container.read(templateFeedbackProvider).acknowledged,
        isEmpty,
      );
      expect(
        app.container.read(templateFeedbackProvider).reads[attempt.requestId],
        ProposalEditorReadOutcome.failed,
      );
      expect(find.byKey(const Key('proposal-title')), findsNothing);
      expect(app.templates.commands, hasLength(1));
      app.router.go('/origin');
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'no attempt has no notice; success read acknowledges but receipt stays',
    (tester) async {
      final app = await workshop.pumpWorkshop(tester);
      expect(find.byType(TemplateApplicationNotice), findsNothing);
      await tester.tap(find.byKey(const Key('template-card-$templateId')));
      await tester.pumpAndSettle();
      await workshop.reveal(tester, find.byKey(const Key('template-use')));
      await tester.tap(find.byKey(const Key('template-use')));
      await tester.pumpAndSettle();
      expect(find.byType(ProposalEditorScreen), findsOneWidget);
      final attempt = app.container
          .read(templateApplicationsProvider.notifier)
          .latest(templateActor, templateId)!;
      expect(
        app.container.read(templateFeedbackProvider).acknowledged,
        contains(attempt.requestId),
      );
      expect(attempt.destinationId, templateDestination);
      app.router.pop();
      await tester.pumpAndSettle();
      await workshop.reveal(
        tester,
        find.byKey(const Key('template-retry-open')),
      );
      expect(find.text('Start another independent draft'), findsOneWidget);
      await tester.tap(find.byKey(const Key('template-retry-open')));
      await tester.pumpAndSettle();
      expect(find.text('Copied draft'), findsOneWidget);
      app.router.pop();
      await tester.pumpAndSettle();
      app.router.pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('template-attempt-notice-${attempt.requestId}')),
        findsNothing,
      );
      for (var i = 0; i < 2; i++) {
        app.router.go('/origin');
        await tester.pumpAndSettle();
        app.router.push(WorkshopRoutes.catalog);
        await tester.pumpAndSettle();
        expect(
          find.byKey(Key('template-attempt-notice-${attempt.requestId}')),
          findsNothing,
        );
      }
      expect(app.templates.commands, hasLength(1));
      expect(
        app.container
            .read(templateApplicationsProvider)
            .attempts[attempt.requestId]
            ?.destinationId,
        templateDestination,
      );
    },
  );

  testWidgets(
    'created notice opens its exact destination, or dismisses without mutation',
    (tester) async {
      final app = await workshop.pumpWorkshop(tester);
      final controller = app.container.read(
        templateApplicationsProvider.notifier,
      );
      await controller.use(templateActor, app.templates.value!, false);
      await tester.pumpAndSettle();
      final attempt = controller.latest(templateActor, templateId)!;
      expect(find.text('Draft created'), findsOneWidget);
      expect(find.textContaining('while the app is running'), findsNothing);
      await tester.tap(
        find.byKey(Key('template-attempt-dismiss-${attempt.requestId}')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Draft created'), findsNothing);
      expect(
        controller.latest(templateActor, templateId)!.requestId,
        attempt.requestId,
      );
      expect(app.templates.commands, hasLength(1));
      app.router.push(WorkshopRoutes.detail(templateId));
      await tester.pumpAndSettle();
      await workshop.reveal(
        tester,
        find.byKey(const Key('template-retry-open')),
      );
      await tester.tap(find.byKey(const Key('template-retry-open')));
      await tester.pumpAndSettle();
      expect(find.text('Copied draft'), findsOneWidget);
      expect(app.templates.commands, hasLength(1));
    },
  );

  testWidgets('returning from navigation is not an acknowledgement', (
    tester,
  ) async {
    final app = await workshop.pumpWorkshop(tester);
    final controller = app.container.read(
      templateApplicationsProvider.notifier,
    );
    await controller.use(templateActor, app.templates.value!, true);
    final attempt = controller.latest(templateActor, templateId)!;
    final handoff = controller.handoff(attempt.requestId)!;
    controller.dismissFeedback(
      attempt.requestId,
    ); // Busy acknowledgement is refused.
    handoff.returned();
    await tester.pumpAndSettle();
    expect(app.container.read(templateFeedbackProvider).acknowledged, isEmpty);
    app.router.go(WorkshopRoutes.catalog);
    await tester.pumpAndSettle();
    expect(find.text('Draft created'), findsOneWidget);
    expect(app.templates.commands, hasLength(1));
  });

  testWidgets(
    'applying double taps stay busy without claiming a draft exists',
    (tester) async {
      final app = await workshop.pumpWorkshop(
        tester,
        initial: WorkshopRoutes.detail(templateId),
      );
      final pending = Completer<void>();
      app.templates.applyLoader = (attempt) async {
        await pending.future;
        return templateReceiptFixture(attempt);
      };
      await workshop.reveal(tester, find.byKey(const Key('template-use')));
      await tester.tap(find.byKey(const Key('template-use')));
      await tester.pump();
      await workshop.reveal(
        tester,
        find.byKey(const Key('template-retry-open')),
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('template-retry-open')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('template-retry-open')));
      await tester.pump();
      expect(app.templates.commands, hasLength(1));
      expect(find.text('Draft created'), findsNothing);
      expect(find.text('Creating draft…'), findsWidgets);
      app.router.go('/origin');
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Origin'), findsOneWidget);
      app.router.push(WorkshopRoutes.catalog);
      await tester.pumpAndSettle();
      expect(find.text('Draft created'), findsOneWidget);
      expect(app.templates.commands, hasLength(1));
    },
  );

  for (final failedLookup in [false, true]) {
    testWidgets(
      'lost acknowledgement uses frozen request, failed lookup=$failedLookup',
      (tester) async {
        final app = await workshop.pumpWorkshop(
          tester,
          initial: WorkshopRoutes.detail(templateId),
        );
        app.templates.applyError = Exception('Synthetic lost acknowledgement');
        await workshop.reveal(tester, find.byKey(const Key('template-use')));
        await tester.tap(find.byKey(const Key('template-use')));
        await tester.pumpAndSettle();
        final controller = app.container.read(
          templateApplicationsProvider.notifier,
        );
        final attempt = controller.latest(templateActor, templateId)!;
        expect(find.text('Draft creation is unconfirmed'), findsOneWidget);
        expect(find.text('Draft created'), findsNothing);
        controller.dismissFeedback(attempt.requestId);
        expect(
          app.container.read(templateFeedbackProvider).acknowledged,
          isEmpty,
        );
        app.templates.applyError = null;
        if (failedLookup) {
          app.templates.recoverError = Exception(
            'Synthetic receipt read failed',
          );
        } else {
          app.templates.recovered = templateReceiptFixture(attempt);
        }
        await tester.tap(find.byKey(const Key('template-retry-open')));
        await tester.pumpAndSettle();
        expect(find.text('Copied draft'), findsOneWidget);
        expect(app.templates.commands, hasLength(failedLookup ? 2 : 1));
        expect(app.templates.commands.map((a) => a.requestId).toSet(), {
          attempt.requestId,
        });
        for (final command in app.templates.commands) {
          expect(
            (
              command.actor,
              command.templateId,
              command.token,
              command.prefillCapacity,
              command.groupId,
            ),
            (
              attempt.actor,
              attempt.templateId,
              attempt.token,
              attempt.prefillCapacity,
              attempt.groupId,
            ),
          );
        }
      },
    );
  }

  for (final failure in ['transport', 'removed', 'forbidden']) {
    testWidgets('editor $failure stays truthful and reopening never copies', (
      tester,
    ) async {
      final app = await workshop.pumpWorkshop(tester);
      final controller = app.container.read(
        templateApplicationsProvider.notifier,
      );
      await controller.use(templateActor, app.templates.value!, false);
      final attempt = controller.latest(templateActor, templateId)!;
      if (failure == 'transport') {
        app.proposals.ownReadError = Exception('Synthetic network failure');
      }
      if (failure == 'removed') app.proposals.ownItems = [];
      if (failure == 'forbidden') {
        app.proposals.ownReadError = const PostgrestException(
          message: 'Synthetic forbidden',
          code: '42501',
        );
      }
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(Key('template-attempt-open-${attempt.requestId}')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProposalEditorScreen), findsOneWidget);
      final outcome = failure == 'transport'
          ? ProposalEditorReadOutcome.failed
          : ProposalEditorReadOutcome.unavailable;
      expect(
        app.container.read(templateFeedbackProvider).reads[attempt.requestId],
        outcome,
      );
      expect(
        app.container.read(templateFeedbackProvider).acknowledged,
        isEmpty,
      );
      app.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Draft created'), findsNothing);
      expect(
        find.text(
          failure == 'transport'
              ? 'The draft could not be opened. Try opening it again.'
              : 'This draft is unavailable to this account.',
        ),
        findsOneWidget,
      );
      expect(
        app.container
            .read(templateApplicationsProvider)
            .attempts[attempt.requestId]
            ?.destinationId,
        templateDestination,
      );
      expect(app.templates.commands, hasLength(1));
      if (failure == 'transport') {
        app.proposals.ownReadError = null;
        await tester.tap(
          find.byKey(Key('template-attempt-open-${attempt.requestId}')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Copied draft'), findsOneWidget);
        expect(app.container.read(templateFeedbackProvider).reads, isEmpty);
        expect(
          app.container.read(templateFeedbackProvider).acknowledged,
          contains(attempt.requestId),
        );
        expect(app.templates.commands, hasLength(1));
      }
    });
  }

  testWidgets('navigation failure records an actionable reopening error', (
    tester,
  ) async {
    final app = await workshop.pumpWorkshop(tester);
    final controller = app.container.read(
      templateApplicationsProvider.notifier,
    );
    await controller.use(templateActor, app.templates.value!, false);
    final attempt = controller.latest(templateActor, templateId)!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: app.container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TemplateApplicationNotice(
                attempt: attempt,
                catalog: true,
                onResume: () =>
                    openTemplateDestination(context, ref, attempt.requestId),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('template-attempt-open-${attempt.requestId}')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The draft could not be opened. Try opening it again.'),
      findsOneWidget,
    );
    expect(
      controller.latest(templateActor, templateId)!.destinationId,
      templateDestination,
    );
    expect(app.templates.commands, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account switches hide other attempts and reject old handoff callbacks including ABA',
    (tester) async {
      final app = await workshop.pumpWorkshop(tester);
      final controller = app.container.read(
        templateApplicationsProvider.notifier,
      );
      await controller.use(templateActor, app.templates.value!, false);
      final attempt = controller.latest(templateActor, templateId)!;
      final stale = controller.handoff(attempt.requestId)!;
      app.container
          .read(authSessionProvider.notifier)
          .markProfileReady(AuthIdentity(id: needId(42)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('template-attempt-notice-${attempt.requestId}')),
        findsNothing,
      );
      expect(controller.handoff(attempt.requestId), isNull);
      stale.observer.onRead(ProposalEditorReadOutcome.loaded);
      app.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: templateActor));
      await tester.pumpAndSettle();
      stale.observer.onRead(ProposalEditorReadOutcome.loaded);
      stale.failed();
      stale.returned();
      expect(
        app.container.read(templateFeedbackProvider).acknowledged,
        isEmpty,
      );
      expect(app.container.read(templateFeedbackProvider).reads, isEmpty);
      final current = controller.handoff(attempt.requestId)!;
      current.observer.onRead(ProposalEditorReadOutcome.loaded);
      expect(
        app.container.read(templateFeedbackProvider).acknowledged,
        contains(attempt.requestId),
      );
      expect(app.templates.commands, hasLength(1));
      app.container.read(authSessionProvider.notifier).markSignedOut();
      await tester.pumpAndSettle();
      expect(find.byType(TemplateApplicationNotice), findsNothing);
      expect(controller.handoff(attempt.requestId), isNull);
    },
  );
}
