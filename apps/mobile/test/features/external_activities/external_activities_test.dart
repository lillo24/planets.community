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
import 'package:planets_mobile/features/activity_interest/application/activity_interest_tracker.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/mock_mode/application/mock_mode_coordinator.dart';
import 'package:planets_mobile/features/project_delegates/application/project_invite_sharing.dart';
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
import '../../support/fake_activity_interest.dart';
import '../../support/fake_auth.dart';
import '../../support/fake_project_delegates.dart';

void main() {
  setUpAll(() async {
    await RenderedEvidence.loadFonts(force: true);
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
  });
  for (final language in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final sample in [
        'weekly',
        'unknown',
        'cancelled',
        'place',
        'dataset',
      ]) {
        testWidgets('SPORTUI01 $sample $language 2x dark=$dark', (
          tester,
        ) async {
          final width = language == 'it' ? 320.0 : 360.0;
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final payload = externalActivityPayload()..['category'] = 'sports';
          if (sample == 'weekly' || sample == 'unknown') {
            payload['kind'] = 'course';
            payload['occurrences'] = [];
            payload['next_at'] = sample == 'unknown'
                ? null
                : '2026-10-25T09:00:00Z';
            payload['next_occurrence'] = sample == 'unknown'
                ? null
                : {
                    'kind': 'timed',
                    'start': '2026-10-25T10:00:00+01:00',
                    'end': null,
                    'timezone': 'Europe/Rome',
                  };
            payload['schedule'] = {
              'season_start': '2026-10-01',
              'season_end': '2026-11-30',
              'timezone': 'Europe/Rome',
              if (sample == 'weekly')
                'weekly': {
                  'days': [1, 3],
                  'start_time': '10:00',
                  'end_time': '11:00',
                },
            };
          } else if (sample == 'cancelled') {
            payload['status'] = 'cancelled';
          } else {
            payload['kind'] = 'place';
            payload['description'] = null;
            payload['occurrences'] = [];
            payload['next_at'] = null;
            payload['link_scope'] = sample == 'dataset' ? 'dataset' : 'item';
            payload['access'] =
                'Access stated by the source; opening times unknown';
          }
          payload['title'] = switch (sample) {
            'weekly' => 'Synthetic weekly fitness',
            'unknown' => 'Synthetic course with unconfirmed sessions',
            'cancelled' => 'Synthetic cancelled running event',
            _ => 'Synthetic public basketball court',
          };
          payload['source_categories'] = [
            sample == 'place' || sample == 'dataset'
                ? 'Basketball court'
                : 'Fitness',
          ];
          final item = ExternalActivity.parse(payload);
          final gateway = FakeExternalActivityGateway()..detail = item;
          final router = await _pump(
            tester,
            gateway,
            language: language,
            scale: 2,
            dark: dark,
          );
          router.go('/activities/external/${item.id}');
          await tester.pumpAndSettle();
          await RenderedEvidence.capture(
            tester,
            'sportui01-$sample-$language-${dark ? 'dark' : 'light'}-top',
          );
          final link = find.byKey(const Key('external-activity-official-link'));
          await tester.scrollUntilVisible(
            link,
            250,
            scrollable: find.byType(Scrollable).hitTestable().first,
          );
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: link,
              matching: find.text(
                sample == 'dataset'
                    ? (language == 'it'
                          ? 'Vedi dataset della fonte'
                          : 'View source dataset')
                    : (language == 'it'
                          ? 'Vedi informazioni ufficiali'
                          : 'Official information'),
              ),
            ),
            findsOneWidget,
          );
          await RenderedEvidence.capture(
            tester,
            'sportui01-$sample-$language-${dark ? 'dark' : 'light'}-source',
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final language in ['en', 'it']) {
    for (final width in [320.0, 360.0]) {
      for (final dark in [false, true]) {
        testWidgets('ACTUI02 rendered $language $width 2x dark=$dark', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final payload = externalActivityPayload();
          final gateway = FakeExternalActivityGateway()
            ..page = externalPageFixture(
              items: [ExternalActivity.parse(payload)],
              health: dark
                  ? ExternalCatalogueHealth.stale
                  : ExternalCatalogueHealth.healthy,
            );
          await _pump(
            tester,
            gateway,
            language: language,
            scale: 2,
            dark: dark,
          );
          await RenderedEvidence.capture(
            tester,
            'actui02-$language-${width.toInt()}-2x-${dark ? 'dark' : 'light'}',
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('external-$externalActivityFixtureId')),
            250,
            scrollable: find.byType(Scrollable).hitTestable().first,
          );
          await tester.pumpAndSettle();
          await RenderedEvidence.capture(
            tester,
            'actui02-results-$language-${width.toInt()}-2x-${dark ? 'dark' : 'light'}',
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
    'ACTUI02 kind transitions, search and reset use full server filters',
    (tester) async {
      final gateway = FakeExternalActivityGateway();
      await _pump(tester, gateway);
      await tester.tap(find.byKey(const Key('activities-category-sports')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('activities-kind-course')));
      await tester.pumpAndSettle();
      expect(gateway.calls.last.category, 'sports');
      expect(gateway.calls.last.kind, ExternalActivityKind.course);
      final search = find.byKey(const Key('activities-external-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'swimming');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(gateway.calls.last.query, 'swimming');
      expect(gateway.calls.last.kind, ExternalActivityKind.course);
      await tester.ensureVisible(
        find.byKey(const Key('activities-reset-filters')),
      );
      await tester.tap(find.byKey(const Key('activities-reset-filters')));
      await tester.pumpAndSettle();
      expect(gateway.calls.last.category, 'sports');
      expect(gateway.calls.last.kind, isNull);
      expect(gateway.calls.last.query, isEmpty);
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    },
  );

  testWidgets(
    'ACTUI02 Culture clears incompatible sports place without changing native scope',
    (tester) async {
      final gateway = FakeExternalActivityGateway();
      await _pump(tester, gateway);
      await tester.tap(find.byKey(const Key('activities-category-sports')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('activities-kind-place')));
      await tester.pumpAndSettle();
      expect(gateway.calls.last.kind, ExternalActivityKind.place);
      expect(find.byKey(const Key('activities-native-tavoli')), findsNothing);
      await tester.tap(find.byKey(const Key('activities-category-culture')));
      await tester.pumpAndSettle();
      expect(gateway.calls.last.kind, isNull);
      expect(find.byKey(const Key('activities-kind-place')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('activities-native-tavoli')),
      );
      await tester.tap(find.byKey(const Key('activities-native-tavoli')));
      await tester.pumpAndSettle();
      expect(find.text('Native Tavoli destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'course detail renders its canonical derived lesson without inventing prose or an unknown-schedule warning',
    (tester) async {
      final payload = externalActivityPayload()
        ..['kind'] = 'course'
        ..['description'] = null
        ..['occurrences'] = []
        ..['next_at'] = '2026-10-25T09:00:00Z'
        ..['next_occurrence'] = {
          'kind': 'timed',
          'start': '2026-10-25T10:00:00+01:00',
          'end': null,
          'timezone': 'Europe/Rome',
        }
        ..['schedule'] = {
          'season_start': '2026-10-01',
          'season_end': '2026-11-30',
          'timezone': 'Europe/Rome',
        };
      final router = await _pump(
        tester,
        FakeExternalActivityGateway()..detail = ExternalActivity.parse(payload),
      );
      router.go('/activities/external/$externalActivityFixtureId');
      await tester.pumpAndSettle();
      expect(find.textContaining('10:00'), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().activitiesExternalScheduleUnknown),
        findsNothing,
      );
      expect(
        find.text(AppLocalizationsEn().activitiesScheduleUnknown),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ACTMET01 imported card gesture once; filters, deep links and return do not emit',
    (tester) async {
      final item = ExternalActivity.parse(externalActivityPayload());
      final gateway = FakeExternalActivityGateway()
        ..page = externalPageFixture(
          items: [item],
          health: ExternalCatalogueHealth.healthy,
        )
        ..detail = item;
      final sink = MemoryActivityInterestSink();
      final router = await _pump(tester, gateway, interestSink: sink);
      expect(sink.events, isEmpty);
      router.go('/activities/external/${item.id}');
      await tester.pumpAndSettle();
      expect(sink.events, isEmpty);
      router.go('/activities');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('activities-category-culture')));
      await tester.pumpAndSettle();
      expect(sink.events, isEmpty);
      final card = find.byKey(ValueKey('external-${item.id}'));
      await tester.scrollUntilVisible(
        card,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final onTap = tester.widget<ExternalActivityCard>(card).onTap;
      onTap();
      onTap();
      await tester.pumpAndSettle();
      expect(sink.events.single.properties, {
        'schema_version': 1,
        'item_kind': 'imported_activity',
        'item_id': externalActivityFixtureId,
        'origin_surface': 'activities_list',
      });
      router.pop();
      await tester.pumpAndSettle();
      expect(sink.events, hasLength(1));
    },
  );

  testWidgets(
    'ACTMET01 imported sharing uses official source URL and honest action names',
    (tester) async {
      final item = ExternalActivity.parse(externalActivityPayload());
      final sink = MemoryActivityInterestSink();
      final sharing = FakeProjectInviteSharing();
      final router = await _pump(
        tester,
        FakeExternalActivityGateway()..detail = item,
        interestSink: sink,
        sharing: sharing,
      );
      router.go('/activities/external/${item.id}');
      await tester.pumpAndSettle();
      final copy = find.byKey(const Key('external-activity-copy'));
      await tester.scrollUntilVisible(copy, 250);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      final share = find.byKey(const Key('external-activity-share'));
      await tester.ensureVisible(share);
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(sharing.copied, item.officialLink.uri.toString());
      expect(sharing.shared, sharing.copied);
      expect(sink.events.map((e) => e.properties['action']), [
        'link_copied',
        'share_sheet_invoked',
      ]);
      for (final event in sink.events) {
        expect(event.properties['item_kind'], 'imported_activity');
        expect(event.properties['origin_surface'], 'imported_activity_detail');
        expect(event.properties.values, isNot(contains(sharing.copied)));
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final native in [false, true]) {
    testWidgets(
      'ACTMET01 imported platform failure native=$native emits nothing',
      (tester) async {
        final item = ExternalActivity.parse(externalActivityPayload());
        final sink = MemoryActivityInterestSink();
        final router = await _pump(
          tester,
          FakeExternalActivityGateway()..detail = item,
          interestSink: sink,
          sharing: FakeProjectInviteSharing()
            ..error = StateError('platform failure'),
        );
        router.go('/activities/external/${item.id}');
        await tester.pumpAndSettle();
        final button = find.byKey(
          Key(native ? 'external-activity-share' : 'external-activity-copy'),
        );
        await tester.scrollUntilVisible(button, 250);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(sink.events, isEmpty);
        expect(
          find.text(AppLocalizationsEn().projectShareFailure),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'ACTMET01 imported pending copy drops after account replacement',
    (tester) async {
      final item = ExternalActivity.parse(externalActivityPayload());
      final sink = MemoryActivityInterestSink();
      final pending = Completer<void>();
      final router = await _pump(
        tester,
        FakeExternalActivityGateway()..detail = item,
        interestSink: sink,
        sharing: FakeProjectInviteSharing()..delay = pending.future,
      );
      router.go('/activities/external/${item.id}');
      await tester.pumpAndSettle();
      final copy = find.byKey(const Key('external-activity-copy'));
      await tester.scrollUntilVisible(copy, 250);
      await tester.tap(copy);
      await tester.pump();
      ProviderScope.containerOf(
            tester.element(find.byType(ExternalActivityDetailScreen)),
          )
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'account-two'));
      await tester.pump();
      pending.complete();
      await tester.pumpAndSettle();
      expect(sink.events, isEmpty);
    },
  );

  testWidgets(
    'ACTMET01 Mock catalogue navigates without analytics or external sharing',
    (tester) async {
      final item = ExternalActivity.parse(externalActivityPayload());
      final sink = MemoryActivityInterestSink();
      final gateway = FakeExternalActivityGateway()
        ..page = externalPageFixture(
          items: [item],
          health: ExternalCatalogueHealth.healthy,
        )
        ..detail = item;
      await _pump(tester, gateway, interestSink: sink, mock: true);
      final card = find.byKey(ValueKey('external-${item.id}'));
      await tester.scrollUntilVisible(
        card,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(sink.events, isEmpty);
      expect(find.byKey(const Key('external-activity-copy')), findsNothing);
      expect(find.byKey(const Key('external-activity-share')), findsNothing);
    },
  );

  testWidgets('ACTMET01 unavailable imported detail has no share controls', (
    tester,
  ) async {
    final sink = MemoryActivityInterestSink();
    final router = await _pump(
      tester,
      FakeExternalActivityGateway(),
      interestSink: sink,
    );
    router.go('/activities/external/$externalActivityFixtureId');
    await tester.pumpAndSettle();
    expect(sink.events, isEmpty);
    expect(find.byKey(const Key('external-activity-copy')), findsNothing);
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
        expect(request.url.path, '/rest/v1/rpc/list_external_activities_v2');
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
        kind: ExternalActivityKind.event,
        from: '2026-10-23',
        to: '2026-10-26',
      ),
    );
    gateway.page = externalPageFixture(
      items: [item],
      health: ExternalCatalogueHealth.healthy,
    );
    await controller.refresh();
    expect(gateway.calls.last.discipline, isNull);
    expect(gateway.calls.last.query, 'source text');
    expect(gateway.calls.last.kind, ExternalActivityKind.event);
    expect(gateway.calls.last.from, '2026-10-23');
    expect(gateway.calls.last.to, '2026-10-26');
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
      await tester.scrollUntilVisible(
        find.byKey(const Key('activities-external-search')),
        200,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
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
        await tester.scrollUntilVisible(
          find.byKey(const Key('activities-preview-examples')),
          200,
          scrollable: find.byType(Scrollable).hitTestable().first,
        );
        await tester.pumpAndSettle();
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
  MemoryActivityInterestSink? interestSink,
  FakeProjectInviteSharing? sharing,
  bool mock = false,
  bool dark = false,
}) async {
  final auth = FakeAuthGateway();
  addTearDown(auth.close);
  final tracker = interestSink == null
      ? null
      : memoryActivityInterestTracker(interestSink);
  if (tracker != null) addTearDown(tracker.dispose);
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
        authGatewayProvider.overrideWithValue(auth),
        activeMockRealmProvider.overrideWithValue(mock),
        if (tracker != null)
          activityInterestTrackerProvider.overrideWithValue(tracker),
        if (sharing != null)
          projectInviteSharingProvider.overrideWithValue(sharing),
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
          theme: dark ? AppTheme.dark : AppTheme.light,
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
