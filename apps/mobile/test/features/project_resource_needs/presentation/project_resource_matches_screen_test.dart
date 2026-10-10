import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/cover_media/presentation/cover_image.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_matches_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/domain/project_resource_match_models.dart';
import 'package:planets_mobile/features/project_resource_needs/presentation/project_resource_matches_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_cover_media.dart';
import '../../../support/fake_project_resource_matches.dart';
import '../../../support/fake_project_resource_needs.dart';

void main() {
  test(
    'screen has no Resource-request, need-mutation, or polling coupling',
    () {
      final source = File(
        'lib/features/project_resource_needs/presentation/project_resource_matches_screen.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('resource_request')));
      expect(source, isNot(contains('.close(')));
      expect(source, isNot(contains('Timer')));
      expect(source, isNot(contains('Realtime')));
    },
  );

  testWidgets('shows source need, default filters, cards, and every reason', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 4200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final textKinds = ProjectResourceTextMatchKind.values;
    final locationKinds = ProjectResourceLocationMatchKind.values;
    final matches = [
      for (var index = 0; index < textKinds.length; index++)
        projectResourceMatchFixture(
          listingId: _listingId(index + 1),
          title: 'Matching resource ${index + 1}',
          textMatchKind: textKinds[index],
          locationMatchKind: locationKinds[index % locationKinds.length],
        ),
    ];
    final gateway = FakeProjectResourceMatchesGateway()
      ..page = ProjectResourceMatchPage(items: matches, hasMore: false);
    final harness = await _pump(tester, gateway: gateway);
    addTearDown(harness.dispose);

    expect(find.text('Cordless drill needed'), findsOneWidget);
    expect(find.text('A drill for the community workshop.'), findsOneWidget);
    expect(find.text('Anywhere'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Why it matches'), findsNWidgets(matches.length));
    for (final copy in [
      'Need phrase appears in the listing title',
      'Need keywords match the listing title',
      'Need keywords match the listing description',
      'Need details match the listing title',
      'Need details match the listing description',
      'Same locality',
      'Same area',
      'Same country',
      'Other / location not comparable',
    ]) {
      expect(find.text(copy), findsWidgets);
    }
    expect(find.text('2 people interested'), findsWidgets);
    expect(find.textContaining('score'), findsNothing);
    expect(find.textContaining('reservation'), findsNothing);
    expect(find.textContaining('queue'), findsNothing);
    expect(find.textContaining('available to borrow'), findsNothing);
  });

  testWidgets('match card inherits cover while preserving its reason footer', (
    tester,
  ) async {
    const coverPath =
        '$matchCreatorId/resources/$matchListingId/'
        '40000000-0000-4000-8000-000000000099.webp';
    final gateway = FakeProjectResourceMatchesGateway()
      ..page = ProjectResourceMatchPage(
        items: [projectResourceMatchFixture(coverObjectPath: coverPath)],
        hasMore: false,
      );
    final coverMedia = FakeCoverMediaGateway()..downloadResult = _pngBytes();
    final harness = await _pump(
      tester,
      gateway: gateway,
      coverMedia: coverMedia,
    );
    addTearDown(harness.dispose);

    expect(find.byKey(Key('resource-cover-$matchListingId')), findsOneWidget);
    expect(find.byType(CoverImage), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Why it matches'), findsOneWidget);
    expect(find.text('Need keywords match the listing title'), findsOneWidget);
    expect(coverMedia.calls, contains('download:$coverPath'));
  });

  testWidgets('changes visible filters and shows differentiated empty states', (
    tester,
  ) async {
    final gateway = FakeProjectResourceMatchesGateway();
    final harness = await _pump(tester, gateway: gateway);
    addTearDown(harness.dispose);

    expect(
      find.text('No matching published resources found yet.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('project-resource-match-location-anywhere')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Same country').last);
    await tester.pumpAndSettle();

    expect(
      gateway.calls.last.locationScope,
      ProjectResourceLocationScope.sameCountry,
    );
    expect(find.text('Same country'), findsOneWidget);
    expect(find.text('No matching resources found.'), findsOneWidget);
    expect(find.byKey(const Key('location-attribution')), findsNothing);
    expect(
      find.text('Try a broader location or include both Dona and Scambia.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('project-resource-match-mode-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dona').last);
    await tester.pumpAndSettle();
    expect(
      gateway.calls.last.listingMode,
      ProjectResourceListingModeFilter.donate,
    );
    expect(find.text('Dona'), findsOneWidget);
  });

  testWidgets('safe failure retries without exposing backend diagnostics', (
    tester,
  ) async {
    final gateway = FakeProjectResourceMatchesGateway()
      ..error = const PostgrestException(
        message: 'secret SQL details',
        code: '55000',
      );
    final harness = await _pump(tester, gateway: gateway);
    addTearDown(harness.dispose);

    expect(
      find.text(
        "Matching isn't available with the current Project state or location filter. Try a broader location filter or check the Project details.",
      ),
      findsOneWidget,
    );
    expect(find.text('Anywhere'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.textContaining('secret SQL'), findsNothing);
    expect(find.byKey(const Key('location-attribution')), findsNothing);

    gateway
      ..error = null
      ..page = ProjectResourceMatchPage(
        items: [projectResourceMatchFixture()],
        hasMore: false,
      );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Cordless drill'), findsOneWidget);
  });

  testWidgets('loads more, pull-refreshes, and card opens existing detail', (
    tester,
  ) async {
    final first = projectResourceMatchFixture();
    final second = projectResourceMatchFixture(
      listingId: _listingId(2),
      title: 'Second matching resource',
    );
    final refreshed = projectResourceMatchFixture(
      listingId: _listingId(3),
      title: 'Refreshed matching resource',
    );
    final gateway = FakeProjectResourceMatchesGateway()
      ..queuedPages.addAll([
        ProjectResourceMatchPage(items: [first], hasMore: true),
        ProjectResourceMatchPage(items: [second], hasMore: false),
        ProjectResourceMatchPage(items: [refreshed], hasMore: false),
      ]);
    final harness = await _pump(tester, gateway: gateway);
    addTearDown(harness.dispose);

    await tester.scrollUntilVisible(
      find.byKey(const Key('project-resource-match-load-more')),
      200,
    );
    await tester.tap(find.byKey(const Key('project-resource-match-load-more')));
    await tester.pumpAndSettle();
    expect(find.text('Second matching resource'), findsOneWidget);

    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await refresh;
    await tester.pumpAndSettle();
    expect(gateway.calls.length, 3);
    expect(find.text('Refreshed matching resource'), findsOneWidget);

    final refreshedCard = find.byKey(
      Key('resource-card-${refreshed.listingId}'),
    );
    tester.widget<InkWell>(refreshedCard).onTap!();
    await tester.pumpAndSettle();
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/resources/${refreshed.listingId}',
    );
    expect(find.text('Existing resource detail'), findsOneWidget);
    expect(harness.needsGateway.calls, isNot(contains(startsWith('close:'))));
  });

  testWidgets('long content remains usable at high text scaling', (
    tester,
  ) async {
    final gateway = FakeProjectResourceMatchesGateway()
      ..page = ProjectResourceMatchPage(
        items: [
          projectResourceMatchFixture(
            title: List.filled(12, 'Long resource title').join(' '),
            description: List.filled(
              30,
              'Long matching resource description',
            ).join(' '),
          ),
        ],
        hasMore: false,
      );
    final harness = await _pump(tester, gateway: gateway, textScale: 2);
    addTearDown(harness.dispose);

    expect(tester.takeException(), isNull);
    expect(find.text('Why it matches'), findsOneWidget);
  });
}

Future<
  ({
    ProviderContainer container,
    GoRouter router,
    FakeProjectResourceNeedsGateway needsGateway,
    void Function() dispose,
  })
>
_pump(
  WidgetTester tester, {
  required FakeProjectResourceMatchesGateway gateway,
  double textScale = 1,
  CoverMediaGateway? coverMedia,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 4200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: matchCreatorId)),
  );
  final needsGateway = FakeProjectResourceNeedsGateway()
    ..ownItems = [
      projectResourceNeedFixture(
        id: matchNeedId,
        projectId: matchProjectId,
        title: 'Cordless drill needed',
        details: 'A drill for the community workshop.',
      ),
    ];
  final router = GoRouter(
    initialLocation:
        '/proposals/$matchProjectId/resources/$matchNeedId/matches',
    routes: [
      GoRoute(
        path: '/proposals/:projectId/resources/:resourceNeedId/matches',
        builder: (context, state) => ProjectResourceMatchesScreen(
          projectId: state.pathParameters['projectId']!,
          resourceNeedId: state.pathParameters['resourceNeedId']!,
        ),
      ),
      GoRoute(
        path: '/resources/:listingId',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Existing resource detail')),
        ),
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      projectResourceNeedsGatewayProvider.overrideWithValue(needsGateway),
      projectResourceMatchesGatewayProvider.overrideWithValue(gateway),
      coverMediaGatewayProvider.overrideWithValue(
        coverMedia ?? FakeCoverMediaGateway(),
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: matchCreatorId));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    container: container,
    router: router,
    needsGateway: needsGateway,
    dispose: () {
      router.dispose();
      container.dispose();
      auth.close();
    },
  );
}

String _listingId(int suffix) =>
    '40000000-0000-4000-8000-${suffix.toString().padLeft(12, '0')}';

Uint8List _pngBytes() {
  final source = image.Image(width: 32, height: 18);
  image.fill(source, color: image.ColorRgb8(40, 120, 80));
  return image.encodePng(source);
}
