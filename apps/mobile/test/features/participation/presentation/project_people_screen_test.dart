import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';
import 'package:planets_mobile/features/participation/application/project_people_controller.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/data/project_people_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/participation/domain/project_capacity.dart';
import 'package:planets_mobile/features/participation/domain/project_people_models.dart';
import 'package:planets_mobile/features/participation/presentation/creator_participation_screen.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_blocking.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_profile_photo.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_project_people.dart';

const _creator = ProjectPerson(
  profileId: 'user-1',
  displayName: 'Casey',
  isCreator: true,
  roleRank: 0,
);
const _member = ProjectPerson(
  profileId: 'user-2',
  displayName: 'Alessandra Maria Rossi with a very long display name',
  isCreator: false,
  roleRank: 1,
  authorityRole: ProjectDelegatedAuthorityRole.coCreator,
  delegateId: 'delegate',
  membershipId: 'membership',
);
ProjectRoleOffer _offer(int index, {String target = 'user-2'}) =>
    ProjectRoleOffer(
      id: 'offer-$index',
      targetProfileId: target,
      targetDisplayName: 'Jordan',
      issuerProfileId: 'user-1',
      issuerDisplayName: 'Casey',
      role: ProjectDelegatedAuthorityRole.coCreator,
      createdAt: DateTime.utc(2026, 10, 11),
      expiresAt: DateTime.utc(2026, 10, 18),
      membershipId: 'membership',
    );

void main() {
  setUpAll(() async {
    const captures = String.fromEnvironment('PEOPLE_UI_CAPTURE_DIR');
    if (captures.isEmpty) return;
    const fonts = String.fromEnvironment('PEOPLE_UI_FONT_DIR');
    if (fonts.isEmpty) {
      throw ArgumentError(
        'PEOPLE_UI_FONT_DIR must point to Flutter material_fonts for readable captures.',
      );
    }
    final loader = FontLoader('Roboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      loader.addFont(
        File('$fonts/roboto-$weight.ttf')
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    }
    await loader.load();
    await (FontLoader('MaterialIcons')..addFont(
          File('$fonts/materialicons-regular.otf')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
  });
  for (final language in ['en', 'it']) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        for (final populated in [false, true]) {
          final scenario =
              '$language-${dark ? "dark" : "light"}-${scale}x-${populated ? "populated" : "empty"}';
          testWidgets('320dp $scenario stays readable and preserves sections', (
            tester,
          ) async {
            final gateway = FakeProjectPeopleGateway()
              ..rows = [
                _creator,
                if (populated) ...[
                  _member,
                  const ProjectPerson(
                    profileId: 'user-3',
                    displayName: 'Jordan',
                    isCreator: false,
                    roleRank: 3,
                    membershipId: 'ordinary-membership',
                  ),
                ],
              ];
            if (populated) {
              gateway.requestRows = [
                creatorJoinRequestFixture(
                  requesterProfileId: 'user-4',
                  requesterDisplayName:
                      'Francesca Maria with a very long display name',
                ),
              ];
              gateway.offerRows = [_offer(1, target: 'user-3')];
              gateway.historyRows = [
                creatorMemberFixture(status: MembershipStatus.left),
              ];
            }
            await _pump(
              tester,
              gateway: gateway,
              language: language,
              scale: scale,
              dark: dark,
              capacity: ProjectCapacitySnapshot.fromRow({
                'registration_capacity': 5,
                'count_organizers_toward_capacity': false,
                'current_participant_count': populated ? 2 : 0,
                'ordinary_participant_count': populated ? 1 : 0,
                'organizer_count': populated ? 2 : 1,
                'capacity_used_count': populated ? 1 : 0,
                'social_people_count': populated ? 3 : 1,
                'spots_remaining': populated ? 4 : 5,
                'is_full': false,
              }),
            );
            expect(find.byKey(const Key('page-close')), findsOneWidget);
            expect(
              find.descendant(
                of: find.byType(AppBar),
                matching: find.byKey(const Key('participant-links-manage')),
              ),
              findsNothing,
            );
            expect(
              find.text(
                language == 'it'
                    ? '${populated ? 1 : 0} / 5 posti utilizzati'
                    : '${populated ? 1 : 0} / 5 spots used',
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                language == 'it'
                    ? (populated
                          ? '4 posti disponibili · 2 organizzatori'
                          : '5 posti disponibili · 1 organizzatore')
                    : (populated
                          ? '4 spots remaining · 2 organizers'
                          : '5 spots remaining · 1 organizer'),
              ),
              findsOneWidget,
            );
            expect(
              find.textContaining(
                language == 'it'
                    ? 'Partecipando, il tuo nome'
                    : 'Your display name is visible',
              ),
              findsNothing,
            );
            await _capture(tester, scenario);
            if (!populated) {
              expect(
                find.text(language == 'it' ? 'Richieste (0)' : 'Requests (0)'),
                findsOneWidget,
              );
              expect(
                find.text(
                  language == 'it' ? 'Inviti di ruolo (0)' : 'Role offers (0)',
                ),
                findsOneWidget,
              );
              expect(
                find.textContaining(
                  language == 'it'
                      ? 'Partecipanti precedenti'
                      : 'Past participants',
                ),
                findsNothing,
              );
              expect(
                find.byKey(const Key('people-actions-user-1')),
                findsNothing,
              );
            } else {
              await _scrollTo(
                tester,
                find.byKey(const Key('people-person-user-2')),
              );
              expect(
                find.text(
                  language == 'it'
                      ? 'Co-creatore · Partecipante'
                      : 'Co-creator · Participant',
                ),
                findsOneWidget,
              );
              expect(
                find.byKey(const Key('people-actions-user-2')),
                findsOneWidget,
              );
              await _capture(tester, '$scenario-roster');
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }

  testWidgets(
    'section counts are semantic headings and roster menus support keyboard activation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(
          tester,
          gateway: FakeProjectPeopleGateway()..rows = [_creator, _member],
        );
        expect(
          tester.getSemantics(find.text('Requests (0)')),
          matchesSemantics(label: 'Requests (0)', isHeader: true),
        );
        expect(
          tester.getSemantics(find.byKey(const Key('page-close'))).label,
          'Close',
        );
        final menu = find.byKey(const Key('people-actions-user-2'));
        await _scrollTo(tester, menu);
        expect(tester.getSize(menu).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
        for (var attempt = 0; attempt < 10; attempt++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          if (FocusManager.instance.primaryFocus?.context
                  ?.findAncestorWidgetOfExactType<IconButton>()
                  ?.key ==
              const Key('people-actions-user-2')) {
            break;
          }
        }
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<IconButton>()
              ?.key,
          const Key('people-actions-user-2'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('people-safety-section')), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final included in [false, true]) {
    testWidgets(
      'organizer/member overlap uses canonical usage, included=$included',
      (tester) async {
        final capacity = ProjectCapacitySnapshot.fromRow({
          'registration_capacity': 5,
          'count_organizers_toward_capacity': included,
          'current_participant_count': 2,
          'ordinary_participant_count': 1,
          'organizer_count': 2,
          'capacity_used_count': included ? 3 : 1,
          'social_people_count': 3,
          'spots_remaining': included ? 2 : 4,
          'is_full': false,
        });
        await _pump(tester, capacity: capacity);
        expect(find.text('${included ? 3 : 1} / 5 spots used'), findsOneWidget);
        expect(
          find.text(
            included
                ? '2 spots remaining · 2 organizers included in capacity'
                : '4 spots remaining · 2 organizers',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('current memberships'), findsNothing);
        expect(find.textContaining('unique people'), findsNothing);
      },
    );
  }
  testWidgets(
    'unspecified and full capacity never fabricate or repeat counts',
    (tester) async {
      await _pump(
        tester,
        capacity: capacityFixture(
          registrationCapacity: null,
          currentParticipantCount: 2,
        ),
      );
      expect(find.text('Registration capacity not set'), findsOneWidget);
      expect(find.text('2 participants · 1 organizer'), findsOneWidget);
      expect(find.textContaining('spots remaining'), findsNothing);
      expect(find.textContaining(' / '), findsNothing);
      await _pump(
        tester,
        capacity: capacityFixture(
          registrationCapacity: 5,
          currentParticipantCount: 5,
        ),
      );
      expect(find.text('5 / 5 spots used'), findsOneWidget);
      expect(find.text('Full · 1 organizer'), findsOneWidget);
      expect(find.textContaining('0 spots'), findsNothing);
    },
  );

  for (final role in ProjectManagementRole.values) {
    testWidgets(
      '$role retains Participant Links visibility/navigation for both project kinds',
      (tester) async {
        for (final kind in ProjectKind.values) {
          final app = await _pump(tester, role: role, kind: kind);
          final link = find.byKey(const Key('participant-links-manage'));
          expect(link, role.isManager ? findsOneWidget : findsNothing);
          expect(
            find.text('Requests (0)'),
            role.isManager ? findsOneWidget : findsNothing,
          );
          if (role.isManager) {
            await tester.ensureVisible(link);
            await tester.tap(link);
            await tester.pumpAndSettle();
            expect(find.text('Participant link destination'), findsOneWidget);
          } else {
            expect(app.gateway.calls, ['people:first', 'offers:first']);
            expect(
              find.byKey(const Key('creator-participation-capacity')),
              findsNothing,
            );
          }
        }
      },
    );
  }

  testWidgets('Close honors route guard; refresh reloads canonical state', (
    tester,
  ) async {
    final guard = ValueNotifier(false);
    addTearDown(guard.dispose);
    final app = await _pump(tester, canPop: guard);
    await tester.tap(find.byKey(const Key('page-close')));
    await tester.pumpAndSettle();
    expect(find.byType(CreatorParticipationScreen), findsOneWidget);
    app.gateway.rows = [_creator, _member];
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 350),
      1000,
    );
    await tester.pumpAndSettle();
    expect(app.gateway.calls.where((c) => c == 'people:first').length, 2);
    guard.value = true;
    await tester.pump();
    await tester.tap(find.byKey(const Key('page-close')));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets(
    'only actionable self rows have menus; others retain Block and both triggers',
    (tester) async {
      final app = await _pump(
        tester,
        gateway: FakeProjectPeopleGateway()..rows = [_creator, _member],
      );
      expect(find.byKey(const Key('people-actions-user-1')), findsNothing);
      final other = find.byKey(const Key('people-actions-user-2'));
      await _scrollTo(tester, other);
      await tester.tap(other);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('people-safety-section')), findsOneWidget);
      expect(
        find.byKey(const Key('people-action-revokeAuthority')),
        findsOneWidget,
      );
      app.router.pop();
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const Key('people-person-user-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('people-safety-section')), findsOneWidget);
      app.router.pop();
      await tester.pumpAndSettle();
      await _pump(
        tester,
        viewer: 'user-2',
        role: ProjectManagementRole.coCreator,
        gateway: FakeProjectPeopleGateway()..rows = [_member],
      );
      await tester.tap(find.byKey(const Key('people-actions-user-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('people-action-stepDown')), findsOneWidget);
      expect(find.byKey(const Key('people-safety-section')), findsNothing);
    },
  );

  testWidgets(
    'resolved requests are not pending; recipient and structural offer actions stay distinct',
    (tester) async {
      final gateway = FakeProjectPeopleGateway()
        ..rows = [_creator]
        ..requestRows = [
          creatorJoinRequestFixture(
            id: 'resolved',
            status: JoinRequestStatus.accepted,
          ),
        ]
        ..offerRows = [_offer(1)];
      await _pump(tester, gateway: gateway);
      expect(
        find.byKey(const Key('participation-accept-resolved')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('participation-reject-resolved')),
        findsNothing,
      );
      await _scrollTo(
        tester,
        find.byKey(const Key('people-offer-withdraw-offer-1')),
      );
      expect(
        find.byKey(const Key('people-offer-accept-offer-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('people-offer-decline-offer-1')),
        findsNothing,
      );
      await _pump(
        tester,
        viewer: 'user-2',
        role: ProjectManagementRole.none,
        gateway: gateway,
      );
      expect(
        find.byKey(const Key('participation-request-resolved')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('people-offer-withdraw-offer-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('people-offer-accept-offer-1')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('people-offer-decline-offer-1')));
      await tester.pumpAndSettle();
      expect(gateway.calls, contains('decline:user-2:offer-1'));
    },
  );

  testWidgets(
    'empty failed pages retain error/retry and loading never claims zero',
    (tester) async {
      final gateway = FakeProjectPeopleGateway()..error = StateError('network');
      await _pump(tester, gateway: gateway);
      for (final section in PeopleSection.values) {
        final retry = find.byKey(Key('people-retry-${section.name}'));
        await _scrollTo(tester, retry);
        expect(
          find.byKey(Key('people-page-error-${section.name}')),
          findsOneWidget,
        );
      }
      expect(find.textContaining('(0)'), findsNothing);
      gateway.error = null;
      await tester.tap(find.byKey(const Key('people-retry-history')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Past participants'), findsNothing);
      final pending = Completer<void>();
      gateway.delay = pending.future;
      final load = await _pump(tester, gateway: gateway, settle: false);
      await tester.pump();
      expect(find.textContaining('(0)'), findsNothing);
      pending.complete();
      await tester.pumpAndSettle();
      expect(load.container.read(projectPeopleProvider).loading, isFalse);
    },
  );

  for (final section in PeopleSection.values) {
    testWidgets(
      '$section pagination reports loaded rows, retries and exhausts independently',
      (tester) async {
        final gateway = FakeProjectPeopleGateway()..rows = [_creator];
        switch (section) {
          case PeopleSection.people:
            gateway.rows = List.generate(
              51,
              (i) => ProjectPerson(
                profileId: 'p$i',
                displayName: 'Person $i',
                isCreator: false,
                roleRank: 3,
                membershipId: 'm$i',
              ),
            );
          case PeopleSection.requests:
            gateway.requestRows = List.generate(
              51,
              (i) => creatorJoinRequestFixture(
                id: 'r$i',
                message: null,
                status: JoinRequestStatus.rejected,
              ),
            );
          case PeopleSection.offers:
            gateway.offerRows = List.generate(51, (i) => _offer(i));
          case PeopleSection.history:
            gateway.historyRows = List.generate(
              51,
              (i) => creatorMemberFixture(
                id: 'm$i',
                status: MembershipStatus.left,
              ),
            );
        }
        final app = await _pump(tester, gateway: gateway);
        expect(find.textContaining('50 loaded'), findsOneWidget);
        final more = find.byKey(Key('people-more-${section.name}'));
        await _scrollTo(tester, more);
        gateway.error = StateError('page failure');
        await tester.tap(more);
        await tester.pumpAndSettle();
        final retry = find.byKey(Key('people-retry-${section.name}'));
        await _scrollTo(tester, retry);
        expect(
          find.byKey(Key('people-page-error-${section.name}')),
          findsOneWidget,
        );
        gateway.error = null;
        await tester.tap(retry);
        await tester.pumpAndSettle();
        final state = app.container.read(projectPeopleProvider);
        expect(switch (section) {
          PeopleSection.people => state.people.items.length,
          PeopleSection.requests => state.requests.items.length,
          PeopleSection.offers => state.offers.items.length,
          PeopleSection.history => state.history.items.length,
        }, 51);
        expect(more, findsNothing);
        expect(
          gateway.calls.where((c) => c.startsWith('${section.name}:first')),
          hasLength(1),
        );
      },
    );
  }
}

Future<
  ({
    GoRouter router,
    ProviderContainer container,
    FakeProjectPeopleGateway gateway,
  })
>
_pump(
  WidgetTester tester, {
  FakeProjectPeopleGateway? gateway,
  ProjectCapacitySnapshot? capacity,
  ProjectManagementRole role = ProjectManagementRole.creator,
  String viewer = 'user-1',
  String language = 'en',
  double scale = 1,
  bool dark = false,
  ProjectKind kind = ProjectKind.oneTime,
  ValueNotifier<bool>? canPop,
  bool settle = true,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = FakeAuthGateway(
    snapshot: AuthSnapshot(identity: AuthIdentity(id: viewer)),
  );
  addTearDown(auth.close);
  final people = gateway ?? (FakeProjectPeopleGateway()..rows = [_creator]);
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      projectDelegateGatewayProvider.overrideWithValue(
        FakeProjectDelegateGateway()..role = role,
      ),
      participationGatewayProvider.overrideWithValue(
        FakeParticipationGateway()
          ..capacity = capacity ?? capacityFixture(registrationCapacity: 5),
      ),
      projectPeopleGatewayProvider.overrideWithValue(people),
      profilePhotoGatewayProvider.overrideWithValue(FakeProfilePhotoGateway()),
      blockingGatewayProvider.overrideWithValue(FakeBlockingGateway()),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(AuthIdentity(id: viewer));
  final prefix = kind == ProjectKind.oneTime ? 'proposals' : 'tavoli';
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/people',
        builder: (_, _) {
          final screen = CreatorParticipationScreen(
            projectId: 'project',
            projectKind: kind,
          );
          return canPop == null
              ? screen
              : ValueListenableBuilder<bool>(
                  valueListenable: canPop,
                  builder: (_, allowed, _) =>
                      PopScope(canPop: allowed, child: screen),
                );
        },
      ),
      GoRoute(
        path: '/$prefix/project/participant-links',
        builder: (_, _) =>
            const Scaffold(body: Text('Participant link destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: const Key('people-capture'),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(router.push('/people'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (router: router, container: container, gateway: people);
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    600,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 150,
  );
  await tester.pumpAndSettle();
}

// Opt-in PNG evidence uses the installed SDK's Roboto and Material Icons fonts.
// Run with PEOPLE_UI_CAPTURE_DIR and PEOPLE_UI_FONT_DIR=.../material_fonts.
Future<void> _capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('PEOPLE_UI_CAPTURE_DIR');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('people-capture')),
  );
  final oldShadows = debugDisableShadows;
  try {
    // Widget tests normally replace elevation shadows with solid outlines.
    debugDisableShadows = false;
    boundary.markNeedsPaint();
    await tester.pump();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = oldShadows;
    boundary.markNeedsPaint();
    await tester.pump();
  }
}
