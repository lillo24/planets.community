import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/core/backend/public_external_link.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/activities_sandbox/presentation/activities_screen.dart';
import 'package:planets_mobile/features/activities_sandbox/presentation/activity_example_detail_screen.dart';
import 'package:planets_mobile/features/external_activities/application/external_activities_controller.dart';
import 'package:planets_mobile/features/external_activities/data/external_activity_gateway.dart';
import 'package:planets_mobile/features/external_activities/domain/external_activity.dart';
import 'package:planets_mobile/features/external_activities/presentation/external_activities_screen.dart';
import 'package:planets_mobile/features/external_activities/presentation/external_activity_detail_screen.dart';
import 'package:planets_mobile/features/external_activities/presentation/external_activity_widgets.dart';
import 'package:planets_mobile/features/settings/application/activities_split_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/activities_split_preference.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:planets_mobile/l10n/generated/app_localizations_en.dart';

import '../../support/rendered_evidence.dart';
import '../../support/fake_external_activities.dart';

void main() {
  setUpAll(() async {
    await RenderedEvidence.loadFonts(force: true);
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
  });

  test('RPC gateway forwards complete filters, handles source disable and preserves real failures', () async {
    var responseCode = 200;
    Object? response = {
      'state': 'unconfigured',
      'as_of': '2026-10-22T12:00:00Z',
      'items': [],
      'disciplines': [],
      'next_cursor': null,
      'last_success_at': null,
    };
    final client = SupabaseClient(
      'https://planets.example.org',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/list_external_activities');
        final params = jsonDecode(request.body) as Map<String, dynamic>;
        expect(params['p_category'], 'culture');
        expect(params['p_query'], 'source text');
        expect(params['p_limit'], 20);
        return http.Response(
          jsonEncode(response),
          responseCode,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final gateway = SupabaseExternalActivityGateway(client);
    const filter = ExternalActivityFilter(
      category: 'culture',
      query: 'source text',
    );
    final page = await gateway.list(
      filter,
      cursor: {'as_of': '2026-10-21T12:00:00Z'},
    );
    expect(page.health, ExternalCatalogueHealth.unconfigured);
    expect(page.items, isEmpty);
    responseCode = 400;
    response = {
      'code': '22023',
      'message': 'Activity cursor requires refresh.',
    };
    await expectLater(
      gateway.list(filter, cursor: {'as_of': '2026-10-21T12:00:00Z'}),
      throwsA(isA<ExternalActivityCursorExpired>()),
    );
    await expectLater(gateway.list(filter), throwsA(isA<PostgrestException>()));
    responseCode = 200;
    response = {'state': 'healthy', 'items': null};
    await expectLater(gateway.list(filter), throwsFormatException);
  });

  test('source disable clears retained pages and removed disciplines cannot remain hidden filters', () async {
    final item = ExternalActivity.parse(externalActivityPayload());
    final gateway = FakeExternalActivityGateway()
      ..page = externalPageFixture(
        items: [item],
        health: ExternalCatalogueHealth.healthy,
        cursor: {'as_of': '2026-10-21T12:00:00Z', 'id': item.id},
      );
    final container = ProviderContainer(
      overrides: [
        initialActivitiesSplitPreferenceProvider.overrideWithValue(
          const ActivitiesSplitPreferenceState(mode: ActivitiesSplitMode.on),
        ),
        externalActivityGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      externalActivitiesControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(
      externalActivitiesControllerProvider.notifier,
    )..setActive(true);
    await Future<void>.delayed(Duration.zero);
    gateway.page = externalPageFixture();
    await controller.loadMore();
    expect(
      container.read(externalActivitiesControllerProvider).page!.items,
      isEmpty,
    );
    expect(
      container.read(externalActivitiesControllerProvider).page!.health,
      ExternalCatalogueHealth.unconfigured,
    );
    gateway.page = externalPageFixture(
      items: [item],
      health: ExternalCatalogueHealth.healthy,
      disciplines: ['rowing'],
    );
    await controller.filter(
      const ExternalActivityFilter(
        category: 'sports',
        query: 'source text',
        discipline: 'rowing',
      ),
    );
    gateway.page = externalPageFixture(
      items: [item],
      health: ExternalCatalogueHealth.healthy,
    );
    await controller.refresh();
    expect(gateway.calls.last.discipline, isNull);
    expect(gateway.calls.last.query, 'source text');
    expect(
      container.read(externalActivitiesControllerProvider).filter.category,
      'sports',
    );
  });

  test(
    'exclusive date ends use calendar arithmetic across spring and autumn DST',
    () {
      for (final start in ['2026-03-29', '2026-10-25']) {
        final date = DateTime.parse(start);
        final end = DateTime.utc(
          date.year,
          date.month,
          date.day + 1,
        ).toIso8601String().substring(0, 10);
        final occurrence = ExternalOccurrence.parse({
          'kind': 'all_day',
          'start': start,
          'end': end,
          'timezone': 'Europe/Rome',
        });
        final label = externalOccurrenceLabel(
          occurrence,
          'en',
          AppLocalizationsEn(),
        );
        expect(
          label,
          start == '2026-03-29'
              ? 'Mar 29, 2026 · All day'
              : 'Oct 25, 2026 · All day',
        );
        expect(label, isNot(contains('00:00')));
      }
    },
  );

  test('public links reject unsafe schemes, credentials, IP/local destinations and ports', () {
    for (final input in [
      'javascript:alert(1)',
      'http://calendar.example.org/event',
      'https://a:b@calendar.example.org/event',
      'https://127.0.0.1/event',
      'https://localhost/event',
      'https://a.local/event',
      'https://calendar.example.org:9000/event',
      'https://calendar.example.org/unsafe path',
    ]) {
      expect(() => PublicExternalLink.parse(input), throwsFormatException);
    }
    expect(
      PublicExternalLink.parse('https://calendar.example.org/event').uri.host,
      'calendar.example.org',
    );
  });
  test('strict parsing preserves sessions/offsets and refuses malformed success-shaped payloads', () {
    final item = ExternalActivity.parse(externalActivityPayload());
    expect(item.occurrences, hasLength(2));
    expect(item.nextOccurrence!.start, '2026-10-24T10:00:00+02:00');
    expect(item.cost, isNull);
    expect(item.category, 'culture');
    expect(
      () => ExternalActivityPage.parse({'state': 'healthy', 'items': null}),
      throwsFormatException,
    );
    expect(
      () => ExternalActivity.parse({
        ...externalActivityPayload(),
        'canonical_url': 'file:///secret',
      }),
      throwsFormatException,
    );
    expect(
      () => ExternalOccurrence.parse({
        'kind': 'date',
        'start': '2026-02-30',
        'timezone': 'Europe/Rome',
      }),
      throwsFormatException,
    );
  });
  test('controller performs no construction/off/inactive IO and fences old filter responses', () async {
    final gateway = FakeExternalActivityGateway();
    final container = ProviderContainer(
      overrides: [
        initialActivitiesSplitPreferenceProvider.overrideWithValue(
          const ActivitiesSplitPreferenceState(mode: ActivitiesSplitMode.on),
        ),
        externalActivityGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      externalActivitiesControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(
      externalActivitiesControllerProvider.notifier,
    );
    expect(gateway.calls, isEmpty);
    await controller.refresh();
    expect(gateway.calls, isEmpty);
    final pending = Completer<ExternalActivityPage>();
    gateway.onList = (_, _) => pending.future;
    controller.setActive(true);
    expect(gateway.calls, hasLength(1));
    gateway.onList = (_, _) async =>
        externalPageFixture(health: ExternalCatalogueHealth.empty);
    await controller.filter(
      const ExternalActivityFilter(category: 'sports', query: 'rowing'),
    );
    pending.complete(
      externalPageFixture(
        items: [ExternalActivity.parse(externalActivityPayload())],
        health: ExternalCatalogueHealth.healthy,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(externalActivitiesControllerProvider).page!.items,
      isEmpty,
    );
    expect(
      container.read(externalActivitiesControllerProvider).filter.query,
      'rowing',
    );
    controller.setActive(false);
    final count = gateway.calls.length;
    await controller.refresh();
    await controller.loadMore();
    expect(gateway.calls, hasLength(count));
  });
  test('refresh failure retains public rows with an explicit error; invalidated cursor restarts reads', () async {
    final gateway = FakeExternalActivityGateway()
      ..page = externalPageFixture(
        items: [ExternalActivity.parse(externalActivityPayload())],
        health: ExternalCatalogueHealth.healthy,
        cursor: {
          'as_of': '2026-10-21T12:00:00Z',
          'id': externalActivityFixtureId,
        },
      );
    final container = ProviderContainer(
      overrides: [
        initialActivitiesSplitPreferenceProvider.overrideWithValue(
          const ActivitiesSplitPreferenceState(mode: ActivitiesSplitMode.on),
        ),
        externalActivityGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      externalActivitiesControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(
      externalActivitiesControllerProvider.notifier,
    )..setActive(true);
    await Future<void>.delayed(Duration.zero);
    gateway.error = StateError('synthetic failed read');
    await controller.refresh();
    expect(container.read(externalActivitiesControllerProvider).failed, isTrue);
    expect(
      container.read(externalActivitiesControllerProvider).page!.items,
      hasLength(1),
    );
    gateway.error = null;
    gateway.onList = (_, cursor) async {
      if (cursor != null) throw const ExternalActivityCursorExpired();
      return externalPageFixture(health: ExternalCatalogueHealth.empty);
    };
    await controller.loadMore();
    expect(gateway.cursors[gateway.cursors.length - 2], isNotNull);
    expect(gateway.cursors.last, isNull);
    expect(
      container.read(externalActivitiesControllerProvider).page!.items,
      isEmpty,
    );
  });

  testWidgets(
    'real backend list/detail, official link and backend-only refresh retain filters',
    (tester) async {
      final item = ExternalActivity.parse(externalActivityPayload(stale: true));
      final gateway = FakeExternalActivityGateway()
        ..page = externalPageFixture(
          items: [item],
          health: ExternalCatalogueHealth.stale,
        )
        ..detail = item;
      final launcher = FakePublicExternalLinkLauncher();
      final router = await _pump(tester, gateway, launcher: launcher);
      expect(
        find.text('Synthetic cultural exhibition about sport'),
        findsOneWidget,
      );
      expect(find.text('First steps on the climbing wall'), findsNothing);
      expect(find.text('Last observed more than 72 hours ago'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await RenderedEvidence.capture(tester, 'actapi01-synthetic-list');
      await tester.enterText(
        find.byKey(const Key('activities-external-search')),
        'sport',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(gateway.calls.last.query, 'sport');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('external-$externalActivityFixtureId')),
        200,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await tester.tap(
        find.byKey(const ValueKey('external-$externalActivityFixtureId')),
      );
      await tester.pumpAndSettle();
      expect(gateway.detailCalls, [externalActivityFixtureId]);
      expect(
        find.textContaining('Synthetic fixture attribution'),
        findsOneWidget,
      );
      expect(find.textContaining('Last observed by PLANETS:'), findsOneWidget);
      expect(find.textContaining('Oct 31, 2026'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      await RenderedEvidence.capture(tester, 'actapi01-synthetic-detail');
      await tester.scrollUntilVisible(
        find.byKey(const Key('external-activity-official-link')),
        200,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await tester.tap(
        find.byKey(const Key('external-activity-official-link')),
      );
      await tester.pumpAndSettle();
      expect(
        launcher.links.single.uri.toString(),
        'https://calendar.example.org/events/synthetic',
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('activities-external-search')),
            )
            .controller!
            .text,
        'sport',
      );
      final calls = gateway.calls.length;
      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refresh;
      expect(gateway.calls, hasLength(calls + 1));
    },
  );

  for (final health in [
    ExternalCatalogueHealth.unconfigured,
    ExternalCatalogueHealth.neverSynchronized,
    ExternalCatalogueHealth.empty,
    ExternalCatalogueHealth.unavailable,
  ]) {
    testWidgets(
      'honest $health state has no fictional fallback and explicit example preview',
      (tester) async {
        final gateway = FakeExternalActivityGateway()
          ..page = externalPageFixture(health: health);
        final router = await _pump(tester, gateway);
        expect(find.byType(ExternalActivityCard), findsNothing);
        expect(
          find.byKey(const Key('external-activities-empty')),
          health == ExternalCatalogueHealth.empty
              ? findsOneWidget
              : findsNothing,
        );
        await tester.tap(find.byKey(const Key('activities-preview-examples')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/activities/examples');
        expect(find.text('Fictional examples'), findsOneWidget);
        expect(
          find.byKey(const Key('activities-example-search')),
          findsOneWidget,
        );
        expect(gateway.detailCalls, isEmpty);
      },
    );
  }
  testWidgets(
    'failed read is not empty or unconfigured; OFF and inactive surfaces do not read',
    (tester) async {
      final gateway = FakeExternalActivityGateway()
        ..error = StateError('read failed');
      await _pump(tester, gateway);
      expect(
        find.byKey(const Key('external-activities-read-error')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('external-activities-empty')), findsNothing);
      expect(find.byKey(const Key('external-activities-health')), findsNothing);
      final off = FakeExternalActivityGateway();
      await _pump(tester, off, enabled: false);
      expect(off.calls, isEmpty);
      final inactive = FakeExternalActivityGateway();
      await _pump(tester, inactive, active: false);
      expect(inactive.calls, isEmpty);
    },
  );
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language 320dp 2x source schedules and detail remain accessible',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final payload = externalActivityPayload()
          ..['occurrences'] = [
            {
              'kind': 'all_day',
              'start': '2026-10-25',
              'end': '2026-10-26',
              'timezone': 'Europe/Rome',
            },
          ]
          ..['next_at'] = '2026-10-24T22:00:00Z';
        final item = ExternalActivity.parse(payload);
        final gateway = FakeExternalActivityGateway()
          ..page = externalPageFixture(
            items: [item],
            health: ExternalCatalogueHealth.healthy,
          )
          ..detail = item;
        final router = await _pump(
          tester,
          gateway,
          language: language,
          scale: 2,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('external-$externalActivityFixtureId')),
          250,
          scrollable: find.byType(Scrollable).hitTestable().first,
        );
        expect(
          find.textContaining(language == 'it' ? 'Tutto il giorno' : 'All day'),
          findsOneWidget,
        );
        await tester.pumpAndSettle();
        await RenderedEvidence.capture(tester, 'actapi01-$language-320-2x');
        router.push('/activities/external/$externalActivityFixtureId');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('00:00'), findsNothing);
      },
    );
  }
}

Future<GoRouter> _pump(
  WidgetTester tester,
  FakeExternalActivityGateway gateway, {
  FakePublicExternalLinkLauncher? launcher,
  bool enabled = true,
  bool active = true,
  String language = 'en',
  double scale = 1,
}) async {
  final router = GoRouter(
    initialLocation: '/activities',
    routes: [
      GoRoute(
        path: '/activities',
        builder: (_, _) => const ExternalActivitiesScreen(),
        routes: [
          GoRoute(
            path: 'external/:id',
            builder: (_, state) => ExternalActivityDetailScreen(
              activityId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'examples',
            builder: (_, _) => const ActivitiesScreen(),
          ),
          GoRoute(
            path: 'examples/:id',
            builder: (_, state) => ActivityExampleDetailScreen(
              exampleId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/tavoli',
        builder: (_, _) =>
            const Scaffold(body: Text('Native Tavoli destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        initialActivitiesSplitPreferenceProvider.overrideWithValue(
          ActivitiesSplitPreferenceState(
            mode: enabled ? ActivitiesSplitMode.on : ActivitiesSplitMode.off,
          ),
        ),
        externalActivityGatewayProvider.overrideWithValue(gateway),
        publicExternalLinkLauncherProvider.overrideWithValue(
          launcher ?? FakePublicExternalLinkLauncher(),
        ),
      ],
      child: RenderedEvidence.wrap(
        MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => TickerMode(
            enabled: active,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
