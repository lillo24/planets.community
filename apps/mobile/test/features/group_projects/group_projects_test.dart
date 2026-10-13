import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/group_projects/application/group_attribution_draft.dart';
import 'package:planets_mobile/features/group_projects/data/group_project_gateway.dart';
import 'package:planets_mobile/features/group_projects/domain/group_project_models.dart';
import 'package:planets_mobile/features/group_projects/presentation/group_project_widgets.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_proposal.dart';

class MemoryGroups extends GroupProjectGateway {
  MemoryGroups()
    : super(() => throw StateError('No network in component tests.'));
  ProjectGroupBinding current = const ProjectGroupBinding(
    groupId: 'group-a',
    name: 'Garden',
    version: 1,
  );
  final writes = <(String, int, String?)>[];
  Object? failure;
  bool lostResponse = false;
  Future<List<PublishableGroup>>? eligibleResult;
  @override
  Future<ProjectGroupBinding> own(String actor, String project) async =>
      current;
  @override
  Future<void> set(
    String actor,
    String project,
    String request,
    int version,
    String? group,
  ) async {
    writes.add((request, version, group));
    if (failure case final error?) throw error;
    current = ProjectGroupBinding(groupId: group, version: version + 1);
    if (lostResponse) {
      lostResponse = false;
      throw const SocketException('Lost response');
    }
  }

  @override
  Future<List<PublishableGroup>> eligible(
    String actor, {
    PublishableGroup? after,
  }) async =>
      eligibleResult ??
      [PublishableGroup('group-a', 'Garden', 'informal', DateTime.utc(2026))];
}

void main() {
  test('eligible groups reject unsupported kinds and private revisions reject negative values', () {
    expect(
      () => PublishableGroup.parse({
        'id': 'group',
        'name': 'Garden',
        'group_kind': 'unknown',
        'created_at': '2026-01-01T00:00:00Z',
      }),
      throwsFormatException,
    );
    expect(
      () => ProjectGroupBinding.parse({
        'group_id': null,
        'group_name': null,
        'version': -1,
        'frozen': false,
      }),
      throwsFormatException,
    );
  });
  test('clearing after an uncertain grouped creation clears the same accepted draft', () async {
    final gateway = MemoryGroups();
    final draft = GroupAttributionDraft(
      gateway,
      'actor',
      initialGroup: 'group-a',
    )..select(null);
    await draft.persist(
      'accepted-project',
      created: true,
      createdGroup: 'group-a',
    );
    expect(gateway.writes.single.$2, 1);
    expect(gateway.writes.single.$3, isNull);
    expect(draft.confirmed.groupId, isNull);
    expect(draft.confirmed.version, 2);
  });
  test(
    'unknown association outcome freezes exact key/version/intent until reread',
    () async {
      final gateway = MemoryGroups()..lostResponse = true;
      final draft = GroupAttributionDraft(
        gateway,
        'actor',
        binding: gateway.current,
      )..select('group-b');
      await expectLater(
        draft.persist('project', created: false),
        throwsA(isA<SocketException>()),
      );
      expect(draft.pending, isTrue);
      expect(() => draft.select(null), throwsStateError);
      await draft.persist('project', created: false);
      expect(gateway.writes[0], gateway.writes[1]);
      expect(draft.pending, isFalse);
      expect(draft.confirmed.groupId, 'group-b');
    },
  );
  test(
    'definitive representation denial permits clearing retained selection',
    () async {
      final gateway = MemoryGroups()
        ..failure = const PostgrestException(
          message: 'Denied',
          code: '42501',
          details: {'reason': 'group_representation_unavailable'},
        );
      final draft = GroupAttributionDraft(
        gateway,
        'actor',
        binding: gateway.current,
      )..select('group-b');
      await expectLater(
        draft.persist('project', created: false),
        throwsA(isA<PostgrestException>()),
      );
      expect(draft.pending, isFalse);
      draft.select(null);
      gateway.failure = null;
      await draft.persist('project', created: false);
      expect(draft.confirmed.groupId, isNull);
      expect(draft.confirmed.version, 2);
    },
  );
  test(
    'atomic creation rereads the same accepted selection without a second set',
    () async {
      final gateway = MemoryGroups();
      final draft = GroupAttributionDraft(
        gateway,
        'actor',
        initialGroup: 'group-a',
      );
      await draft.persist('accepted-project', created: true);
      expect(gateway.writes, isEmpty);
      expect(draft.confirmed.version, 1);
      expect(draft.dirty, isFalse);
    },
  );
  test(
    'group denial preserves Project editor authority and bound draft',
    () async {
      final gateway = FakeProposalGateway()..ownItems = [ownProposalFixture()];
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      final container = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(
            FakeProfileAnchorGateway(),
          ),
          proposalGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.close);
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-1'));
      final controller = container.read(proposalEditorProvider.notifier);
      await controller.load('user-1', 'proposal-1');
      final groups = MemoryGroups()
        ..failure = const PostgrestException(
          message: 'Group role lost',
          code: '42501',
          details: {'reason': 'group_representation_unavailable'},
        );
      final draft = GroupAttributionDraft(
        groups,
        'user-1',
        binding: groups.current,
      )..select('group-b');
      expect(
        await controller.saveDraft(
          'user-1',
          proposalInputFixture(),
          attribution: draft,
        ),
        isNull,
      );
      expect(
        container.read(proposalEditorProvider).failure,
        ProposalFailureKind.unavailable,
      );
      expect(controller.boundProposalId, 'proposal-1');
      expect(draft.failed, isTrue);
      draft.select(null);
      groups.failure = null;
      expect(
        await controller.saveDraft(
          'user-1',
          proposalInputFixture(),
          attribution: draft,
        ),
        'proposal-1',
      );
    },
  );
  test('neutral projection rejects an exposed hidden identity', () {
    expect(
      () => ProjectGroupAttribution.parse({
        'state': 'unavailable',
        'project_id': 'project',
        'group_id': 'secret',
      }),
      throwsFormatException,
    );
  });
  for (final locale in ['en', 'it']) {
    testWidgets(
      '$locale personal default and deliberate choice at 320dp large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final draft = GroupAttributionDraft(MemoryGroups(), 'actor');
        final auth = FakeAuthGateway(
          snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'actor')),
        );
        final container = ProviderContainer(
          overrides: [
            authGatewayProvider.overrideWithValue(auth),
            profileAnchorGatewayProvider.overrideWithValue(
              FakeProfileAnchorGateway(),
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(auth.close);
        container
            .read(authSessionProvider.notifier)
            .markProfileReady(const AuthIdentity(id: 'actor'));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: Locale(locale),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: GroupPublishSelector(
                    draft: draft,
                    enabled: true,
                    onChanged: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        expect(draft.groupId, isNull);
        await tester.tap(find.byKey(const Key('group-publish-selector')));
        await tester.pumpAndSettle();
        expect(draft.groupId, isNull);
        await tester.tap(find.byKey(const ValueKey('publish-for-group-a')));
        await tester.pumpAndSettle();
        expect(draft.groupId, 'group-a');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('an account switch discards a late private chooser page', (
    tester,
  ) async {
    final response = Completer<List<PublishableGroup>>();
    final gateway = MemoryGroups()..eligibleResult = response.future;
    final draft = GroupAttributionDraft(gateway, 'actor');
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'actor')),
    );
    final container = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'actor'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GroupPublishSelector(
              draft: draft,
              enabled: true,
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('group-publish-selector')));
    await tester.pump();
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'different-actor'));
    response.complete([
      PublishableGroup(
        'group-a',
        'Private old affiliation',
        'informal',
        DateTime.utc(2026),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Private old affiliation'), findsNothing);
    expect(find.textContaining('account changed'), findsOneWidget);
    expect(draft.groupId, isNull);
    expect(tester.takeException(), isNull);
  });
}
