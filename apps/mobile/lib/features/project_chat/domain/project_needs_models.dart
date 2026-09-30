import 'project_chat_models.dart';

enum ProjectRequirementImportance {
  required('required'),
  useful('useful');

  const ProjectRequirementImportance(this.wireValue);

  final String wireValue;

  static ProjectRequirementImportance fromWire(String value) => switch (value) {
    'required' => ProjectRequirementImportance.required,
    'useful' => ProjectRequirementImportance.useful,
    _ => throw const FormatException(
      'Unsupported Project requirement importance.',
    ),
  };
}

class ProjectLiveRequirement {
  const ProjectLiveRequirement({
    required this.kind,
    required this.id,
    required this.label,
    required this.importance,
    required this.isCovered,
    required this.viewerIsCovering,
    required this.isManuallyCovered,
  });

  final ProjectRequirementKind kind;
  final String id;
  final String label;
  final ProjectRequirementImportance? importance;
  final bool isCovered;
  final bool viewerIsCovering;
  final bool isManuallyCovered;

  String get canonicalKey => '${kind.wireValue}:$id';
}

class ProjectRequirementAttention {
  const ProjectRequirementAttention({
    required this.chatId,
    required this.hasUnseenResurfacedNeed,
    required this.latestUnseenEventId,
    required this.latestUnseenEventAt,
  });

  final String chatId;
  final bool hasUnseenResurfacedNeed;
  final String? latestUnseenEventId;
  final DateTime? latestUnseenEventAt;
}
