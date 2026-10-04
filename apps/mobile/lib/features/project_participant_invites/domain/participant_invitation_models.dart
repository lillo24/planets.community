import '../../participation/domain/participation_models.dart';

enum ParticipantInviteFailure {
  unavailable,
  full,
  forbidden,
  profileRequired,
  invalidInput,
  network,
  malformed,
}

class ParticipantLink {
  const ParticipantLink({
    required this.id,
    required this.token,
    required this.createdAt,
  });
  final String id;
  final String token;
  final DateTime createdAt;
  String get url => 'https://planets.community/join/project/$token';
  @override
  String toString() => 'ParticipantLink(redacted)';
}

class ParticipantLinkHistory {
  const ParticipantLinkHistory({
    required this.id,
    required this.issuerId,
    required this.createdAt,
    this.revokedAt,
    this.revokerId,
    this.reason,
  });
  final String id;
  final String issuerId;
  final DateTime createdAt;
  final DateTime? revokedAt;
  final String? revokerId;
  final String? reason;
}

class ParticipantInvitePreview {
  const ParticipantInvitePreview({
    required this.available,
    this.projectId,
    this.kind,
    this.title,
  });
  final bool available;
  final String? projectId;
  final ProjectKind? kind;
  final String? title;
}

enum ParticipantAdmissionOutcome { joined, alreadyJoined, creator }

class ParticipantAdmissionResult {
  const ParticipantAdmissionResult({
    required this.projectId,
    required this.membershipId,
    required this.outcome,
    required this.status,
    required this.replayed,
  });
  final String projectId;
  final String? membershipId;
  final ParticipantAdmissionOutcome outcome;
  final MembershipStatus? status;
  final bool replayed;
}
