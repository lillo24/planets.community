import '../../proposals/domain/proposal_models.dart';

class TemplateCursor {
  const TemplateCursor(this.linkedAt, this.id);
  final DateTime linkedAt;
  final String id;
}

/// Only the canonical public card projection. No owner or baseline content.
class TemplateCard {
  const TemplateCard({
    required this.id,
    required this.sourceId,
    required this.linkedAt,
    required this.title,
    required this.summary,
    required this.skills,
    required this.creatorId,
    this.creatorName,
    this.coverPath,
  });
  final String id, sourceId, title, summary, creatorId;
  final DateTime linkedAt;
  final List<ProposalSkill> skills;
  final String? creatorName, coverPath;
  TemplateCursor get cursor => TemplateCursor(linkedAt, id);
}

class TemplateDetail {
  const TemplateDetail({
    required this.id,
    required this.sourceId,
    required this.token,
    required this.title,
    required this.summary,
    required this.description,
    required this.skills,
    required this.creatorId,
    required this.durationSeconds,
    required this.blueprintCount,
    this.creatorName,
    this.coverPath,
    this.capacity,
  });
  final String id, sourceId, token, title, summary, description, creatorId;
  final List<ProposalSkill> skills;
  final String? creatorName, coverPath;
  final int? capacity;
  final num durationSeconds;
  final int blueprintCount;
}

class TemplateBlueprint {
  const TemplateBlueprint(this.sourceNeedId, this.title, this.details);
  final String sourceNeedId, title, details;
}

/// Process-memory recovery contains opaque intent/IDs only, never copied text.
class TemplateAttempt {
  const TemplateAttempt({
    required this.actor,
    required this.templateId,
    required this.token,
    required this.prefillCapacity,
    required this.requestId,
    this.destinationId,
  });
  final String actor, templateId, token, requestId;
  final bool prefillCapacity;
  final String? destinationId;
  TemplateAttempt accepted(String id) => TemplateAttempt(
    actor: actor,
    templateId: templateId,
    token: token,
    prefillCapacity: prefillCapacity,
    requestId: requestId,
    destinationId: id,
  );
}

class TemplateReceipt {
  const TemplateReceipt({
    required this.requestId,
    required this.destinationId,
    required this.templateId,
    required this.sourceId,
    required this.token,
    required this.prefillCapacity,
    required this.durationSeconds,
    required this.acceptedAt,
    this.capacity,
  });
  final String requestId, destinationId, templateId, sourceId, token;
  final bool prefillCapacity;
  final int? capacity;
  final num durationSeconds;
  final DateTime acceptedAt;
}
