import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

import '../test/features/messages/presentation/messages_guest_navigation_test.dart'
    as messages;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final signedIn in [false, true]) {
    for (final language in [
      LanguagePreference.english,
      LanguagePreference.italian,
    ]) {
      testWidgets(
        'Messages toolbar ${signedIn ? 'ready' : 'guest'} ${language.name}',
        (tester) async {
          await messages.pumpMessagesSmoke(
            tester,
            signedIn: signedIn,
            language: language,
          );
          await binding.convertFlutterSurfaceToImage();
          await tester.pump();
          final prefix =
              'msg04-${signedIn ? 'ready' : 'guest'}-${language.name}';
          expect(find.byType(TabBar), findsNothing);
          expect(find.byType(BackButton), findsNothing);
          await binding.takeScreenshot('$prefix-chats');
          await tester.tap(find.byKey(const Key('message-chat-scope-groups')));
          await tester.pumpAndSettle();
          await binding.takeScreenshot('$prefix-groups');
          await tester.tap(find.byKey(const Key('messages-requests-action')));
          await tester.pumpAndSettle();
          expect(find.byType(BackButton), findsOneWidget);
          await binding.takeScreenshot('$prefix-requests');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(BackButton), findsNothing);
          expect(
            find.byKey(const Key('message-chat-scope-toggle')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
