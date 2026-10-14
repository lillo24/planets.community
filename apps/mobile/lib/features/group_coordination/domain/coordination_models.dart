import 'dart:convert';

import '../../group_contact/domain/group_contact_models.dart';

int coordinationVersion(Object? value) {
  if (value is! int || value < 1) {
    throw const FormatException('Malformed audience version.');
  }
  return value;
}

List<T> coordinationList<T>(
  Object? value,
  T Function(Object?) parse, {
  int max = 5,
}) {
  if (value is! List || value.length > max) {
    throw const FormatException('Unbounded coordination audience.');
  }
  return List.unmodifiable(value.map(parse));
}

class CoordinationGroup {
  const CoordinationGroup(this.id, this.name, this.claimed);
  final String id, name;
  final bool claimed;
  factory CoordinationGroup.parse(Object? value) {
    final r = contactRow(value, const {'group_id', 'group_name', 'is_claimed'});
    return CoordinationGroup(
      contactUuid(r['group_id']),
      contactText(r['group_name'], 120),
      contactBool(r['is_claimed']),
    );
  }
}

class CoordinationPerson {
  const CoordinationPerson(this.person, this.confirmed);
  final ContactParticipant person;
  final bool confirmed;
  factory CoordinationPerson.parse(Object? value) {
    final r = contactRow(value, const {
      'profile_id',
      'group_id',
      'group_name',
      'display_name',
      'confirmed',
      'active',
    });
    return CoordinationPerson(
      ContactParticipant.parse({...r}..remove('confirmed')),
      contactBool(r['confirmed']),
    );
  }
}

class CoordinationProposal {
  const CoordinationProposal({
    required this.id,
    required this.viewerRole,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.activityAt,
    required this.expiresAt,
    this.resolvedAt,
    this.title,
    this.note,
    this.initiatorId,
    this.initiatorName,
    this.ownGroupId,
    this.sourceChatId,
    this.chatId,
    required this.groups,
    required this.audience,
    required this.claimableGroupIds,
    required this.audienceDisclosed,
    required this.allSeatsNamed,
    required this.ownConfirmed,
    required this.canConfirm,
    required this.canChangeAudience,
    required this.canCancel,
    required this.canDecline,
  });
  final String id, viewerRole, status;
  final int version;
  final DateTime createdAt, activityAt, expiresAt;
  final DateTime? resolvedAt;
  final String? title,
      note,
      initiatorId,
      initiatorName,
      ownGroupId,
      sourceChatId,
      chatId;
  final List<CoordinationGroup> groups;
  final List<CoordinationPerson> audience;
  final List<String> claimableGroupIds;
  final bool audienceDisclosed,
      allSeatsNamed,
      ownConfirmed,
      canConfirm,
      canChangeAudience,
      canCancel,
      canDecline;
  Object get refreshValue => jsonEncode({
    'version': version,
    'status': status,
    'title': title,
    'note': note,
    'initiator': initiatorId,
    'name': initiatorName,
    'own': ownGroupId,
    'source': sourceChatId,
    'chat': chatId,
    'claimable': claimableGroupIds,
    'groups': groups.map((g) => [g.id, g.name, g.claimed]).toList(),
    'audience': audience
        .map(
          (a) => [
            a.person.profileId,
            a.person.groupId,
            a.person.groupName,
            a.person.displayName,
            a.person.active,
            a.confirmed,
          ],
        )
        .toList(),
    'flags': [
      audienceDisclosed,
      allSeatsNamed,
      ownConfirmed,
      canConfirm,
      canChangeAudience,
      canCancel,
      canDecline,
    ],
  });
  factory CoordinationProposal.parse(Object? value) {
    final r = contactRow(value, const {
      'item_kind',
      'proposal_id',
      'viewer_role',
      'status',
      'version',
      'created_at',
      'activity_at',
      'expires_at',
      'resolved_at',
      'title',
      'request_message',
      'requester_profile_id',
      'requester_display_name',
      'groups',
      'audience',
      'audience_disclosed',
      'all_seats_named',
      'claimable_group_ids',
      'own_group_id',
      'own_confirmed',
      'can_confirm',
      'can_change_audience',
      'can_cancel',
      'can_decline',
      'source_chat_id',
      'chat_id',
    });
    if (r['item_kind'] != 'group_coordination_proposal' ||
        !{'requester', 'delegate'}.contains(r['viewer_role']) ||
        !{
          'pending',
          'active',
          'declined',
          'canceled',
          'expired',
        }.contains(r['status'])) {
      throw const FormatException('Unsupported coordination state.');
    }
    final groups = coordinationList(r['groups'], CoordinationGroup.parse),
        audience = coordinationList(r['audience'], CoordinationPerson.parse);
    final claims = coordinationList(
      r['claimable_group_ids'],
      contactUuid,
      max: 3,
    );
    final disclosed = contactBool(r['audience_disclosed']),
        note = contactOptionalText(r['request_message'], 1000);
    if (groups.map((g) => g.id).toSet().length != groups.length ||
        audience.map((a) => a.person.profileId).toSet().length !=
            audience.length ||
        audience.map((a) => a.person.groupId).toSet().length !=
            audience.length ||
        audience.any((a) => !groups.any((g) => g.id == a.person.groupId)) ||
        claims.toSet().length != claims.length ||
        claims.any((id) => !groups.any((g) => g.id == id)) ||
        (!disclosed && audience.isNotEmpty) ||
        (note == null &&
            (groups.isNotEmpty ||
                audience.isNotEmpty ||
                claims.isNotEmpty ||
                disclosed)) ||
        (note != null && groups.length < 3) ||
        (r['can_confirm'] == true &&
            (!disclosed ||
                audience.length != groups.length ||
                r['own_group_id'] == null)) ||
        (r['chat_id'] != null && r['status'] != 'active') ||
        (r['source_chat_id'] != null && note == null)) {
      throw const FormatException('Mixed coordination disclosure.');
    }
    return CoordinationProposal(
      id: contactUuid(r['proposal_id']),
      viewerRole: r['viewer_role'] as String,
      status: r['status'] as String,
      version: coordinationVersion(r['version']),
      createdAt: contactDate(r['created_at']),
      activityAt: contactDate(r['activity_at']),
      expiresAt: contactDate(r['expires_at']),
      resolvedAt: contactOptionalDate(r['resolved_at']),
      title: contactOptionalText(r['title'], 120),
      note: note,
      initiatorId: contactOptionalUuid(r['requester_profile_id']),
      initiatorName: contactOptionalText(r['requester_display_name'], 120),
      ownGroupId: contactOptionalUuid(r['own_group_id']),
      sourceChatId: contactOptionalUuid(r['source_chat_id']),
      chatId: contactOptionalUuid(r['chat_id']),
      groups: groups,
      audience: audience,
      claimableGroupIds: claims,
      audienceDisclosed: disclosed,
      allSeatsNamed: contactBool(r['all_seats_named']),
      ownConfirmed: contactBool(r['own_confirmed']),
      canConfirm: contactBool(r['can_confirm']),
      canChangeAudience: contactBool(r['can_change_audience']),
      canCancel: contactBool(r['can_cancel']),
      canDecline: contactBool(r['can_decline']),
    );
  }
}
