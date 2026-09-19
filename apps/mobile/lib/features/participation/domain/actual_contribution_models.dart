enum ActualContributionKind {
  skill('skill'),
  resource('resource'),
  substantialEffort('substantial_effort');

  const ActualContributionKind(this.wireValue);

  final String wireValue;

  static ActualContributionKind fromWire(String value) => switch (value) {
    'skill' => ActualContributionKind.skill,
    'resource' => ActualContributionKind.resource,
    'substantial_effort' => ActualContributionKind.substantialEffort,
    _ => throw const FormatException('Unsupported actual contribution kind.'),
  };
}

enum ActualContributionSource {
  finalCommitment('final_commitment'),
  creatorAdded('creator_added'),
  substantialEffort('substantial_effort');

  const ActualContributionSource(this.wireValue);

  final String wireValue;

  static ActualContributionSource fromWire(String value) => switch (value) {
    'final_commitment' => ActualContributionSource.finalCommitment,
    'creator_added' => ActualContributionSource.creatorAdded,
    'substantial_effort' => ActualContributionSource.substantialEffort,
    _ => throw const FormatException('Unsupported actual contribution source.'),
  };
}

class ActualContribution {
  const ActualContribution({
    required this.kind,
    required this.id,
    required this.label,
    required this.source,
  });

  final ActualContributionKind kind;
  final String? id;
  final String? label;
  final ActualContributionSource source;

  String get key => switch (kind) {
    ActualContributionKind.skill ||
    ActualContributionKind.resource => '${kind.wireValue}:$id',
    ActualContributionKind.substantialEffort => kind.wireValue,
  };
}

class ActualContributionOption {
  const ActualContributionOption({
    required this.kind,
    required this.id,
    required this.label,
  });

  final ActualContributionKind kind;
  final String id;
  final String label;

  String get key => '${kind.wireValue}:$id';
}

class ActualContributionEditorItem {
  const ActualContributionEditorItem({
    required this.kind,
    required this.id,
    required this.label,
    required this.isSelected,
    required this.source,
  });

  final ActualContributionKind kind;
  final String id;
  final String label;
  final bool isSelected;
  final ActualContributionSource? source;
}
