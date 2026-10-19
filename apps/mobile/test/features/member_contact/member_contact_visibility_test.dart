import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/member_contact/presentation/member_contact_chat_screen.dart';
import 'package:planets_mobile/features/messages/application/message_chats_refresh.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/presentation/message_read_viewport.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../integration_test/member_contact_visibility.dart';
import '../messages/message_unread_test.dart' show Gateway;
import 'member_contact_fixtures.dart';
import 'member_contact_screens_test.dart' show basic, pumpMember;

void main() {
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language 320dp 2x oversized member notice owns visibility and scrolling',
      (tester) async {
        // A short real screen supplies the bounded notice geometry without
        // replacing the production chat, its layout, or its localized copy.
        tester.view.physicalSize = const Size(320, 520);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var token = boundary;
        final (container, _) = await pumpMember(
          tester,
          (name, args) async {
            if (name == 'get_own_member_contact_conversation') {
              return chatRow(readOnly: true);
            }
            if (name == 'get_own_member_contact_feed') {
              return {
                'items': [
                  for (var n = 8; n >= 1; n--)
                    {
                      ...messageRow(ordinal: n),
                      'id':
                          '00000000-0000-4000-8000-'
                          '${(800 + n).toString().padLeft(12, '0')}',
                      'body': 'Fictional retained message $n',
                    },
                ],
                'read_boundary': token,
              };
            }
            return basic(name, args);
          },
          path: '/chat',
          language: language,
          scale: 2,
        );
        final context = tester.element(find.byType(MemberContactChatScreen));
        final notice = find.text(
          AppLocalizations.of(context).memberContactReadOnly,
        );
        final owner = Scrollable.of(tester.element(notice));
        final ownerFinder = find.byElementPredicate(
          (element) =>
              element is StatefulElement && identical(element.state, owner),
        );
        final history = find.byType(MessageReadViewport);
        final historyController = tester
            .widget<MessageReadViewport>(history)
            .scrollController;
        expect(MediaQuery.sizeOf(context).width, 320);
        expect(MediaQuery.textScalerOf(context).scale(10), 20);
        expect(
          tester.getSize(notice).height,
          greaterThan(tester.getSize(ownerFinder).height),
        );
        expect(owner.position, isNot(same(historyController.position)));

        // Leave a fresh boundary pending while looking at older history. A
        // notice visibility operation must not scroll or acknowledge that feed.
        await tester.drag(history, const Offset(0, 150));
        await tester.pumpAndSettle();
        expect(historyController.position.extentAfter, greaterThan(1));
        token = '00000000-0000-4000-8000-000000000702';
        container.read(messageChatsRefreshProvider.notifier).notifyChanged();
        await tester.pumpAndSettle();
        final unread = container.read(messageUnreadGatewayProvider) as Gateway;
        final reads = unread.reads;
        final historyPixels = historyController.position.pixels;
        expect(tester.widget<MessageReadViewport>(history).boundary, token);
        await tester.ensureVisible(notice);
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          notice.hitTestable(),
          findsNothing,
          reason: 'Leading alignment leaves the tall notice center clipped.',
        );

        await revealMemberContactContent(tester, notice);
        expect(notice.hitTestable(), findsOneWidget);
        expect(find.byKey(const Key('contact-message-body')), findsNothing);
        expect(find.byKey(const Key('contact-message-send')), findsNothing);
        void unchangedHistory() {
          expect(
            historyController.position.pixels,
            closeTo(historyPixels, .01),
          );
          expect(unread.reads, reads);
        }

        unchangedHistory();

        // Scroll only the notice owner, first to its beginning and then through
        // overlapping text portions to its end. Every line remains reachable.
        final rect = tester.getRect(ownerFinder);
        for (
          var n = 0;
          n < 12 && tester.getTopLeft(notice).dy < rect.top;
          n++
        ) {
          await tester.dragFrom(
            Offset(rect.center.dx, rect.top + 8),
            Offset(0, rect.height * .55),
          );
          await tester.pumpAndSettle();
          unchangedHistory();
        }
        expect(tester.getTopLeft(notice).dy, greaterThanOrEqualTo(rect.top));
        expect(tester.getTopLeft(notice).dy, lessThan(rect.bottom));
        var covered = rect.bottom - tester.getTopLeft(notice).dy;
        for (
          var n = 0;
          n < 12 && tester.getBottomRight(notice).dy > rect.bottom;
          n++
        ) {
          await tester.dragFrom(
            Offset(rect.center.dx, rect.bottom - 8),
            Offset(0, -rect.height * .55),
          );
          await tester.pumpAndSettle();
          final top = tester.getTopLeft(notice).dy;
          expect(
            rect.top - top,
            lessThanOrEqualTo(covered + 1),
            reason: 'Successive visible portions overlap; no text is skipped.',
          );
          covered = rect.bottom - top;
          unchangedHistory();
        }
        expect(
          tester.getBottomRight(notice).dy,
          lessThanOrEqualTo(rect.bottom),
        );
        expect(tester.getBottomRight(notice).dy, greaterThan(rect.top));
        expect(covered, greaterThanOrEqualTo(tester.getSize(notice).height));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
