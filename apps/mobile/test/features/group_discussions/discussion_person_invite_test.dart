import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/application/discussion_controllers.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_invite_destinations_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_invite_destination.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_person_invite.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/policies/application/policy_documents.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'discussion_test_support.dart';
import 'discussion_widgets_test.dart' show app;

Map<String, dynamic> destinationRow() => {
  'room_id': roomId,
  'group_id': groupId,
  'target_profile_id': id(9),
  'title': 'Synthetic invitation destination',
  'purpose': 'Plan a shared garden.',
  'visibility': 'invitation',
  'created_at': '2026-10-14T10:00:00Z',
};
DiscussionInviteDestination destination() =>
    DiscussionInviteDestination(destinationRow(), groupId, id(9));

class Destinations implements DiscussionInviteDestinationsGateway {
  List<DiscussionInviteDestination> rows = [destination()];
  Completer<List<DiscussionInviteDestination>>? held;
  Object? failure;
  String expectedPerson = id(9);
  final actors = <String>[];
  @override
  Future<List<DiscussionInviteDestination>> page(
    String actor,
    String group,
    String person,
    Map<String, dynamic>? cursor,
  ) {
    actors.add(actor);
    expect(group, groupId);
    expect(person, expectedPerson);
    if (failure != null) return Future.error(failure!);
    return held?.future ?? Future.value(rows);
  }
}

class Accepted extends PolicyAcceptanceController {
  @override
  PolicyAcceptanceState build() => PolicyAcceptanceState(
    actor,
    ref.watch(policyVersionProvider),
    PolicyAcceptancePhase.accepted,
  );
  void requireConsent() => state = PolicyAcceptanceState(
    actor,
    state.version,
    PolicyAcceptancePhase.required,
  );
  void markAccepted() => state = PolicyAcceptanceState(
    actor,
    state.version,
    PolicyAcceptancePhase.accepted,
  );
}

Future<void> tapDestination(WidgetTester tester) async {
  final target = find.byKey(const Key('person-invite-idea-$roomId'));
  await tester.scrollUntilVisible(
    target,
    100,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('person-idea-destinations')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target.hitTestable());
}

void main() {
  test('destination rejects cross-context and extra private projections', () {
    expect(destination().id, roomId);
    for (final row in [
      {...destinationRow(), 'group_id': id(20)},
      {...destinationRow(), 'target_profile_id': id(21)},
      {...destinationRow(), 'preview': 'Must never be returned.'},
      {...destinationRow(), 'admission_id': admission},
      {...destinationRow(), 'visibility': 'public'},
    ]) {
      expect(
        () => DiscussionInviteDestination(row, groupId, id(9)),
        throwsFormatException,
      );
    }
  });

  for (final language in ['en', 'it']) {
    testWidgets(
      '$language narrow enlarged selector uses only C and explicit confirmation',
      (tester) async {
        tester.view.physicalSize = const Size(320, 711);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final destinations = Destinations(), gateway = Gateway();
        gateway.write = (key, intent) async {
          expect(intent, {'p_room_id': roomId, 'p_profile_id': id(9)});
          return receipt();
        };
        final container = ProviderContainer(
          overrides: [
            authSessionProvider.overrideWith(Session.new),
            policyAcceptanceProvider.overrideWith(Accepted.new),
            discussionGatewayProvider.overrideWithValue(gateway),
            discussionInviteDestinationsGatewayProvider.overrideWithValue(
              destinations,
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await gateway.hints.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: app(
              DiscussionPersonInviteAction(groupId: groupId, personId: id(9)),
              locale: Locale(language),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(gateway.keys, isEmpty);
        await tester.tap(find.byKey(const Key('person-invite-to-idea')));
        await tester.pumpAndSettle();
        await tapDestination(tester);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          gateway.keys,
          isEmpty,
          reason: 'Opening/selecting must not invite or join.',
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(gateway.keys, hasLength(1));
        expect(gateway.historyReads, 0);
        expect(gateway.roomReads, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'committed reply loss survives sheet dismissal/remount with the original invite identity',
    (tester) async {
      final destinations = Destinations(), gateway = Gateway();
      final intents = <Map<String, dynamic>>[];
      gateway.write = (key, intent) async {
        intents.add({...intent});
        destinations.rows =
            []; // The committed pending invitation is no longer a destination.
        if (intents.length == 1) {
          throw const SocketException('Lost committed invitation reply.');
        }
        return receipt();
      };
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          policyAcceptanceProvider.overrideWith(Accepted.new),
          discussionGatewayProvider.overrideWithValue(gateway),
          discussionInviteDestinationsGatewayProvider.overrideWithValue(
            destinations,
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await gateway.hints.close();
      });
      Future<void> mount(int version) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(
            DiscussionPersonInviteAction(
              key: ValueKey(version),
              groupId: groupId,
              personId: id(9),
            ),
          ),
        ),
      );
      await mount(1);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('person-invite-to-idea')));
      await tester.pumpAndSettle();
      await tapDestination(tester);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.keys, hasLength(1));
      expect(
        container
            .read(discussionCommandsProvider)
            .attempts
            .values
            .single
            .uncertain,
        true,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await mount(2);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('person-invite-to-idea')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('person-invite-idea-$roomId')), findsNothing);
      await tester.tap(find.byKey(const Key('person-invite-recover-$roomId')));
      await tester.pumpAndSettle();
      expect(gateway.keys, hasLength(2));
      expect(gateway.keys.last, gateway.keys.first);
      expect(intents, [
        {'p_room_id': roomId, 'p_profile_id': id(9)},
        {'p_room_id': roomId, 'p_profile_id': id(9)},
      ]);
      expect(container.read(discussionCommandsProvider).attempts, isEmpty);
      expect(gateway.historyReads, 0);
      expect(gateway.roomReads, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'removed recovery attempt cannot create a fresh UUID after policy navigation',
    (tester) async {
      final destinations = Destinations()..rows = [], gateway = Gateway();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          policyAcceptanceProvider.overrideWith(Accepted.new),
          discussionGatewayProvider.overrideWithValue(gateway),
          discussionInviteDestinationsGatewayProvider.overrideWithValue(
            destinations,
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await gateway.hints.close();
      });
      final commands = container.read(discussionCommandsProvider);
      final slot = discussionInviteSlot(actor, groupId, roomId, id(9));
      final original = DiscussionAttempt(actor, DiscussionAction.invite, {
        'p_room_id': roomId,
        'p_profile_id': id(9),
      })..error = const SocketException('Lost reply');
      commands.attempts[slot] = original;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(
            DiscussionPersonInviteAction(groupId: groupId, personId: id(9)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('person-invite-to-idea')));
      await tester.pumpAndSettle();
      (container.read(policyAcceptanceProvider.notifier) as Accepted)
          .requireConsent();
      await tester.tap(find.byKey(const Key('person-invite-recover-$roomId')));
      await tester.pumpAndSettle();
      commands.clearProtected(); // The actual same-account phase invalidator.
      expect(original.cancelled, true);
      (container.read(policyAcceptanceProvider.notifier) as Accepted)
          .markAccepted();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(gateway.keys, isEmpty);
      expect(commands.attempts, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'canonical denial then Cancel cannot restore a cached destination',
    (tester) async {
      final destinations = Destinations(), gateway = Gateway();
      gateway.write = (_, _) async {
        destinations.failure = const PostgrestException(
          message: 'Unavailable',
          code: '42501',
        );
        throw destinations.failure!;
      };
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          policyAcceptanceProvider.overrideWith(Accepted.new),
          discussionGatewayProvider.overrideWithValue(gateway),
          discussionInviteDestinationsGatewayProvider.overrideWithValue(
            destinations,
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await gateway.hints.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(
            DiscussionPersonInviteAction(groupId: groupId, personId: id(9)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('person-invite-to-idea')));
      await tester.pumpAndSettle();
      await tapDestination(tester);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic invitation destination'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic invitation destination'), findsNothing);
      expect(find.byKey(const Key('person-invite-idea-$roomId')), findsNothing);
      expect(gateway.keys, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'composition invalidation refreshes both Block and Unblock without remounting',
    (tester) async {
      final destinations = Destinations(), gateway = Gateway();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          discussionGatewayProvider.overrideWithValue(gateway),
          discussionInviteDestinationsGatewayProvider.overrideWithValue(
            destinations,
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await gateway.hints.close();
      });
      Future<void> mount(int revision) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(
            DiscussionPersonInviteAction(
              groupId: groupId,
              personId: id(9),
              eligibilityRevision: revision,
            ),
          ),
        ),
      );
      await mount(0);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('person-invite-to-idea')), findsOneWidget);
      destinations.failure = const PostgrestException(
        message: 'Unavailable',
        code: '42501',
      );
      await mount(1);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('person-invite-to-idea')), findsNothing);
      destinations.failure = null;
      await mount(2);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('person-invite-to-idea')), findsOneWidget);
      expect(destinations.actors.length, 3);
      expect(gateway.keys, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a deferred receipt stays in its original person context', (
    tester,
  ) async {
    final destinations = Destinations(), gateway = Gateway();
    final held = Completer<DiscussionReceipt>();
    gateway.write = (_, _) => held.future;
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(Session.new),
        policyAcceptanceProvider.overrideWith(Accepted.new),
        discussionGatewayProvider.overrideWithValue(gateway),
        discussionInviteDestinationsGatewayProvider.overrideWithValue(
          destinations,
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await gateway.hints.close();
    });
    Future<void> mount(String person) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: app(
          DiscussionPersonInviteAction(groupId: groupId, personId: person),
        ),
      ),
    );
    await mount(id(9));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('person-invite-to-idea')));
    await tester.pumpAndSettle();
    await tapDestination(tester);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    expect(gateway.keys, hasLength(1));
    destinations.expectedPerson = id(10);
    destinations.rows = [];
    await mount(id(10));
    held.complete(receipt());
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(
      container
          .read(discussionCommandsProvider)
          .attempts[discussionInviteSlot(actor, groupId, roomId, id(9))]
          ?.receipt,
      isNotNull,
    );
    expect(gateway.keys, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final connected in [true, false]) {
    testWidgets(
      'C signal $connected clears destinations before a delayed response and account switch',
      (tester) async {
        final destinations = Destinations(), gateway = Gateway();
        final container = ProviderContainer(
          overrides: [
            authSessionProvider.overrideWith(Session.new),
            discussionGatewayProvider.overrideWithValue(gateway),
            discussionInviteDestinationsGatewayProvider.overrideWithValue(
              destinations,
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await gateway.hints.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: app(
              DiscussionPersonInviteAction(groupId: groupId, personId: id(9)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('person-invite-to-idea')));
        await tester.pumpAndSettle();
        expect(find.text('Synthetic invitation destination'), findsOneWidget);
        destinations.held = Completer();
        gateway.hints.add(connected);
        await tester.pump();
        await tester.pump();
        expect(find.text('Synthetic invitation destination'), findsNothing);
        await tester.pump(const Duration(milliseconds: 250));
        (container.read(authSessionProvider.notifier) as Session).change(
          id(22),
        );
        await tester.pump();
        destinations.held!.complete([destination()]);
        await tester.pumpAndSettle();
        expect(find.text('Synthetic invitation destination'), findsNothing);
        expect(destinations.actors.toSet(), {actor});
        expect(gateway.keys, isEmpty);
        expect(gateway.historyReads, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
