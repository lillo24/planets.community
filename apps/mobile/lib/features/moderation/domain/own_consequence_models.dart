enum OwnConsequenceType {
  safetyNotice,
  interactionRestriction,
  contentHide,
  accountSuspension;

  static OwnConsequenceType fromWire(Object? value) => switch (value) {
    'safety_notice' => safetyNotice,
    'interaction_restriction' => interactionRestriction,
    'content_hide' => contentHide,
    'account_suspension' => accountSuspension,
    _ => throw const FormatException('Invalid notice type.'),
  };
}

class OwnConsequenceCursor {
  const OwnConsequenceCursor(this.appliedAt, this.consequenceId);

  // Keep the exact server timestamp, including all six fractional digits.
  // Display localization and DateTime serialization never define the cursor.
  final String appliedAt;
  final String consequenceId;
}

class OwnConsequence {
  const OwnConsequence({
    required this.id,
    required this.type,
    required this.isActive,
    required this.appliedAtWire,
    required this.appliedAt,
    required this.applyReason,
    this.revokedAt,
    this.revokeReason,
    this.contentKind,
    this.contentId,
    this.contentTitle,
  });

  factory OwnConsequence.fromJson(Map<String, dynamic> row) {
    const keys = {
      'consequence_id',
      'consequence_type',
      'is_active',
      'applied_at',
      'apply_reason',
      'revoked_at',
      'revoke_reason',
      'content_kind',
      'content_id',
      'content_title',
    };
    if (row.length != keys.length || !row.keys.toSet().containsAll(keys)) {
      throw const FormatException('Unexpected notice projection.');
    }
    final active = row['is_active'];
    final appliedWire = row['applied_at'];
    final applied = _time(appliedWire);
    final revoked = row['revoked_at'] == null ? null : _time(row['revoked_at']);
    final removedReason = row['revoke_reason'] == null
        ? null
        : _reason(row['revoke_reason']);
    if (active is! bool ||
        (active && (revoked != null || removedReason != null)) ||
        (!active && (revoked == null || removedReason == null)) ||
        (revoked != null && revoked.isBefore(applied))) {
      throw const FormatException('Invalid notice episode.');
    }
    final kind = row['content_kind'];
    final contentId = row['content_id'];
    final title = row['content_title'];
    if ((kind == null) != (contentId == null) ||
        (kind != null &&
            !{'one_time', 'recurring', 'resource_listing'}.contains(kind)) ||
        (title != null &&
            (kind == null ||
                title is! String ||
                title.trim().isEmpty ||
                title.runes.length > 200))) {
      throw const FormatException('Invalid notice content reference.');
    }
    return OwnConsequence(
      id: _uuid(row['consequence_id']),
      type: OwnConsequenceType.fromWire(row['consequence_type']),
      isActive: active,
      appliedAtWire: appliedWire as String,
      appliedAt: applied,
      applyReason: _reason(row['apply_reason']),
      revokedAt: revoked,
      revokeReason: removedReason,
      contentKind: kind as String?,
      contentId: contentId == null ? null : _uuid(contentId),
      contentTitle: title as String?,
    );
  }

  final String id;
  final OwnConsequenceType type;
  final bool isActive;
  final String appliedAtWire;
  final DateTime appliedAt;
  final String applyReason;
  final DateTime? revokedAt;
  final String? revokeReason;
  final String? contentKind;
  final String? contentId;
  final String? contentTitle;

  OwnConsequenceCursor get cursor => OwnConsequenceCursor(appliedAtWire, id);
}

class OwnConsequencePage {
  const OwnConsequencePage(this.items, {required this.hasMore});

  final List<OwnConsequence> items;
  final bool hasMore;
}

String _uuid(Object? value) {
  if (value is! String ||
      !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
          .hasMatch(value)) {
    throw const FormatException('Invalid notice identifier.');
  }
  return value.toLowerCase();
}

String _reason(Object? value) {
  if (value is! String || value.trim().isEmpty || value.runes.length > 2000) {
    throw const FormatException('Invalid notice reason.');
  }
  return value; // Staff's user-facing text stays verbatim; never trim/translate it.
}

DateTime _time(Object? value) {
  if (value is! String) throw const FormatException('Invalid notice date.');
  final parts = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (parts == null) throw const FormatException('Invalid notice date.');
  final values = [for (var i = 1; i <= 6; i++) int.parse(parts.group(i)!)];
  final calendar = DateTime.utc(values[0], values[1], values[2]);
  final zone = parts.group(7)!;
  if (calendar.year != values[0] ||
      calendar.month != values[1] ||
      calendar.day != values[2] ||
      values[3] > 23 ||
      values[4] > 59 ||
      values[5] > 59 ||
      (zone != 'Z' &&
          (int.parse(zone.substring(1, 3)) > 23 ||
              int.parse(zone.substring(4)) > 59))) {
    throw const FormatException('Invalid notice date.');
  }
  return DateTime.parse(value);
}
