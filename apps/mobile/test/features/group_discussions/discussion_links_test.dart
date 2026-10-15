import 'dart:async';

import '../../support/fake_group_discussions.dart';

import 'package:planets_mobile/features/group_discussions/data/discussion_conversion_gateway.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/application/discussion_links_controller.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_links_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_links.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_link_open.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_link_editor.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_links_screen.dart';
import 'package:planets_mobile/features/project_workspace/application/project_workspace_launcher.dart';
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'discussion_test_support.dart';

Map<String, dynamic> linkRow(
  int n, {
  String url = 'https://example.invalid/doc',
}) => {
  'profile_id': actor,
  'room_id': roomId,
  'admission_id': admission,
  'link_id': id(n),
  'name': 'Documento $n',
  'url': url,
  'version': 1,
  'created_at': '2026-10-14T10:00:00Z',
  'updated_at': '2026-10-14T10:00:00Z',
};
DiscussionLink link(int n, {String url = 'https://example.invalid/doc'}) =>
    DiscussionLink(
      linkRow(n, url: url),
      actor: actor,
      room: roomId,
      admission: admission,
    );
DiscussionLinkPage linkPage(List<int> numbers, {bool manager = false}) =>
    DiscussionLinkPage(
      {
        'profile_id': actor,
        'room_id': roomId,
        'admission_id': admission,
        'archived': false,
        'can_manage': manager,
        'items': numbers.map(linkRow).toList(),
      },
      actor: actor,
      room: roomId,
    );

class Links implements DiscussionLinksGateway {
  int reads = 0, exactReads = 0;
  final cursors = <Map<String, dynamic>?>[];
  Future<DiscussionLinkPage> Function()? fetch;
  Future<DiscussionLink> Function()? fresh;
  DiscussionLinkPage result = linkPage([9]);
  @override
  Future<DiscussionLinkPage> page(
    String a,
    String r,
    String? episode,
    Map<String, dynamic>? cursor,
  ) async {
    reads++;
    cursors.add(cursor);
    return fetch == null ? result : await fetch!();
  }

  @override
  Future<DiscussionLink> exact(
    String a,
    String r,
    String episode,
    String item,
  ) async {
    expect([a, r, episode, item], [actor, roomId, admission, id(9)]);
    exactReads++;
    return fresh == null ? link(9) : await fresh!();
  }
}

class Launcher implements ProjectWorkspaceLauncher {
  final urls = <String>[];
  @override
  Future<bool> open(ProjectWorkspaceUrl value) async {
    urls.add(value.value);
    return true;
  }
}

Widget app(Widget home, {String locale = 'en'}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: child!,
  ),
  home: home,
);

void main() {
  testWidgets('revoked editor clears its fields and closes only the dialog', (
    tester,
  ) async {
    final g = Links()..result = linkPage([9], manager: true),
        c = DiscussionLinksController(g, actor, roomId, () => true),
        rooms = Gateway();
    await c.pager.load();
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(Session.new),
        discussionGatewayProvider.overrideWithValue(rooms),
      ],
    );
    addTearDown(() async {
      container.dispose();
      c.dispose();
      await rooms.hints.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      DiscussionLinkEditor(controller: c, link: link(9)),
                ),
                child: const Text('Edit link'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit link'));
    await tester.pumpAndSettle();
    expect(find.text('Documento 9'), findsOneWidget);
    g.result = linkPage([9]);
    await c.pager.refresh();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Edit link'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'account loss during fresh exact reread cannot launch cached destination',
    (tester) async {
      final g = Links(),
          c = DiscussionLinksController(g, actor, roomId, () => true),
          held = Completer<DiscussionLink>(),
          launcher = Launcher();
      await c.pager.load();
      g.fresh = () => held.future;
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          projectWorkspaceLauncherProvider.overrideWithValue(launcher),
        ],
      );
      addTearDown(() {
        container.dispose();
        c.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(
            Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () =>
                      confirmAndOpenDiscussionLink(context, ref, c, link(9)),
                  child: const Text('Open link'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open link'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discussion-link-confirm-open')));
      await tester.pumpAndSettle();
      expect(g.exactReads, 1);
      (container.read(authSessionProvider.notifier) as Session).change(id(7));
      held.complete(link(9));
      await tester.pumpAndSettle();
      expect(launcher.urls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  test('strict collection binds actor, room, episode and descending immutable cursor', () {
    final good = linkRow(9);
    for (final change in [
      {'profile_id': id(8)},
      {'room_id': id(8)},
      {'admission_id': id(8)},
      {'extra': 'private'},
      {'version': 0},
      {'url': 'http://example.invalid'},
      {'name': 'line\nbreak'},
    ]) {
      expect(
        () => DiscussionLink(
          {...good, ...change},
          actor: actor,
          room: roomId,
          admission: admission,
        ),
        throwsA(isA<Exception>()),
      );
    }
    expect(() => linkPage([8, 9]), throwsFormatException);
    expect(
      () => linkPage(List.generate(26, (i) => 30 - i)),
      throwsFormatException,
    );
    expect(linkPage([9, 8]).items.map((l) => l.id), [id(9), id(8)]);
  });
  test('failed next page preserves rows/cursor; denial clears destinations and episode', () async {
    final g = Links()..result = linkPage(List.generate(25, (i) => 40 - i)),
        c = DiscussionLinksController(g, actor, roomId, () => true);
    addTearDown(c.dispose);
    expect(g.reads, 0);
    await c.pager.load();
    final cursor = c.pager.rows.last.cursor;
    g.fetch = () => Future.error(const SocketException('Failed read'));
    await c.pager.load();
    expect(c.pager.rows.length, 25);
    expect(c.pager.error, isNotNull);
    expect(g.cursors.last, cursor);
    g.fetch = () => Future.error(
      const PostgrestException(message: 'Unavailable', code: '42501'),
    );
    await c.pager.refresh();
    expect(c.pager.rows, isEmpty);
    expect(c.admission, isNull);
    expect(c.current(admission, 0), false);
  });
  test(
    'old response cannot reintroduce URLs after invalidation or account loss',
    () async {
      final g = Links(), held = Completer<DiscussionLinkPage>();
      var authorized = true;
      g.fetch = () => held.future;
      final c = DiscussionLinksController(g, actor, roomId, () => authorized);
      addTearDown(c.dispose);
      final loading = c.pager.load();
      authorized = false;
      held.complete(linkPage([9]));
      await loading;
      expect(c.pager.rows, isEmpty);
      expect(c.admission, isNull);
    },
  );
  for (final lang in ['en', 'it']) {
    testWidgets('$lang reader collection is lazy and fits 320px / 2x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final g = Links(), rooms = Gateway();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          discussionGatewayProvider.overrideWithValue(rooms),
          discussionLinksGatewayProvider.overrideWithValue(g),
          discussionConversionGatewayProvider.overrideWithValue(
            emptyDiscussionConversionGateway(),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await rooms.hints.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(const DiscussionLinksScreen(roomId: roomId), locale: lang),
        ),
      );
      await tester.pumpAndSettle();
      expect(g.reads, 1);
      expect(rooms.historyReads, 0);
      // The revised current-audience disclosure can fill the narrow 2x first
      // viewport. Scrolling must reveal the same already-loaded collection.
      await tester.scrollUntilVisible(find.text('Documento 9'), 100);
      expect(find.text('Documento 9'), findsOneWidget);
      expect(find.byKey(const Key('discussion-link-add')), findsNothing);
      expect(tester.takeException(), isNull);
      (container.read(authSessionProvider.notifier) as Session).change(id(7));
      await tester.pumpAndSettle();
      // Old actor response is never retained in the new account's provider.
      expect(container.read(discussionLinksProvider(roomId))!.actor, id(7));
    });
  }
  testWidgets('failed read is not the confirmed empty collection', (
    tester,
  ) async {
    final g = Links()
          ..fetch = () => Future.error(const SocketException('Read failed')),
        rooms = Gateway();
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(Session.new),
        discussionGatewayProvider.overrideWithValue(rooms),
        discussionLinksGatewayProvider.overrideWithValue(g),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await rooms.hints.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: app(const DiscussionLinksScreen(roomId: roomId)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No links are available since your admission.'),
      findsNothing,
    );
    expect(find.text('Retry'), findsWidgets);
  });
  for (final cancel in [false, true]) {
    testWidgets(
      'destination change reconfirms; revocation=$cancel cancels pending launch',
      (tester) async {
        final g = Links(),
            launcher = Launcher(),
            rooms = Gateway(),
            c = DiscussionLinksController(g, actor, roomId, () => true);
        await c.pager.load();
        final container = ProviderContainer(
          overrides: [
            authSessionProvider.overrideWith(Session.new),
            projectWorkspaceLauncherProvider.overrideWithValue(launcher),
          ],
        );
        addTearDown(() async {
          container.dispose();
          c.dispose();
          await rooms.hints.close();
        });
        var reads = 0;
        g.fresh = () async {
          reads++;
          return link(9, url: 'https://changed.invalid/doc');
        };
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: app(
              Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () =>
                        confirmAndOpenDiscussionLink(context, ref, c, link(9)),
                    child: const Text('Open link'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open link'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('discussion-link-confirm-open')));
        await tester.pumpAndSettle();
        expect(reads, 1);
        expect(launcher.urls, isEmpty);
        expect(find.textContaining('changed.invalid'), findsOneWidget);
        if (cancel) {
          (container.read(authSessionProvider.notifier) as Session).change(
            id(7),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('discussion-link-confirm-open')),
            findsNothing,
          );
        } else {
          await tester.tap(
            find.byKey(const Key('discussion-link-confirm-open')),
          );
          await tester.pumpAndSettle();
          expect(reads, 2);
          expect(launcher.urls, ['https://changed.invalid/doc']);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
