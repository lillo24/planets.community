import '../../groups/domain/group_models.dart';

enum GroupAuthority {
  creator,
  coCreator,
  coOrganizer;

  String get wire => switch (this) {
    creator => 'creator',
    coCreator => 'co_creator',
    coOrganizer => 'co_organizer',
  };
  bool get structural => this != coOrganizer;
  static GroupAuthority parse(Object? value) => switch (value) {
    'creator' => creator,
    'co_creator' => coCreator,
    'co_organizer' => coOrganizer,
    _ => throw const FormatException('Invalid group authority.'),
  };
}

T? groupNullable<T>(
  Map<String, dynamic> row,
  String key,
  T Function(Object?) parse,
) {
  if (!row.containsKey(key)) {
    throw const FormatException('Missing group relationship field.');
  }
  return row[key] == null ? null : parse(row[key]);
}

String groupState(Object? value, Set<String> allowed) {
  if (value is! String || !allowed.contains(value)) {
    throw const FormatException('Invalid group relationship state.');
  }
  return value;
}

const groupRequestStates = {'pending', 'accepted', 'rejected', 'withdrawn'};
const groupMemberStates = {'current', 'left', 'removed'};
const groupInviteStates = {
  'pending',
  'accepted',
  'declined',
  'revoked',
  'expired',
};

class GroupSelfContext {
  GroupSelfContext(Map<String, dynamic> row)
    : authority = groupNullable(row, 'authority_role', GroupAuthority.parse),
      delegateId = groupNullable(row, 'delegate_id', groupUuid),
      membershipId = groupNullable(row, 'current_membership_id', groupUuid),
      membershipStatus = groupNullable(
        row,
        'membership_status',
        (v) => groupState(v, groupMemberStates),
      ),
      pendingRequestId = groupNullable(row, 'pending_request_id', groupUuid),
      pendingNote = groupNullable(
        row,
        'pending_note',
        (v) => groupText(v, 500),
      ),
      latestRequestId = groupNullable(row, 'latest_request_id', groupUuid),
      latestRequestStatus = groupNullable(
        row,
        'latest_request_status',
        (v) => groupState(v, groupRequestStates),
      ),
      latestMembershipId = groupNullable(
        row,
        'latest_membership_id',
        groupUuid,
      ),
      latestMembershipStatus = groupNullable(
        row,
        'latest_membership_status',
        (v) => groupState(v, groupMemberStates),
      ) {
    if ((membershipId == null) != (membershipStatus == null) ||
        (authority == GroupAuthority.creator && delegateId != null) ||
        (authority != null &&
            authority != GroupAuthority.creator &&
            delegateId == null)) {
      throw const FormatException('Inconsistent own group state.');
    }
  }
  final GroupAuthority? authority;
  final String? delegateId,
      membershipId,
      membershipStatus,
      pendingRequestId,
      pendingNote,
      latestRequestId,
      latestRequestStatus,
      latestMembershipId,
      latestMembershipStatus;
  bool get manager => authority != null;
  bool get structural => authority?.structural == true;
  bool get people => manager || membershipId != null;
}

class GroupRelationshipReceipt {
  GroupRelationshipReceipt(Map<String, dynamic> row)
    : groupId = groupUuid(row['group_id']),
      id = groupNullable(row, 'relationship_id', groupUuid),
      kind = groupState(row['relationship_kind'], {
        'creator',
        'request',
        'membership',
        'delegate',
        'authority_invitation',
        'participant_invitation',
      }),
      outcome = groupState(row['outcome'], {
        'requested',
        'withdrawn',
        'joined',
        'rejected',
        'left',
        'removed',
        'current',
        'revoked',
        'already_joined',
        'creator',
        'offered',
        'accepted',
        'declined',
        'co_creator',
        'co_organizer',
      }),
      currentStatus = groupNullable(
        row,
        'current_status',
        (v) => groupState(v, {
          ...groupRequestStates,
          ...groupMemberStates,
          ...groupInviteStates,
          'co_creator',
          'co_organizer',
        }),
      ),
      replayed = groupBool(row['replayed']),
      expiresAt = groupNullable(row, 'expires_at', groupDate),
      token = row.containsKey('invite_token')
          ? groupNullable(row, 'invite_token', groupToken)
          : null;
  final String groupId, kind, outcome;
  final String? id, currentStatus, token;
  final DateTime? expiresAt;
  final bool replayed;
  @override
  String toString() => 'GroupRelationshipReceipt(redacted)';
}

String groupToken(Object? value) {
  if (value is! String || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value)) {
    throw const FormatException('Invalid group capability.');
  }
  return value;
}

class GroupInvitePreview {
  GroupInvitePreview(Map<String, dynamic> row, {required bool authority})
    : available = groupBool(row['available']),
      groupId = groupNullable(row, 'group_id', groupUuid),
      name = groupNullable(row, 'group_name', (v) => groupText(v, 120)),
      kind = groupNullable(row, 'group_kind', GroupKind.parse),
      role = authority
          ? groupNullable(row, 'offered_role', GroupAuthority.parse)
          : null,
      expiresAt = authority
          ? groupNullable(row, 'expires_at', groupDate)
          : null {
    if (available != (groupId != null && name != null && kind != null) ||
        (authority &&
            available &&
            (role == null ||
                role == GroupAuthority.creator ||
                expiresAt == null)) ||
        (!available &&
            [groupId, name, kind, role, expiresAt].any((v) => v != null))) {
      throw const FormatException('Inconsistent group invitation preview.');
    }
  }
  final bool available;
  final String? groupId, name;
  final GroupKind? kind;
  final GroupAuthority? role;
  final DateTime? expiresAt;
  String get consentVersion =>
      '$groupId/${role?.wire}/${expiresAt?.toUtc().toIso8601String()}';
}

class GroupSharingLink {
  GroupSharingLink(Map<String, dynamic> row)
    : id = groupUuid(row['invitation_id']),
      token = groupNullable(row, 'invite_token', groupToken),
      createdAt = groupDate(row['created_at']),
      revokedAt = groupNullable(row, 'revoked_at', groupDate);
  final String id;
  final String? token;
  final DateTime createdAt;
  final DateTime? revokedAt;
  @override
  String toString() => 'GroupSharingLink(redacted)';
}

abstract interface class GroupPageRow {
  String get id;
  Map<String, dynamic> get cursor;
}

class GroupPerson implements GroupPageRow {
  GroupPerson(Map<String, dynamic> row)
    : id = groupUuid(row['profile_id']),
      name = groupText(row['display_name'], 120),
      creator = groupBool(row['is_creator']),
      authority = groupNullable(row, 'authority_role', GroupAuthority.parse),
      delegateId = groupNullable(row, 'delegate_id', groupUuid),
      membershipId = groupNullable(row, 'current_membership_id', groupUuid),
      joinedAt = groupNullable(row, 'joined_at', groupDate),
      rank = groupRank(row['role_rank']) {
    if (rank < 0 ||
        rank > 3 ||
        rank !=
            (authority == null
                ? 3
                : GroupAuthority.values.indexOf(authority!))) {
      throw const FormatException('Invalid People order.');
    }
  }
  @override
  final String id;
  final String name;
  final bool creator;
  final GroupAuthority? authority;
  final String? delegateId, membershipId;
  final DateTime? joinedAt;
  final int rank;
  @override
  Map<String, dynamic> get cursor => {
    'p_after_role_rank': rank,
    'p_after_profile_id': id,
  };
}

enum GroupHistoryKind {
  requests,
  memberships,
  delegates,
  offers,
  roleChanges,
  links,
  managed,
}

/// Each family has its own allowlisted SQL projection; nullable values are
/// required keys. The UI never receives raw arbitrary JSON or private profiles.
class GroupHistoryRow implements GroupPageRow {
  GroupHistoryRow(Map<String, dynamic> row, this.family) {
    final spec = switch (family) {
      GroupHistoryKind.requests => ('request_id', 'created_at'),
      GroupHistoryKind.memberships => ('membership_id', 'joined_at'),
      GroupHistoryKind.delegates => ('delegate_id', 'granted_at'),
      GroupHistoryKind.offers ||
      GroupHistoryKind.links => ('invitation_id', 'created_at'),
      GroupHistoryKind.roleChanges => ('change_id', 'created_at'),
      GroupHistoryKind.managed => ('group_id', 'created_at'),
    };
    id = groupUuid(row[spec.$1]);
    createdAt = groupDate(row[spec.$2]);
    timeParameter = 'p_before_${spec.$2}';
    groupId =
        family == GroupHistoryKind.delegates ||
            family == GroupHistoryKind.roleChanges ||
            family == GroupHistoryKind.links
        ? null
        : groupUuid(row['group_id']);
    switch (family) {
      case GroupHistoryKind.requests:
        personId = groupUuid(row['requester_profile_id']);
        name = groupNullable(
          row,
          'requester_display_name',
          (v) => groupText(v, 120),
        );
        note = groupNullable(row, 'note', (v) => groupText(v, 500));
        status = groupState(row['status'], groupRequestStates);
        resolvedAt = groupNullable(row, 'resolved_at', groupDate);
        actorId = groupNullable(row, 'resolved_by_profile_id', groupUuid);
        reason = groupNullable(
          row,
          'resolution_reason',
          (v) => groupText(v, 80),
        );
        relatedId = groupNullable(
          row,
          'superseded_by_membership_id',
          groupUuid,
        );
      case GroupHistoryKind.memberships:
        personId = groupUuid(row['profile_id']);
        name = groupNullable(row, 'display_name', (v) => groupText(v, 120));
        status = groupState(row['membership_status'], groupMemberStates);
        resolvedAt = groupNullable(row, 'ended_at', groupDate);
        actorId = groupNullable(row, 'admitted_by_profile_id', groupUuid);
        endActorId = groupNullable(row, 'ended_by_profile_id', groupUuid);
        relatedId = groupNullable(row, 'originating_request_id', groupUuid);
      case GroupHistoryKind.delegates:
        personId = groupUuid(row['profile_id']);
        name = groupNullable(row, 'display_name', (v) => groupText(v, 120));
        role = GroupAuthority.parse(row['delegate_role']);
        initialRole = GroupAuthority.parse(row['initial_role']);
        actorId = groupUuid(row['granted_by_profile_id']);
        resolvedAt = groupNullable(row, 'revoked_at', groupDate);
        endActorId = groupNullable(row, 'revoked_by_profile_id', groupUuid);
        status = resolvedAt == null ? 'current' : 'revoked';
      case GroupHistoryKind.offers:
        personId = groupNullable(row, 'target_profile_id', groupUuid);
        role = GroupAuthority.parse(row['offered_role']);
        status = groupState(row['status'], groupInviteStates);
        actorId = groupUuid(row['issuer_profile_id']);
        relatedId = groupNullable(row, 'target_membership_id', groupUuid);
        expiresAt = groupDate(row['expires_at']);
        resolvedAt = groupNullable(row, 'resolved_at', groupDate);
        endActorId = groupNullable(row, 'resolved_by_profile_id', groupUuid);
        acceptedId = groupNullable(row, 'accepted_delegate_id', groupUuid);
      case GroupHistoryKind.roleChanges:
        relatedId = groupUuid(row['delegate_id']);
        initialRole = GroupAuthority.parse(row['from_role']);
        role = GroupAuthority.parse(row['to_role']);
        actorId = groupUuid(row['actor_profile_id']);
      case GroupHistoryKind.links:
        actorId = groupUuid(row['issuer_profile_id']);
        resolvedAt = groupNullable(row, 'revoked_at', groupDate);
        endActorId = groupNullable(row, 'revoked_by_profile_id', groupUuid);
        status = resolvedAt == null ? 'current' : 'revoked';
      case GroupHistoryKind.managed:
        name = groupText(row['name'], 120);
        role = GroupAuthority.parse(row['authority_role']);
        publication = GroupPublication.parse(row['publication_state']);
        kind = GroupKind.parse(row['group_kind']);
        suppressed = groupBool(row['directory_suppressed']);
    }
  }
  final GroupHistoryKind family;
  @override
  late final String id;
  late final DateTime createdAt;
  late final String timeParameter;
  late final String? groupId;
  String? personId,
      name,
      note,
      status,
      actorId,
      endActorId,
      reason,
      relatedId,
      acceptedId;
  GroupAuthority? role, initialRole;
  GroupPublication? publication;
  GroupKind? kind;
  bool? suppressed;
  DateTime? expiresAt, resolvedAt;
  @override
  Map<String, dynamic> get cursor => {
    timeParameter: createdAt.toUtc().toIso8601String(),
    'p_before_id': id,
  };
}

int groupRank(Object? value) {
  if (value is! int || value < 0 || value > 3) {
    throw const FormatException('Invalid People order.');
  }
  return value;
}
