import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';

import 'dart:io';

import 'package:planets_mobile/features/group_discussions/application/discussion_controllers.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_folders.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import 'discussion_test_support.dart';

Widget app(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  locale: locale,
  theme: ThemeData(brightness: brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);
void main() {
  testWidgets(
    'accepted invitation with a lost reply remains recoverable after the pending row disappears',
    (tester) async {
      final gateway = Gateway(),
          commands = DiscussionCommands(gateway, (_) => true);
      commands.attempts['invite/$admission'] = DiscussionAttempt(
        actor,
        DiscussionAction.respond,
        {
          'p_room_id': roomId,
          'p_invitation_id': admission,
          'p_response': 'accepted',
        },
      )..error = const SocketException('Lost committed acceptance reply.');
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          discussionGatewayProvider.overrideWithValue(gateway),
          discussionCommandsProvider.overrideWithValue(commands),
        ],
      );
      addTearDown(() async {
        container.dispose();
        commands.dispose();
        await gateway.hints.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(const DiscussionFolders()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsWidgets);
      expect(commands.attempts, isNotEmpty);
      expect(gateway.keys, isEmpty);
      expect(gateway.historyReads, 0);
    },
  );
  for (final lang in ['en', 'it']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$lang $brightness long folder, message and semantics at 320px / 2x',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var taps = 0;
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            app(
              Column(
                children: [
                  DiscussionFolderHeader(
                    name:
                        'Trento Green · Pianificazione collaborativa del parco',
                    unread: 4,
                    expanded: false,
                    onToggle: () => taps++,
                  ),
                  const DiscussionBubble(
                    body: 'Un messaggio lungo, con una descrizione del lavoro condiviso.',
                    sender: 'Un nome molto lungo',
                    own: false,
                  ),
                ],
              ),
              locale: Locale(lang),
              brightness: brightness,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.bySemanticsLabel(RegExp('Trento Green')), findsOneWidget);
          await tester.tap(find.byType(DiscussionFolderHeader));
          expect(taps, 1);
          semantics.dispose();
        },
      );
    }
  }
  testWidgets(
    'groups lazy-load rooms on expansion only; account switch removes content',
    (tester) async {
      final g = Gateway();
      final actual = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          discussionGatewayProvider.overrideWithValue(g),
        ],
      );
      addTearDown(() async {
        actual.dispose();
        await g.hints.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: actual,
          child: app(const DiscussionFolders()),
        ),
      );
      await tester.pumpAndSettle();
      expect(g.groupReads, 1);
      expect(g.roomReads, 0);
      expect(g.historyReads, 0);
      await tester.tap(find.byType(DiscussionFolderHeader));
      await tester.pumpAndSettle();
      expect(g.roomReads, 1);
      expect(find.text('Parco'), findsOneWidget);
      expect(g.historyReads, 0);
      await tester.tap(find.byType(DiscussionFolderHeader));
      await tester.pumpAndSettle();
      expect(find.text('Parco'), findsNothing);
      (actual.read(authSessionProvider.notifier) as Session).change(null);
      await tester.pumpAndSettle();
      expect(find.textContaining('Trento Green'), findsNothing);
    },
  );
}
