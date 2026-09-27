import 'package:planets_mobile/features/project_chat/data/project_needs_gateway.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';
import 'package:planets_mobile/features/project_chat/domain/project_needs_models.dart';

class FakeProjectNeedsGateway implements ProjectNeedsGateway {
  List<ProjectLiveRequirement> requirements = [];
  ProjectRequirementAttention attention = projectAttentionFixture();
  final List<String> calls = [];
  Object? coverageError;
  Object? attentionError;
  Object? actionError;
  Object? acknowledgeError;
  Future<void>? coverageDelay;
  Future<void>? attentionDelay;
  Future<void>? acknowledgeDelay;
  String? acknowledgedEventId;

  @override
  Future<List<ProjectLiveRequirement>> listCoverage({
    required String expectedProfileId,
    required String projectId,
  }) async {
    calls.add('coverage:$projectId');
    if (coverageDelay case final delay?) await delay;
    if (coverageError case final error?) throw error;
    return requirements;
  }

  @override
  Future<ProjectRequirementAttention> getAttention({
    required String expectedProfileId,
    required String projectId,
  }) async {
    calls.add('attention:$projectId');
    if (attentionDelay case final delay?) await delay;
    if (attentionError case final error?) throw error;
    return attention;
  }

  @override
  Future<void> claimRequirement({
    required String expectedParticipantProfileId,
    required String projectId,
    required ProjectRequirementKind kind,
    required String id,
  }) async {
    calls.add('claim:${kind.wireValue}:$id');
    if (actionError case final error?) throw error;
    requirements = [
      for (final requirement in requirements)
        if (requirement.kind == kind && requirement.id == id)
          projectRequirementFixture(
            kind: requirement.kind,
            id: requirement.id,
            label: requirement.label,
            importance: requirement.importance,
            isCovered: true,
            viewerIsCovering: true,
            isManuallyCovered: requirement.isManuallyCovered,
          )
        else
          requirement,
    ];
  }

  @override
  Future<void> setManualCoverage({
    required String expectedManagerProfileId,
    required String projectId,
    required ProjectRequirementKind kind,
    required String id,
    required bool isCovered,
  }) async {
    calls.add('manual:${kind.wireValue}:$id:$isCovered');
    if (actionError case final error?) throw error;
    requirements = [
      for (final requirement in requirements)
        if (requirement.kind == kind && requirement.id == id)
          projectRequirementFixture(
            kind: requirement.kind,
            id: requirement.id,
            label: requirement.label,
            importance: requirement.importance,
            isCovered: isCovered,
            isManuallyCovered: isCovered,
          )
        else
          requirement,
    ];
  }

  @override
  Future<void> acknowledgeAttention({
    required String expectedProfileId,
    required String projectId,
    required String throughSystemEventId,
  }) async {
    calls.add('ack:$throughSystemEventId');
    if (acknowledgeDelay case final delay?) await delay;
    if (acknowledgeError case final error?) throw error;
    acknowledgedEventId = throughSystemEventId;
    if (attention.latestUnseenEventId == throughSystemEventId) {
      attention = projectAttentionFixture();
    }
  }
}

ProjectLiveRequirement projectRequirementFixture({
  ProjectRequirementKind kind = ProjectRequirementKind.skill,
  String id = 'skill-1',
  String label = 'Painting',
  ProjectRequirementImportance? importance =
      ProjectRequirementImportance.required,
  bool isCovered = false,
  bool viewerIsCovering = false,
  bool isManuallyCovered = false,
}) => ProjectLiveRequirement(
  kind: kind,
  id: id,
  label: label,
  importance: kind == ProjectRequirementKind.resource ? null : importance,
  isCovered: isCovered,
  viewerIsCovering: viewerIsCovering,
  isManuallyCovered: isManuallyCovered,
);

ProjectRequirementAttention projectAttentionFixture({
  String chatId = 'chat-1',
  bool hasUnseen = false,
  String? eventId,
  DateTime? eventAt,
}) => ProjectRequirementAttention(
  chatId: chatId,
  hasUnseenResurfacedNeed: hasUnseen,
  latestUnseenEventId: hasUnseen ? eventId ?? 'event-1' : null,
  latestUnseenEventAt: hasUnseen
      ? eventAt ?? DateTime.utc(2026, 9, 18, 12)
      : null,
);
