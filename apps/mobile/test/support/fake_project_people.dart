import 'package:planets_mobile/features/participation/data/project_people_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/participation/domain/project_people_models.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';

import 'fake_participation.dart';

class FakeProjectPeopleGateway implements ProjectPeopleGateway {
  FakeProjectPeopleGateway({this.participation});
  final FakeParticipationGateway? participation;
  List<ProjectPerson> rows = [];
  List<ManagerProjectJoinRequest> requestRows = [];
  List<ManagerProjectMember> historyRows = [];
  List<ProjectRoleOffer> offerRows = [];
  final calls = <String>[];
  Object? error;
  Future<void>? delay;
  Future<void> Function()? onMutation;

  Future<List<T>> _page<T>(
    String label,
    List<T> rows,
    T? after,
    String Function(T) id,
  ) async {
    calls.add('$label:${after == null ? "first" : id(after)}');
    if (delay case final wait?) await wait;
    if (error case final failure?) throw failure;
    if (participation?.error case final failure?) throw failure;
    final start = after == null
        ? 0
        : rows.indexWhere((r) => id(r) == id(after)) + 1;
    return rows.skip(start).take(50).toList();
  }

  @override
  Future<List<ProjectPerson>> people(
    String profileId,
    String projectId,
    ProjectPerson? after,
  ) {
    final current = participation?.creatorMembers.where((m) => m.isCurrent);
    final people = current == null
        ? rows
        : [
            const ProjectPerson(
              profileId: 'user-1',
              displayName: 'Casey',
              isCreator: true,
              roleRank: 0,
            ),
            for (final m in current)
              ProjectPerson(
                profileId: m.participantProfileId,
                displayName: m.participantDisplayName,
                isCreator: m.participantProfileId == 'user-1',
                roleRank: m.participantProfileId == 'user-1' ? 0 : 3,
                membershipId: m.id,
                joinedAt: m.joinedAt,
              ),
          ];
    final unique = {for (final p in people) p.profileId: p};
    return _page('people', unique.values.toList(), after, (p) => p.profileId);
  }

  @override
  Future<List<ManagerProjectJoinRequest>> requests(
    String profileId,
    String projectId,
    ManagerProjectJoinRequest? after,
  ) => _page(
    'requests',
    participation?.creatorRequests ?? requestRows,
    after,
    (r) => r.id,
  );
  @override
  Future<List<ManagerProjectMember>> history(
    String profileId,
    String projectId,
    ManagerProjectMember? after,
  ) => _page(
    'history',
    participation?.creatorMembers.where((m) => !m.isCurrent).toList() ??
        historyRows,
    after,
    (m) => m.id,
  );
  @override
  Future<List<ProjectRoleOffer>> offers(
    String profileId,
    String projectId,
    ProjectRoleOffer? after,
  ) => _page('offers', offerRows, after, (o) => o.id);
  Future<void> _mutate(String call) async {
    calls.add(call);
    if (delay case final wait?) await wait;
    if (error case final failure?) throw failure;
    await onMutation?.call();
  }

  @override
  Future<void> offer(
    String profileId,
    String projectId,
    String membershipId,
    ProjectDelegatedAuthorityRole role,
  ) => _mutate('offer:$profileId:$membershipId:${role.wireValue}');
  @override
  Future<void> respond(
    String profileId,
    String offerId, {
    required bool accept,
  }) => _mutate('${accept ? "accept" : "decline"}:$profileId:$offerId');
  @override
  Future<void> stepDown(String profileId, String delegateId) =>
      _mutate('step-down:$profileId:$delegateId');
}
