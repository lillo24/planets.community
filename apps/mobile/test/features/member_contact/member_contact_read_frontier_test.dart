import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/presentation/conversation_history_list.dart';
import 'package:planets_mobile/features/messages/presentation/message_read_viewport.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../integration_test/member_contact_read_frontier.dart';
import '../messages/message_unread_test.dart' show Gateway, Session, boundary;

void main() {
  testWidgets(
    '320dp 2x visible member body does not ACK until gestures reach card end',
    (tester) async {
      tester.view.physicalSize = const Size(320, 711);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final gateway = Gateway();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          messageUnreadGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      const body = 'Synthetic close reply from Fictional Bob.';
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                // Native chrome and the composer leave a short history window.
                // Exercise the real lazy history and ACK guard in that window.
                child: SizedBox(
                  height: 180,
                  child: MessageReadViewport(
                    profileId: 'reader',
                    kind: 'member_contact_chat',
                    chatId: 'chat',
                    boundary: boundary,
                    scrollController: scroll,
                    child: ConversationHistoryList<String>(
                      items: const [body],
                      itemKey: (item) => item,
                      controller: scroll,
                      enabled: true,
                      hasMore: false,
                      loading: false,
                      failed: false,
                      onLoadOlder: () async {},
                      fallbackLabel: 'Older messages',
                      buttonKey: const Key('older'),
                      empty: const SizedBox.shrink(),
                      itemBuilder: (context, item) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Fictional Bob'),
                              Text(item),
                              const Text('Oct 19, 2026 08:30'),
                              TextButton.icon(
                                key: const Key('message-report'),
                                onPressed: () {},
                                icon: const Icon(Icons.flag_outlined),
                                label: const Text('Report message'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text(body));
      await tester.pump(const Duration(milliseconds: 350));
      final viewport = find.byType(MessageReadViewport);
      final context = tester.element(viewport);
      expect(MediaQuery.sizeOf(context).width, 320);
      expect(MediaQuery.textScalerOf(context).scale(10), 20);
      expect(find.text(body).hitTestable(), findsOneWidget);
      expect(scroll.position.extentAfter, greaterThan(1));
      expect(gateway.reads, 0, reason: 'Body visibility is not the card end.');

      await readMemberContactFrontier(tester, actor: 'reader', chatId: 'chat');
      await tester.pump(const Duration(milliseconds: 300));
      expect(scroll.position.isScrollingNotifier.value, isFalse);
      expect(scroll.position.extentAfter, lessThanOrEqualTo(1));
      final report = find.byKey(const Key('message-report'));
      expect(report.hitTestable(), findsOneWidget);
      expect(
        tester.getBottomRight(report).dy,
        lessThanOrEqualTo(tester.getBottomRight(viewport).dy),
      );
      expect(gateway.reads, 1);
      expect(gateway.boundaries, [boundary]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
