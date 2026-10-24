import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/messages/presentation/inbox_content.dart';

void main() {
  testWidgets('empty requires every mounted source to settle successfully', (
    tester,
  ) async {
    final states = ValueNotifier([
      InboxContent.empty, // Native conversations.
      InboxContent.pending, // Delayed People response.
      InboxContent.inapplicable, // Disabled source.
    ]);
    addTearDown(states.dispose);
    await tester.pumpWidget(_inbox(states));
    await tester.pump();
    expect(find.text('All empty'), findsNothing);
    for (final result in [
      InboxContent.present,
      InboxContent.failure,
      InboxContent.pending, // Retry is still not an empty result.
      InboxContent.empty,
    ]) {
      states.value = [InboxContent.empty, result, InboxContent.inapplicable];
      await tester.pump();
      await tester.pump();
      expect(
        find.text('All empty'),
        result == InboxContent.empty ? findsOneWidget : findsNothing,
      );
    }
    states.value = [InboxContent.present, InboxContent.empty];
    await tester.pump();
    await tester.pump();
    expect(find.text('All empty'), findsNothing);
  });

  testWidgets(
    'a discussion or recovery item alone suppresses the global claim',
    (tester) async {
      final states = ValueNotifier([
        InboxContent.empty,
        InboxContent.inapplicable,
        InboxContent.present,
      ]);
      addTearDown(states.dispose);
      await tester.pumpWidget(_inbox(states));
      await tester.pump();
      expect(find.text('All empty'), findsNothing);
      // Ending the last own-exit relationship legitimately empties this scope.
      states.value = [InboxContent.empty, InboxContent.inapplicable];
      await tester.pump();
      await tester.pump();
      expect(find.text('All empty'), findsOneWidget);
    },
  );

  testWidgets(
    'actor, realm and selected scope discard previous empty results',
    (tester) async {
      final states = ValueNotifier([InboxContent.empty]);
      addTearDown(states.dispose);
      await tester.pumpWidget(
        _inbox(states, identity: ('a', 'mock', 'private')),
      );
      await tester.pump();
      expect(find.text('All empty'), findsOneWidget);
      for (final identity in [
        ('b', 'mock', 'private'),
        ('b', 'normal', 'private'),
        ('b', 'normal', 'groups'),
        ('b', 'normal', 'requests'),
      ]) {
        states.value = [InboxContent.pending];
        await tester.pumpWidget(_inbox(states, identity: identity));
        expect(find.text('All empty'), findsNothing);
        await tester.pump();
        states.value = [InboxContent.empty];
        await tester.pump();
        await tester.pump();
        expect(find.text('All empty'), findsOneWidget);
      }
    },
  );

  testWidgets('refresh calls the existing mounted owners exactly once', (
    tester,
  ) async {
    var peopleRefresh = 0, discussionRefresh = 0;
    final states = ValueNotifier([InboxContent.empty]);
    addTearDown(states.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: InboxContentScope(
          child: Builder(
            builder: (context) => Column(
              children: [
                InboxSource(
                  content: InboxContent.empty,
                  onRefresh: () async => peopleRefresh++,
                  child: const Text('People'),
                ),
                InboxSource(
                  content: InboxContent.empty,
                  onRefresh: () async => discussionRefresh++,
                  child: const Text('Discussions'),
                ),
                TextButton(
                  onPressed: () => InboxContentScope.refresh(context),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    expect((peopleRefresh, discussionRefresh), (1, 1));
  });
}

Widget _inbox(
  ValueNotifier<List<InboxContent>> states, {
  Object identity = 'actor/realm/scope',
}) => MaterialApp(
  home: InboxContentScope(
    key: ValueKey(identity),
    child: ValueListenableBuilder(
      valueListenable: states,
      builder: (context, values, _) => Column(
        children: [
          for (var index = 0; index < values.length; index++)
            InboxSource(
              key: ValueKey(index),
              content: values[index],
              child: const SizedBox.shrink(),
            ),
          const InboxEmpty(child: Text('All empty')),
        ],
      ),
    ),
  ),
);
