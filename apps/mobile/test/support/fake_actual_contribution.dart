import 'dart:async';

import 'package:planets_mobile/features/participation/data/actual_contribution_gateway.dart';
import 'package:planets_mobile/features/participation/domain/actual_contribution_models.dart';

class FakeActualContributionGateway implements ActualContributionGateway {
  List<ActualContribution> contributions = [];
  List<ActualContributionOption> options = [];
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
  bool? lastExpectedSubstantialEffort;
  Set<String> lastSkillIds = const {};
  Set<String> lastResourceNeedIds = const {};
  bool? lastSubstantialEffort;

  @override
  Future<List<ActualContribution>> listActualContributions({
    required String expectedProfileId,
    required String membershipId,
  }) async {
    calls.add('contributions:$membershipId');
    lastExpectedProfileId = expectedProfileId;
    lastMembershipId = membershipId;
    if (readDelay case final delay?) await delay;
    if (readError case final error?) throw error;
    return List.unmodifiable(contributions);
  }

  @override
  Future<List<ActualContributionOption>> listActualContributionOptions({
    required String expectedCreatorProfileId,
    required String membershipId,
  }) async {
    calls.add('options:$membershipId');
    lastExpectedProfileId = expectedCreatorProfileId;
    lastMembershipId = membershipId;
    if (optionsDelay case final delay?) await delay;
    if (optionsError case final error?) throw error;
    return List.unmodifiable(options);
  }

  @override
  Future<void> replaceActualContributions({
    required String expectedCreatorProfileId,
    required String membershipId,
    required Set<String> expectedSkillIds,
    required Set<String> expectedResourceNeedIds,
    required bool expectedSubstantialEffort,
    required Set<String> skillIds,
    required Set<String> resourceNeedIds,
    required bool substantialEffort,
  }) async {
    calls.add('replace:$membershipId');
    lastExpectedProfileId = expectedCreatorProfileId;
    lastMembershipId = membershipId;
    lastExpectedSkillIds = Set.unmodifiable(expectedSkillIds);
    lastExpectedResourceNeedIds = Set.unmodifiable(expectedResourceNeedIds);
    lastExpectedSubstantialEffort = expectedSubstantialEffort;
    lastSkillIds = Set.unmodifiable(skillIds);
    lastResourceNeedIds = Set.unmodifiable(resourceNeedIds);
    lastSubstantialEffort = substantialEffort;
    if (replaceDelay case final delay?) await delay;
    if (replaceErrors.isNotEmpty) throw replaceErrors.removeAt(0);
    final labels = <String, String>{
      for (final item in contributions)
        if (item.id != null && item.label != null) item.key: item.label!,
      for (final item in options) item.key: item.label,
    };
    contributions = [
      for (final id in skillIds)
        actualContributionFixture(
          id: id,
          label: labels['skill:$id'] ?? id,
          source: ActualContributionSource.creatorAdded,
        ),
      for (final id in resourceNeedIds)
        actualContributionFixture(
          id: id,
          kind: ActualContributionKind.resource,
          label: labels['resource:$id'] ?? id,
          source: ActualContributionSource.creatorAdded,
        ),
      if (substantialEffort) substantialEffortFixture(),
    ];
  }
}

ActualContribution actualContributionFixture({
  String id = 'skill-1',
  ActualContributionKind kind = ActualContributionKind.skill,
  String label = 'Carpentry',
  ActualContributionSource source = ActualContributionSource.finalCommitment,
}) => ActualContribution(kind: kind, id: id, label: label, source: source);

ActualContribution substantialEffortFixture() => const ActualContribution(
  kind: ActualContributionKind.substantialEffort,
  id: null,
  label: null,
  source: ActualContributionSource.substantialEffort,
);

ActualContributionOption actualContributionOptionFixture({
  String id = 'skill-1',
  ActualContributionKind kind = ActualContributionKind.skill,
  String label = 'Carpentry',
}) => ActualContributionOption(kind: kind, id: id, label: label);

Completer<void> pendingActualContributionOperation() => Completer<void>();
