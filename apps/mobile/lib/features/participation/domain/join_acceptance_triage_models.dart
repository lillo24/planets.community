enum JoinAcceptanceSelectionKind {
  skill('skill'),
  resource('resource');

  const JoinAcceptanceSelectionKind(this.wireValue);

  final String wireValue;

  static JoinAcceptanceSelectionKind fromWire(String value) => switch (value) {
    'skill' => JoinAcceptanceSelectionKind.skill,
    'resource' => JoinAcceptanceSelectionKind.resource,
    _ => throw const FormatException(
      'Unsupported join-acceptance selection kind.',
    ),
  };
}

enum JoinAcceptanceDecision { needed, alreadyFound, extra }

class JoinAcceptanceItemKey {
  const JoinAcceptanceItemKey(this.kind, this.id);

  final JoinAcceptanceSelectionKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is JoinAcceptanceItemKey && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => '${kind.wireValue}:$id';
}

class JoinAcceptanceTriageItem {
  const JoinAcceptanceTriageItem({
    required this.kind,
    required this.id,
    required this.label,
    this.decision,
  });

  final JoinAcceptanceSelectionKind kind;
  final String id;
  final String label;
  final JoinAcceptanceDecision? decision;

  JoinAcceptanceItemKey get key => JoinAcceptanceItemKey(kind, id);

  JoinAcceptanceTriageItem withDecision(JoinAcceptanceDecision value) =>
      JoinAcceptanceTriageItem(
        kind: kind,
        id: id,
        label: label,
        decision: value,
      );
}
