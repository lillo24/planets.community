import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/project_resource_needs/application/project_resource_matches_controller.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_matches_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/domain/project_resource_match_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_resource_matches.dart';

void main() {
  const key = ProjectResourceMatchesKey(
    projectId: matchProjectId,
    resourceNeedId: matchNeedId,
  );

  test('defaults to visible broad filters and loads backend order', () async {
    final gateway = FakeProjectResourceMatchesGateway()
      ..page = ProjectResourceMatchPage(
        items: [
          projectResourceMatchFixture(
            listingId: '40000000-0000-4000-8000-000000000002',
            title: 'Second-ranked identifier',
          ),
          projectResourceMatchFixture(
            listingId: '40000000-0000-4000-8000-000000000001',
            title: 'First identifier',
          ),
        ],
        hasMore: false,
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectResourceMatchesProvider(key).notifier,
    );
    final initial = session.container.read(projectResourceMatchesProvider(key));

    expect(initial.locationScope, ProjectResourceLocationScope.anywhere);
    expect(initial.listingMode, ProjectResourceListingModeFilter.all);
    expect(await controller.load(matchCreatorId), isTrue);
    final state = session.container.read(projectResourceMatchesProvider(key));
    expect(state.items.map((item) => item.title), [
      'Second-ranked identifier',
      'First identifier',
    ]);
    expect(
      gateway.calls.single.locationScope,
      ProjectResourceLocationScope.anywhere,
    );
    expect(
      gateway.calls.single.listingMode,
      ProjectResourceListingModeFilter.all,
    );
  });

  test(
    'load more preserves order, deduplicates, and advances full cursor',
    () async {
      final first = projectResourceMatchFixture();
      final second = projectResourceMatchFixture(
        listingId: '40000000-0000-4000-8000-000000000002',
        title: 'Second listing',
        textMatchKind:
            ProjectResourceTextMatchKind.needTitleInListingDescription,
        locationMatchKind: ProjectResourceLocationMatchKind.sameCountry,
      );
      final gateway = FakeProjectResourceMatchesGateway()
        ..queuedPages.addAll([
          ProjectResourceMatchPage(items: [first], hasMore: true),
          ProjectResourceMatchPage(items: [first, second], hasMore: false),
        ]);
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectResourceMatchesProvider(key).notifier,
      );

      await controller.load(matchCreatorId);
      expect(await controller.loadMore(matchCreatorId), isTrue);
      final state = session.container.read(projectResourceMatchesProvider(key));
      expect(state.items.map((item) => item.listingId), [
        matchListingId,
        second.listingId,
      ]);
      expect(gateway.calls.last.cursor?.listingId, matchListingId);
      expect(state.cursor?.textMatchKind, second.textMatchKind);
      expect(state.cursor?.locationMatchKind, second.locationMatchKind);
      expect(state.cursor?.publishedAt, second.publishedAt);
      expect(state.cursor?.listingId, second.listingId);
    },
  );

  test(
    'filter changes reset pagination and refresh preserves filters',
    () async {
      final gateway = FakeProjectResourceMatchesGateway()
        ..page = ProjectResourceMatchPage(
          items: [projectResourceMatchFixture()],
          hasMore: true,
        );
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectResourceMatchesProvider(key).notifier,
      );

      await controller.load(matchCreatorId);
      await controller.setLocationScope(
        expectedCreatorProfileId: matchCreatorId,
        locationScope: ProjectResourceLocationScope.sameCountry,
      );
      await controller.setListingMode(
        expectedCreatorProfileId: matchCreatorId,
        listingMode: ProjectResourceListingModeFilter.donate,
      );
      await controller.refresh(matchCreatorId);

      expect(gateway.calls[1].cursor, isNull);
      expect(
        gateway.calls[1].locationScope,
        ProjectResourceLocationScope.sameCountry,
      );
      expect(gateway.calls[2].cursor, isNull);
      expect(
        gateway.calls[2].listingMode,
        ProjectResourceListingModeFilter.donate,
      );
      expect(
        gateway.calls.last.locationScope,
        ProjectResourceLocationScope.sameCountry,
      );
      expect(
        gateway.calls.last.listingMode,
        ProjectResourceListingModeFilter.donate,
      );
    },
  );

  test('canonical need/state failures clear stale matches safely', () async {
    final gateway = FakeProjectResourceMatchesGateway()
      ..page = ProjectResourceMatchPage(
        items: [projectResourceMatchFixture()],
        hasMore: false,
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectResourceMatchesProvider(key).notifier,
    );
    await controller.load(matchCreatorId);

    gateway.error = const PostgrestException(
      message: 'private backend diagnostic',
      code: '55000',
    );
    expect(await controller.refresh(matchCreatorId), isFalse);
    final state = session.container.read(projectResourceMatchesProvider(key));
    expect(state.items, isEmpty);
    expect(
      state.failure,
      ProjectResourceMatchesFailureKind.projectStateUnavailable,
    );
  });

  test(
    'account switch clears state and rejects a stale late response',
    () async {
      final pending = Completer<void>();
      final gateway = FakeProjectResourceMatchesGateway()
        ..page = ProjectResourceMatchPage(
          items: [projectResourceMatchFixture()],
          hasMore: false,
        )
        ..delay = pending.future;
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectResourceMatchesProvider(key).notifier,
      );

      final load = controller.load(matchCreatorId);
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'another-profile'));
      final cleared = session.container.read(
        projectResourceMatchesProvider(key),
      );
      expect(cleared.expectedCreatorProfileId, isNull);
      expect(cleared.items, isEmpty);
      pending.complete();

      expect(await load, isFalse);
      expect(
        session.container.read(projectResourceMatchesProvider(key)).items,
        isEmpty,
      );
    },
  );

  test('maps only stable backend codes', () {
    expect(
      mapProjectResourceMatchesFailure(
        const PostgrestException(message: 'x', code: '22023'),
      ),
      ProjectResourceMatchesFailureKind.invalidInput,
    );
    expect(
      mapProjectResourceMatchesFailure(
        const PostgrestException(message: 'x', code: '42501'),
      ),
      ProjectResourceMatchesFailureKind.forbidden,
    );
    expect(
      mapProjectResourceMatchesFailure(
        const PostgrestException(message: 'x', code: 'P0002'),
      ),
      ProjectResourceMatchesFailureKind.notFound,
    );
    expect(
      mapProjectResourceMatchesFailure(StateError('private')),
      ProjectResourceMatchesFailureKind.unavailable,
    );
  });
}

({ProviderContainer container, void Function() dispose}) _readyContainer(
  FakeProjectResourceMatchesGateway gateway,
) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: matchCreatorId)),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      projectResourceMatchesGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: matchCreatorId));
  return (
    container: container,
    dispose: () {
      container.dispose();
      auth.close();
    },
  );
}
