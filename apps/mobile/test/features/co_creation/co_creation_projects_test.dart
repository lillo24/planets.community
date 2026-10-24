import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';
import 'package:planets_mobile/features/group_projects/domain/group_project_creation_return.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_creation_choice.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import 'co_creation_hubs_flow_test.dart' as f;

void main() {
  for (final language in ['en', 'it']) {
    testWidgets(
      'General starts ordinary native creation and returns $language',
      (tester) async {
        final fixture = f.Fixture()
          ..active.add(f.b)
          ..ever.add(f.b);
        final source = coGeneralRoute(
          HubId.parse(f.hub),
          CoRoomId.parse(f.room),
          CoEpisodeId.parse(f.episode(f.b)),
        );
        final (app, router) = await f.pump(
          tester,
          fixture,
          path: source,
          language: language,
          extraRoutes: [
            GoRoute(
              path: '/proposals/create',
              builder: (_, _) => const ProposalCreationChoice(),
            ),
            GoRoute(
              path: '/proposals/create/scratch',
              builder: (context, state) => Scaffold(
                body: TextButton(
                  onPressed: () => context.go(
                    (state.extra! as GroupProjectCreationReturn).returnPath!,
                  ),
                  child: const Text('Acknowledged native save'),
                ),
              ),
            ),
          ],
        );
        (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
        await tester.pumpAndSettle();
        await f.tap(tester, find.byKey(const Key('co-native-project')));
        expect(find.byType(ProposalCreationChoice), findsOneWidget);
        final l = AppLocalizations.of(
          tester.element(find.byType(ProposalCreationChoice)),
        );
        expect(find.text(l.proposalFromTemplate), findsOneWidget);
        final marker =
            router.routerDelegate.state.extra! as GroupProjectCreationReturn;
        expect(marker.actor, f.b);
        expect(marker.returnPath, source);
        expect(router.routerDelegate.state.uri.hasQuery, isFalse);
        await f.tap(tester, find.byKey(const Key('proposal-start-scratch')));
        expect(router.routerDelegate.state.extra, same(marker));
        expect(fixture.calls, isNot(contains('create_cocreate_project_draft')));
        expect(fixture.commands, isEmpty);
        await f.tap(tester, find.text('Acknowledged native save'));
        expect(router.routerDelegate.state.uri.path, source);
        expect(fixture.active, {f.b});
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('closed General cannot offer a current-room creation action', (
    tester,
  ) async {
    final fixture = f.Fixture()..ever.add(f.b);
    final (app, _) = await f.pump(
      tester,
      fixture,
      path: coGeneralRoute(
        HubId.parse(f.hub),
        CoRoomId.parse(f.room),
        CoEpisodeId.parse(f.episode(f.b)),
      ),
    );
    (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('co-native-project')), findsNothing);
    expect(find.text('Synthetic General history'), findsOneWidget);
  });
}
