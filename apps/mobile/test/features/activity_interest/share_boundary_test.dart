import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/activity_interest/application/activity_interest_tracker.dart';
import 'package:planets_mobile/features/activity_interest/domain/activity_interest_event.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/project_delegates/application/project_invite_sharing.dart';
import 'package:planets_mobile/features/project_participant_invites/presentation/share_link_buttons.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_activity_interest.dart';
import '../../support/fake_auth.dart';

const _id = 'fb040000-0000-4000-8000-000000000002';
const _ordinary = 'https://planets.community/tavoli/$_id?intent=join';

void main() {
  final invalid = <String?>[
    null,
    '',
    'https://planets.community/join/project/${'A' * 43}',
    'https://planets.community/invite/project/${'A' * 43}',
    'https://planets.community/proposals/$_id?intent=join',
    '$_ordinary&token=secret',
    'https://untrusted.invalid/tavoli/$_id?intent=join',
  ];
  for (var index = 0; index < invalid.length; index++) {
    testWidgets(
      'invalid/nonordinary handoff $index cannot emit activity analytics',
      (tester) async {
        final sink = MemoryActivityInterestSink();
        await _pump(tester, sink, prepare: () async => invalid[index]);
        await tester.tap(find.byKey(const Key('project-share-copy')));
        await tester.pumpAndSettle();
        expect(sink.events, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'duplicate callbacks while preparing produce one successful handoff',
    (tester) async {
      final pending = Completer<String?>();
      final sink = MemoryActivityInterestSink();
      final sharing = await _pump(tester, sink, prepare: () => pending.future);
      final callback = tester
          .widget<OutlinedButton>(find.byKey(const Key('project-share-copy')))
          .onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(sink.events, isEmpty);
      pending.complete(_ordinary);
      await tester.pumpAndSettle();
      expect(sharing.copies, 1);
      expect(sink.events.single.properties['action'], 'link_copied');
    },
  );

  testWidgets('telemetry failure preserves clipboard success and UI', (
    tester,
  ) async {
    final sink = MemoryActivityInterestSink()
      ..failure = StateError('telemetry offline');
    final sharing = await _pump(tester, sink, prepare: () async => _ordinary);
    await tester.tap(find.byKey(const Key('project-share-copy')));
    await tester.pumpAndSettle();
    expect(sharing.copies, 1);
    expect(sink.calls, 1);
    expect(
      tester.widget<Text>(find.byKey(const Key('project-share-message'))).data,
      isNot(contains('could not')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider construction failure preserves platform success', (
    tester,
  ) async {
    final sink = MemoryActivityInterestSink();
    final sharing = await _pump(
      tester,
      sink,
      prepare: () async => _ordinary,
      brokenProvider: true,
    );
    await tester.tap(find.byKey(const Key('project-share-copy')));
    await tester.pumpAndSettle();
    expect(sharing.copies, 1);
    expect(
      tester.widget<Text>(find.byKey(const Key('project-share-message'))).data,
      isNot(contains('could not')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disposing controls during platform work drops the completion event',
    (tester) async {
      final sink = MemoryActivityInterestSink();
      final sharing = await _pump(tester, sink, prepare: () async => _ordinary);
      final pending = Completer<void>();
      sharing.delay = pending.future;
      await tester.tap(find.byKey(const Key('project-share-native')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pumpAndSettle();
      expect(sink.events, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<_Sharing> _pump(
  WidgetTester tester,
  MemoryActivityInterestSink sink, {
  required Future<String?> Function() prepare,
  bool brokenProvider = false,
}) async {
  final auth = FakeAuthGateway();
  final tracker = memoryActivityInterestTracker(sink);
  final sharing = _Sharing();
  addTearDown(auth.close);
  addTearDown(tracker.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        if (brokenProvider)
          activityInterestTrackerProvider.overrideWith(
            (ref) => throw StateError('telemetry dependency'),
          )
        else
          activityInterestTrackerProvider.overrideWithValue(tracker),
        projectInviteSharingProvider.overrideWithValue(sharing),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShareLinkButtons(
            projectId: _id,
            prepare: prepare,
            publicActivity: PublicActivityInterestItem.tavolo(_id),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return sharing;
}

final class _Sharing implements ProjectInviteSharing {
  int copies = 0;
  Future<void>? delay;
  @override
  Future<void> copy(String value) async {
    if (delay case final delay?) await delay;
    copies++;
  }

  @override
  Future<void> share(String value, {Rect? origin}) async {
    if (delay case final delay?) await delay;
    // Successful invocation may correspond to a dismissed native share sheet.
  }
}
