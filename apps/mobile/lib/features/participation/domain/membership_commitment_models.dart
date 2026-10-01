enum MembershipCommitmentKind {
  skill('skill'),
  resource('resource');

  const MembershipCommitmentKind(this.wireValue);

  final String wireValue;

  static MembershipCommitmentKind fromWire(String value) => switch (value) {
    'skill' => MembershipCommitmentKind.skill,
    'resource' => MembershipCommitmentKind.resource,
    _ => throw const FormatException('Unsupported membership commitment kind.'),
  };
}

class MembershipCommitment {
  const MembershipCommitment({
    required this.id,
    required this.kind,
    required this.label,
  });

  final String id;
  final MembershipCommitmentKind kind;
  final String label;

  String get key => '${kind.wireValue}:$id';
}

class MembershipCommitmentOption {
  const MembershipCommitmentOption({
    required this.id,
    required this.kind,
    required this.label,
  });

  final String id;
  final MembershipCommitmentKind kind;
  final String label;

  String get key => '${kind.wireValue}:$id';
}

class MembershipCommitmentEditorItem {
  const MembershipCommitmentEditorItem({
    required this.id,
    required this.kind,
    required this.label,
    required this.isSelected,
    required this.isRetained,
  });

  final String id;
  final MembershipCommitmentKind kind;
  final String label;
  final bool isSelected;

  /// True when an authoritative options read proves this commitment is no
  /// longer among the addable options.
  final bool isRetained;
}
