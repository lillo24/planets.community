import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_folders.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import 'discussion_test_support.dart';

Map<String, dynamic> _legacy() => {
  'invitation_id': admission,
  'status': 'pending',
  'room_id': roomId,
  'group_id': groupId,
  'title': 'Parco',
  'group_name': 'Trento Green',
  'inviter_name': 'Fictional creator',
  'created_at': '2026-10-14T10:00:00Z',
};

Map<String, dynamic> _revised(String purpose, String visibility) => {
  ..._legacy(),
  'purpose': purpose,
  'visibility': visibility,
};

class _Invitations extends Gateway {
  _Invitations(this.invitation);
  final DiscussionInvitation invitation;
  int invitationReads = 0, contextReads = 0, peopleReads = 0;

  @override
  Future<List<DiscussionInvitation>> invitations(
    String actor,
    Map<String, dynamic>? cursor,
  ) async {
    invitationReads++;
    return [invitation];
  }

  @override
  Future<DiscussionRoom> room(String actor, String roomId) async {
    contextReads++;
    throw StateError('An invitation preview must not enter the room.');
  }

  @override
  Future<List<DiscussionPerson>> people(
    String actor,
    String roomId,
    Map<String, dynamic>? cursor,
  ) async {
    peopleReads++;
    throw StateError('An invitation preview must not fetch the roster.');
  }
}

void main() {
  test('legacy invitation retains its exact eight-field contract', () {
    final invitation = DiscussionInvitation(_legacy());
    expect(invitation.id, admission);
    expect(invitation.title, 'Parco');
    expect(invitation.purpose, isNull);
    expect(invitation.visibility, isNull);
    expect(
      () => DiscussionInvitation({..._legacy(), 'extra': true}),
      throwsFormatException,
    );
  });

  test('v2 invitation requires bounded purpose and a canonical audience', () {
    for (final audience in ['group', 'invitation']) {
      for (final purpose in ['', List.filled(500, 'a').join()]) {
        final invitation = DiscussionInvitation(_revised(purpose, audience));
        expect(invitation.purpose, purpose);
        expect(invitation.visibility, audience);
      }
    }
    final valid = _revised('Plan a shared garden.', 'invitation');
    for (final malformed in [
      {...valid, 'purpose': null},
      {...valid, 'purpose': 1},
      {...valid, 'purpose': List.filled(501, 'a').join()},
      {...valid, 'visibility': null},
      {...valid, 'visibility': 'public'},
      {...valid, 'status': 'accepted'},
      {...valid, 'messages': <Object>[]},
      Map<String, dynamic>.of(valid)..remove('purpose'),
      Map<String, dynamic>.of(valid)..remove('visibility'),
    ]) {
      expect(
        () => DiscussionInvitation(malformed),
        throwsFormatException,
        reason: malformed.toString(),
      );
    }
  });

  for (final language in ['en', 'it']) {
    for (final audience in ['group', 'invitation']) {
      testWidgets(
        '$language $audience invitation shows purpose and audience before consent at320dp/1.8',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final sentence = language == 'en'
              ? 'We plan a welcoming neighbourhood garden together.'
              : 'Progettiamo insieme un giardino di quartiere accogliente.';
          final purpose = List.filled(
            15,
            sentence,
          ).join(' ').substring(0, 500).trimRight().padRight(500, '.');
          final gateway = _Invitations(
            DiscussionInvitation(_revised(purpose, audience)),
          );
          final container = ProviderContainer(
            overrides: [
              authSessionProvider.overrideWith(Session.new),
              discussionGatewayProvider.overrideWithValue(gateway),
            ],
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            container.dispose();
            await gateway.hints.close();
          });
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(1.8)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: SingleChildScrollView(child: DiscussionRequests()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(DiscussionInvitationTile)),
          );
          final audienceLabel = audience == 'group'
              ? l.discussionGroupVisible
              : l.discussionInviteOnly;
          expect(find.text('Parco'), findsOneWidget);
          expect(find.text(purpose), findsOneWidget);
          expect(
            find.text('${l.discussionAudience}: $audienceLabel'),
            findsOneWidget,
          );
          expect(find.text('Trento Green'), findsOneWidget);
          expect(find.text('Fictional creator'), findsOneWidget);
          expect(find.text(l.discussionConsent), findsOneWidget);
          expect(tester.takeException(), isNull);

          void expectPreviewOnly() {
            expect(gateway.invitationReads, 1);
            expect(gateway.contextReads, 0);
            expect(gateway.historyReads, 0);
            expect(gateway.peopleReads, 0);
            expect(gateway.keys, isEmpty);
          }

          expectPreviewOnly();
          final accept = find.widgetWithText(FilledButton, l.discussionAccept);
          await tester.ensureVisible(accept);
          await tester.pumpAndSettle();
          expect(accept.hitTestable(), findsOneWidget);
          await tester.tap(accept);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expectPreviewOnly();
          final cancel = find.widgetWithText(TextButton, l.groupCancel);
          await tester.ensureVisible(cancel);
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text(purpose), findsOneWidget);
          expectPreviewOnly();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
