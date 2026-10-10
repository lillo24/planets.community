import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/startup/tutorial_project_chat_example.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  for (final language in ['en', 'it']) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('fictional conversation $language ${scale}x $brightness', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          // Deliberately no ProviderScope, Auth, Supabase or chat gateway.
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const TutorialProjectChatExample(),
            ),
          );
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(TutorialProjectChatExample)),
          );
          expect(
            find.bySemanticsLabel(l.tutorialChatExampleLabel),
            findsOneWidget,
          );
          expect(find.text(l.tutorialChatProjectTitle), findsOneWidget);
          expect(
            find.bySemanticsLabel('Giulia: ${l.tutorialChatDateMessage}'),
            findsOneWidget,
          );
          expect(find.byType(TextField), findsNothing);
          expect(find.byType(IconButton), findsNothing);
          expect(find.byType(ButtonStyleButton), findsNothing);
          expect(find.byType(BackButton), findsNothing);
          final conversation = find.byKey(
            const Key('tutorial-project-chat-conversation'),
          );
          final list = find.descendant(
            of: conversation,
            matching: find.byType(Scrollable),
          );
          final sara = find.byKey(const Key('tutorial-chat-message-sara'));
          await tester.scrollUntilVisible(sara, 100, scrollable: list);
          expect(
            find.bySemanticsLabel('Sara: ${l.tutorialChatSkillsMessage}'),
            findsOneWidget,
          );
          expect(find.text(l.tutorialChatMaterialsMessage), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('Giulia')).dy,
            lessThan(tester.getTopLeft(find.text('Marco')).dy),
          );
          expect(
            tester.getTopLeft(find.text('Marco')).dy,
            lessThan(tester.getTopLeft(find.text('Sara')).dy),
          );
          // The example label stays visible while expanded text scrolls.
          expect(
            find.byKey(const Key('tutorial-project-chat-label')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          semantics.dispose();
        });
      }
    }
  }
}
