import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_hint_store.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_general_hint.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_discussion_hints.dart';
import 'discussion_test_support.dart' show Session, actor, groupId;

Future<ProviderContainer> pumpHint(
  WidgetTester tester,
  DiscussionHintStore store,
  String language, {
  VoidCallback? onOpen,
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(Session.new),
      discussionHintStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            final identity = ref.watch(authSessionProvider).identity?.id;
            return Scaffold(
              body: SingleChildScrollView(
                child: identity == null
                    ? const SizedBox.shrink()
                    : DiscussionGeneralHint(actor: identity, onOpen: onOpen),
              ),
            );
          },
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

void main() {
  for (final language in ['en', 'it']) {
    testWidgets('$language dismissal survives remount and is account-scoped', (
      tester,
    ) async {
      final store = FakeDiscussionHintStore();
      var opens = 0;
      await pumpHint(tester, store, language, onOpen: () => opens++);
      final dismiss = find.byKey(const Key('discussion-general-hint-dismiss'));
      expect(dismiss, findsOneWidget);
      await tester.tap(dismiss);
      await tester.pumpAndSettle();
      expect(dismiss, findsNothing);
      expect(store.saved[actor], true);
      await tester.tap(find.byKey(const Key('discussion-general-workspace')));
      expect(opens, 1, reason: 'Dismissing never removes the workspace entry.');
      await tester.pumpWidget(const SizedBox.shrink());
      final container = await pumpHint(tester, store, language);
      expect(dismiss, findsNothing);
      (container.read(authSessionProvider.notifier) as Session).change(groupId);
      await tester.pumpAndSettle();
      expect(dismiss, findsOneWidget);
      (container.read(authSessionProvider.notifier) as Session).change(actor);
      await tester.pumpAndSettle();
      expect(dismiss, findsNothing);
      expect(store.writes, [actor]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$language failed read/write stay explicit and retryable', (
      tester,
    ) async {
      final store = FakeDiscussionHintStore()..failRead = true;
      await pumpHint(tester, store, language);
      final context = tester.element(find.byType(DiscussionGeneralHint));
      final l = AppLocalizations.of(context);
      expect(find.text(l.discussionGeneralHintLoadFailed), findsOneWidget);
      expect(
        find.byKey(const Key('discussion-general-hint-dismiss')),
        findsOneWidget,
      );
      store.failRead = false;
      await tester.tap(find.text(l.discussionRetry));
      await tester.pumpAndSettle();
      expect(find.text(l.discussionGeneralHintLoadFailed), findsNothing);
      store.failWrite = true;
      await tester.tap(
        find.byKey(const Key('discussion-general-hint-dismiss')),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.discussionGeneralHintSaveFailed), findsOneWidget);
      expect(store.saved[actor], isNull);
      store.failWrite = false;
      await tester.tap(find.text(l.discussionRetry));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('discussion-general-hint-dismiss')),
        findsNothing,
      );
      expect(store.saved[actor], true);
      expect(store.writes, [actor, actor]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('late old-account restore cannot hide a new-account hint', (
    tester,
  ) async {
    final store = _DelayedHintStore();
    final container = await pumpHint(tester, store, 'en', settle: false);
    (container.read(authSessionProvider.notifier) as Session).change(groupId);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('discussion-general-hint-dismiss')),
      findsOneWidget,
    );
    store.previous.complete(true);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('discussion-general-hint-dismiss')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _DelayedHintStore implements DiscussionHintStore {
  final previous = Completer<bool>();
  @override
  Future<bool> dismissed(String id) =>
      id == actor ? previous.future : Future.value(false);
  @override
  Future<void> dismiss(String actor) async {}
}
