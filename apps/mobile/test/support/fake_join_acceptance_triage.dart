import 'package:planets_mobile/features/participation/data/join_acceptance_triage_gateway.dart';
import 'package:planets_mobile/features/participation/domain/join_acceptance_triage_models.dart';

class FakeJoinAcceptanceTriageGateway implements JoinAcceptanceTriageGateway {
  List<JoinAcceptanceTriageItem> selections = [];
  Object? selectionError;
  Object? mutationError;
  void Function()? onAccepted;
  Future<void>? selectionDelay;
  Future<void>? mutationDelay;
  final List<String> calls = [];
  String? lastExpectedManagerProfileId;
  String? lastRequestId;
  Set<String> neededSkillIds = const {};
  Set<String> alreadyFoundSkillIds = const {};
  Set<String> extraSkillIds = const {};
  Set<String> neededResourceNeedIds = const {};
  Set<String> alreadyFoundResourceNeedIds = const {};
  Set<String> extraResourceNeedIds = const {};

  @override
  Future<List<JoinAcceptanceTriageItem>> listSelections({
    required String expectedManagerProfileId,
    required String requestId,
  }) async {
    calls.add('selections:$requestId');
    lastExpectedManagerProfileId = expectedManagerProfileId;
    lastRequestId = requestId;
    if (selectionDelay case final delay?) await delay;
    if (selectionError case final error?) throw error;
    return List.unmodifiable(selections);
  }

  @override
  Future<void> acceptWithTriage({
    required String expectedManagerProfileId,
    required String requestId,
    required Set<String> neededSkillIds,
    required Set<String> alreadyFoundSkillIds,
    required Set<String> extraSkillIds,
    required Set<String> neededResourceNeedIds,
    required Set<String> alreadyFoundResourceNeedIds,
    required Set<String> extraResourceNeedIds,
  }) async {
    calls.add('accept:$requestId');
    lastExpectedManagerProfileId = expectedManagerProfileId;
    lastRequestId = requestId;
    this.neededSkillIds = Set.unmodifiable(neededSkillIds);
    this.alreadyFoundSkillIds = Set.unmodifiable(alreadyFoundSkillIds);
    this.extraSkillIds = Set.unmodifiable(extraSkillIds);
    this.neededResourceNeedIds = Set.unmodifiable(neededResourceNeedIds);
    this.alreadyFoundResourceNeedIds = Set.unmodifiable(
      alreadyFoundResourceNeedIds,
    );
    this.extraResourceNeedIds = Set.unmodifiable(extraResourceNeedIds);
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final error?) throw error;
    onAccepted?.call();
  }
}

JoinAcceptanceTriageItem triageItemFixture({
  String id = 'skill-1',
  JoinAcceptanceSelectionKind kind = JoinAcceptanceSelectionKind.skill,
  String label = 'Carpentry',
}) => JoinAcceptanceTriageItem(kind: kind, id: id, label: label);
