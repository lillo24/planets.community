import 'dart:async';

import 'package:planets_mobile/features/participation/data/membership_commitment_gateway.dart';
import 'package:planets_mobile/features/participation/domain/membership_commitment_models.dart';

class FakeMembershipCommitmentGateway implements MembershipCommitmentGateway {
  List<MembershipCommitment> commitments = [];
  List<MembershipCommitmentOption> options = [];
  Object? readError;
  Object? optionsError;
  final List<Object> replaceErrors = [];
  Future<void>? readDelay;
  Future<void>? optionsDelay;
  Future<void>? replaceDelay;
  final List<String> calls = [];
  String? lastExpectedProfileId;
  String? lastMembershipId;
  Set<String> lastExpectedSkillIds = const {};
  Set<String> lastExpectedResourceNeedIds = const {};
  Set<String> lastSkillIds = const {};
  Set<String> lastResourceNeedIds = const {};

  @override
  Future<List<MembershipCommitment>> listCommitments({
    required String expectedProfileId,
    required String membershipId,
  }) async {
    calls.add('commitments:$membershipId');
    lastExpectedProfileId = expectedProfileId;
    lastMembershipId = membershipId;
    if (readDelay case final delay?) await delay;
    if (readError case final error?) throw error;
    return List.unmodifiable(commitments);
  }

  @override
  Future<List<MembershipCommitmentOption>> listOptions({
    required String expectedProfileId,
    required String membershipId,
  }) async {
    calls.add('options:$membershipId');
    lastExpectedProfileId = expectedProfileId;
    lastMembershipId = membershipId;
    if (optionsDelay case final delay?) await delay;
    if (optionsError case final error?) throw error;
    return List.unmodifiable(options);
  }

  @override
  Future<void> replaceCommitments({
    required String expectedActorProfileId,
    required String membershipId,
    required Set<String> expectedSkillIds,
    required Set<String> expectedResourceNeedIds,
    required Set<String> skillIds,
    required Set<String> resourceNeedIds,
  }) async {
    calls.add('replace:$membershipId');
    lastExpectedProfileId = expectedActorProfileId;
    lastMembershipId = membershipId;
    lastExpectedSkillIds = Set.unmodifiable(expectedSkillIds);
    lastExpectedResourceNeedIds = Set.unmodifiable(expectedResourceNeedIds);
    lastSkillIds = Set.unmodifiable(skillIds);
    lastResourceNeedIds = Set.unmodifiable(resourceNeedIds);
    if (replaceDelay case final delay?) await delay;
    if (replaceErrors.isNotEmpty) throw replaceErrors.removeAt(0);
    final labels = <String, String>{
      for (final item in commitments) item.key: item.label,
      for (final item in options) item.key: item.label,
    };
    commitments = [
      for (final id in skillIds)
        MembershipCommitment(
          id: id,
          kind: MembershipCommitmentKind.skill,
          label: labels['skill:$id'] ?? id,
        ),
      for (final id in resourceNeedIds)
        MembershipCommitment(
          id: id,
          kind: MembershipCommitmentKind.resource,
          label: labels['resource:$id'] ?? id,
        ),
    ];
  }
}

MembershipCommitment membershipCommitmentFixture({
  String id = 'skill-1',
  MembershipCommitmentKind kind = MembershipCommitmentKind.skill,
  String label = 'Carpentry',
}) => MembershipCommitment(id: id, kind: kind, label: label);

MembershipCommitmentOption membershipCommitmentOptionFixture({
  String id = 'skill-1',
  MembershipCommitmentKind kind = MembershipCommitmentKind.skill,
  String label = 'Carpentry',
}) => MembershipCommitmentOption(id: id, kind: kind, label: label);

Completer<void> pendingCommitmentOperation() => Completer<void>();
