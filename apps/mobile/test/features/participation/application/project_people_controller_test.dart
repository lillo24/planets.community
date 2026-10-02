import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/application/project_people_controller.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/data/project_people_gateway.dart';
import 'package:planets_mobile/features/participation/domain/project_people_models.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_project_people.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_profile_photo.dart';

void main() {
  ProjectPerson person(int n) => ProjectPerson(
    profileId: 'p$n',
    displayName: 'Person $n',
    isCreator: false,
    roleRank: 3,
    membershipId: 'm$n',
  );
  ProviderContainer session(
    FakeProjectPeopleGateway gateway, {
    ProjectManagementRole role = ProjectManagementRole.creator,
  }) {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    addTearDown(auth.close);
    final container = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway(),
        ),
        projectPeopleGatewayProvider.overrideWithValue(gateway),
        projectDelegateGatewayProvider.overrideWithValue(
          FakeProjectDelegateGateway()..role = role,
        ),
        participationGatewayProvider.overrideWithValue(
          FakeParticipationGateway(),
        ),
        profilePhotoGatewayProvider.overrideWithValue(
          FakeProfilePhotoGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-1'));
    return container;
  }

  test('each section is bounded independently and duplicate page commands do not fan out', () async {
    final gateway = FakeProjectPeopleGateway()
      ..rows = List.generate(101, person);
    final container = session(gateway);
    final controller = container.read(projectPeopleProvider.notifier);
    await controller.load('user-1', 'project');
    expect(container.read(projectPeopleProvider).people.items, hasLength(50));
    expect(
      gateway.calls,
      containsAll([
        'people:first',
        'requests:first',
        'history:first',
        'offers:first',
      ]),
    );
    await Future.wait([
      controller.loadMore(PeopleSection.people),
      controller.loadMore(PeopleSection.people),
    ]);
    expect(container.read(projectPeopleProvider).people.items, hasLength(100));
    expect(gateway.calls.where((c) => c == 'people:p49'), hasLength(1));
    await controller.loadMore(PeopleSection.people);
    expect(container.read(projectPeopleProvider).people.items, hasLength(101));
    expect(container.read(projectPeopleProvider).people.hasMore, isFalse);
    expect(gateway.calls.where((c) => c.startsWith('history')), hasLength(1));
  });
  test('late mutation failure cannot overwrite a different Project', () async {
    final gateway = FakeProjectPeopleGateway()..rows = [person(1)];
    final container = session(gateway);
    final controller = container.read(projectPeopleProvider.notifier);
    await controller.load('user-1', 'first-project');
    final pending = Completer<void>();
    final mutation = controller.mutate((_, _) async {
      await pending.future;
      throw const PostgrestException(message: 'capacity', code: 'PT409');
    });
    await controller.load('user-1', 'second-project');
    pending.complete();
    expect(await mutation, isFalse);
    expect(container.read(projectPeopleProvider).projectId, 'second-project');
    expect(container.read(projectPeopleProvider).failure, isNull);
  });
  test(
    'ordinary member never invokes manager requests, history or capacity',
    () async {
      final gateway = FakeProjectPeopleGateway()..rows = [person(1)];
      final container = session(gateway, role: ProjectManagementRole.none);
      await container
          .read(projectPeopleProvider.notifier)
          .load('user-1', 'project');
      await container
          .read(projectPeopleProvider.notifier)
          .loadMore(PeopleSection.requests);
      expect(gateway.calls, ['people:first', 'offers:first']);
      expect(container.read(projectPeopleProvider).capacity, isNull);
    },
  );
  test(
    'sign-out clears all private rows and ignores late page responses',
    () async {
      final gateway = FakeProjectPeopleGateway()
        ..rows = List.generate(51, person);
      final container = session(gateway);
      final controller = container.read(projectPeopleProvider.notifier);
      await controller.load('user-1', 'project');
      final pending = Completer<void>();
      gateway.delay = pending.future;
      final load = controller.loadMore(PeopleSection.people);
      container.read(authSessionProvider.notifier).markSignedOut();
      await container.pump();
      pending.complete();
      await load;
      expect(container.read(projectPeopleProvider).people.items, isEmpty);
      expect(container.read(projectPeopleProvider).profileId, isNull);
    },
  );
  test('42501 on a later page clears every private section and role', () async {
    final gateway = FakeProjectPeopleGateway()
      ..rows = List.generate(51, person);
    final container = session(gateway);
    final controller = container.read(projectPeopleProvider.notifier);
    await controller.load('user-1', 'project');
    gateway.error = const PostgrestException(
      message: 'private denial',
      code: '42501',
    );
    await controller.loadMore(PeopleSection.people);
    final state = container.read(projectPeopleProvider);
    expect(state.people.items, isEmpty);
    expect(state.requests.items, isEmpty);
    expect(state.history.items, isEmpty);
    expect(state.role, ProjectManagementRole.none);
    expect(state.failure, PeopleFailure.forbidden);
  });
  test('transient paging failure retains rows but exposes an explicit retryable failure', () async {
    final gateway = FakeProjectPeopleGateway()
      ..rows = List.generate(51, person);
    final container = session(gateway);
    final controller = container.read(projectPeopleProvider.notifier);
    await controller.load('user-1', 'project');
    gateway.error = StateError('network');
    await controller.loadMore(PeopleSection.people);
    expect(container.read(projectPeopleProvider).people.items, hasLength(50));
    expect(
      container.read(projectPeopleProvider).people.failure,
      PeopleFailure.unavailable,
    );
    gateway.error = null;
    await controller.loadMore(PeopleSection.people);
    expect(container.read(projectPeopleProvider).people.items, hasLength(51));
  });
  test(
    'capacity failure refreshes truth and stays distinct from general conflict',
    () async {
      final gateway = FakeProjectPeopleGateway()..rows = [person(1)];
      final container = session(gateway);
      final controller = container.read(projectPeopleProvider.notifier);
      await controller.load('user-1', 'project');
      expect(
        await controller.mutate((_, _) async {
          throw const PostgrestException(
            message: 'Project capacity would be exceeded',
            code: 'PT409',
          );
        }),
        isFalse,
      );
      expect(
        container.read(projectPeopleProvider).failure,
        PeopleFailure.capacity,
      );
      expect(container.read(projectPeopleProvider).people.items, hasLength(1));
      expect(
        peopleFailure(
          const PostgrestException(message: 'Already offered', code: 'PT409'),
        ),
        PeopleFailure.conflict,
      );
    },
  );
}
