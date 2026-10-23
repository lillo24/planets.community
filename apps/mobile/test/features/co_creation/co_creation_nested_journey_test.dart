import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_hubs_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/rendered_evidence.dart';
import 'co_creation_hubs_flow_test.dart' as f;
import 'co_creation_numbered_test.dart' as n;

class NestedFixture extends n.NumberedFixture {
  final directoryQueries = <Map<String, dynamic>>[];
  @override
  Map<String, Object?> publicHub() => {
    ...super.publicHub(),
    'topic_label': 'Valorant',
  };

  Map<String, Object?> group() => {
    ...n.summary(),
    'capacity': 3,
    'occupied': joined ? 3 : 2,
    'available': !joined,
  };

  @override
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'list_cocreate_categories':
        return [
          {
            'category_id': 'videogames',
            'label_en': 'Video games',
            'label_it': 'Videogiochi',
            'icon': 'games',
            'sort_order': 10,
          },
        ];
      case 'list_cocreate_communities':
        directoryQueries.add(Map.of(args));
        return [
          {
            'category_id': 'videogames',
            'kind': 'hub',
            'hub': publicHub(),
            'proposal': null,
          },
        ];
      case 'list_cocreate_numbered_groups':
        return [group()];
      case 'get_cocreate_numbered_group':
        return group();
      case 'get_cocreate_current_meeting':
        return null;
    }
    final result = await super.rpc(name, args);
    if (name == 'get_cocreate_general_context' ||
        name == 'get_cocreate_numbered_context') {
      return {
        ...result as Map<String, dynamic>,
        'topic_label': 'Valorant',
        if (name == 'get_cocreate_numbered_context') ...{
          'capacity': 3,
          'occupied': joined ? 3 : 2,
        },
      };
    }
    if (name == 'mutate_cocreate_numbered_group') {
      return {...result as Map<String, dynamic>, 'capacity': 3};
    }
    return result;
  }
}

void main() {
  setUpAll(() => RenderedEvidence.loadFonts(force: true));
  for (final language in ['en', 'it']) {
    testWidgets(
      'active category to General and separate 2/3 group $language at 320dp 2x',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = NestedFixture();
        final (app, router) = await f.pump(
          tester,
          fixture,
          path: '/people/hubs',
          language: language,
          dark: language == 'it',
          large: true,
          extraRoutes: n.routes(),
        );
        (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(CoCreationHubsScreen)),
        );
        await tester.enterText(find.byType(TextField).at(1), 'Trento');
        await f.tap(
          tester,
          find.widgetWithText(FilledButton, l.coPeopleSearch),
        );
        await f.tap(
          tester,
          find.text(language == 'it' ? 'Videogiochi' : 'Video games'),
        );
        expect(fixture.directoryQueries.last['p_locality'], 'Trento');
        await tester.ensureVisible(find.text('Valorant'));
        await tester.pumpAndSettle();
        await RenderedEvidence.capture(tester, 'active-directory-$language-2x');
        await f.tap(tester, find.text('Valorant'));
        expect(fixture.calls, isNot(contains('get_cocreate_room_page_v3')));
        expect(find.text(l.coCommunityMembers(2, 3)), findsOneWidget);
        await tester.ensureVisible(find.text(l.coCommunityMembers(2, 3)));
        await tester.pumpAndSettle();
        await RenderedEvidence.capture(tester, 'active-hub-$language-2x');
        await f.tap(tester, find.widgetWithText(FilledButton, l.coRoomsJoin));
        expect(fixture.active, contains(f.b));
        expect(
          fixture.joined,
          isFalse,
          reason: 'General admission never joins its children',
        );
        await f.tap(tester, find.text(l.coRoomsOpenGeneral));
        expect(find.text('Synthetic General history'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        await f.tap(tester, find.text(l.coGroupsNumber(2)));
        expect(
          fixture.joined,
          isFalse,
          reason: 'numbered detail is only a preview',
        );
        await f.tap(tester, find.widgetWithText(FilledButton, l.coGroupsJoin));
        expect(fixture.joined, isTrue);
        expect(find.text('3/3'), findsOneWidget);
        await f.tap(tester, find.text(l.coGroupsOpen));
        expect(
          router.routerDelegate.state.uri.path,
          contains('/groups/${n.room}/${n.ep}'),
        );
        expect(fixture.calls, contains('get_cocreate_numbered_context'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
