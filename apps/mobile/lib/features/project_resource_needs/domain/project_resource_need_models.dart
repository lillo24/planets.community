import '../../participation/domain/participation_models.dart';

const projectResourceNeedTitleMinLength = 2;
const projectResourceNeedTitleMaxLength = 160;
const projectResourceNeedDetailsMaxLength = 1000;

enum ProjectResourceNeedState {
  open('open'),
  closed('closed');

  const ProjectResourceNeedState(this.wireValue);

  final String wireValue;

  static ProjectResourceNeedState fromWire(String value) => switch (value) {
    'open' => ProjectResourceNeedState.open,
    'closed' => ProjectResourceNeedState.closed,
    _ => throw const FormatException(
      'Unsupported Project resource-need state.',
    ),
  };
}

class PublicProjectResourceNeed {
  const PublicProjectResourceNeed({
    required this.id,
    required this.title,
    required this.details,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? details;
  final DateTime createdAt;
}

class ProjectResourceNeed {
  const ProjectResourceNeed({
    required this.id,
    required this.projectId,
    required this.projectKind,
    required this.title,
    required this.details,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    required this.closedAt,
  });

  final String id;
  final String projectId;
  final ProjectKind projectKind;
  final String title;
  final String? details;
  final ProjectResourceNeedState state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;

  bool get isOpen => state == ProjectResourceNeedState.open;
}

class ProjectResourceNeedInput {
  const ProjectResourceNeedInput({required this.title, required this.details});

  final String title;
  final String details;

  bool get isValid {
    final titleLength = title.trim().length;
    return titleLength >= projectResourceNeedTitleMinLength &&
        titleLength <= projectResourceNeedTitleMaxLength &&
        details.trim().length <= projectResourceNeedDetailsMaxLength;
  }
}
