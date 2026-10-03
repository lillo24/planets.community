import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';

import '../../../support/fake_participation.dart';

void main() {
  group('participation wire enums', () {
    test('parse both project kinds and every lifecycle status', () {
      expect(ProjectKind.fromWire('one_time'), ProjectKind.oneTime);
      expect(ProjectKind.fromWire('recurring'), ProjectKind.recurring);
      expect(JoinRequestStatus.fromWire('pending'), JoinRequestStatus.pending);
      expect(
        JoinRequestStatus.fromWire('accepted'),
        JoinRequestStatus.accepted,
      );
      expect(
        JoinRequestStatus.fromWire('rejected'),
        JoinRequestStatus.rejected,
      );
      expect(
        JoinRequestStatus.fromWire('withdrawn'),
        JoinRequestStatus.withdrawn,
      );
      expect(MembershipStatus.fromWire('current'), MembershipStatus.current);
      expect(MembershipStatus.fromWire('left'), MembershipStatus.left);
      expect(MembershipStatus.fromWire('removed'), MembershipStatus.removed);
    });

    test('unknown wire values fail closed', () {
      expect(() => ProjectKind.fromWire('proposal'), throwsFormatException);
      expect(
        () => JoinRequestStatus.fromWire('approved'),
        throwsFormatException,
      );
      expect(
        () => MembershipStatus.fromWire('verified'),
        throwsFormatException,
      );
    });
  });

  group('ParticipationPayloadParser', () {
    const parser = ParticipationPayloadParser();

    test('direct invitation episodes have no originating request', () {
      final own = parser.ownMembership({
        'membership_id': 'membership-invite',
        'project_id': 'proposal-1',
        'project_kind': 'one_time',
        'originating_request_id': null,
        'membership_status': 'current',
        'joined_at': '2026-10-03T10:00:00Z',
        'left_at': null,
        'removed_at': null,
      });
      final managed = parser.managerMember({
        'membership_id': 'membership-invite',
        'participant_profile_id': 'user-2',
        'participant_display_name': 'Recipient',
        'originating_request_id': null,
        'membership_status': 'left',
        'joined_at': '2026-10-03T10:00:00Z',
        'left_at': '2026-10-03T12:00:00Z',
        'removed_at': null,
        'removed_by_profile_id': null,
      });
      expect(own.originatingRequestId, isNull);
      expect(own.isCurrent, isTrue);
      expect(managed.originatingRequestId, isNull);
      expect(managed.status, MembershipStatus.left);
    });

    test('parses nullable messages and timestamps', () {
      final request = parser.ownJoinRequest({
        'request_id': 'request-1',
        'project_id': 'proposal-1',
        'project_kind': 'one_time',
        'status': 'pending',
        'request_message': null,
        'created_at': '2026-09-08T10:00:00Z',
        'resolved_at': null,
      });
      final membership = parser.ownMembership({
        'membership_id': 'membership-1',
        'project_id': 'tavolo-1',
        'project_kind': 'recurring',
        'originating_request_id': 'request-1',
        'membership_status': 'removed',
        'joined_at': '2026-09-08T10:00:00Z',
        'left_at': null,
        'removed_at': '2026-09-08T12:00:00Z',
      });

      expect(request.message, isNull);
      expect(request.resolvedAt, isNull);
      expect(request.createdAt, DateTime.utc(2026, 9, 8, 10));
      expect(membership.projectKind, ProjectKind.recurring);
      expect(membership.status, MembershipStatus.removed);
      expect(membership.removedAt, DateTime.utc(2026, 9, 8, 12));
    });

    test('parses creator review and protected meeting rows', () {
      final request = parser.managerJoinRequest({
        'request_id': 'request-1',
        'requester_profile_id': 'user-2',
        'requester_display_name': 'Jordan',
        'requester_is_organizer': false,
        'status': 'accepted',
        'request_message': 'Private context',
        'created_at': '2026-09-08T10:00:00Z',
        'resolved_at': '2026-09-08T11:00:00Z',
        'resolved_by_profile_id': 'user-1',
      });
      final member = parser.managerMember({
        'membership_id': 'membership-1',
        'participant_profile_id': 'user-2',
        'participant_display_name': 'Jordan',
        'originating_request_id': 'request-1',
        'membership_status': 'current',
        'joined_at': '2026-09-08T11:00:00Z',
        'left_at': null,
        'removed_at': null,
        'removed_by_profile_id': null,
      });
      final meeting = parser.meetingDetails({
        'project_id': 'proposal-1',
        'project_kind': 'one_time',
        'exact_meeting_text': 'Private meeting text',
        'exact_location': 'POINT(1 2)',
      });

      expect(request.message, 'Private context');
      expect(request.requesterIsOrganizer, isFalse);
      expect(request.resolvedByProfileId, 'user-1');
      expect(member.isCurrent, isTrue);
      expect(meeting.exactMeetingText, 'Private meeting text');
      expect(meeting.exactLocation, 'POINT(1 2)');
    });

    test('malformed rows fail instead of returning success-shaped data', () {
      expect(() => parser.ownJoinRequest('not-a-row'), throwsFormatException);
      expect(
        () => parser.ownJoinRequest({
          'request_id': 'request-1',
          'project_id': 'proposal-1',
          'project_kind': 'invalid',
          'status': 'pending',
          'request_message': null,
          'created_at': '2026-09-08T10:00:00Z',
          'resolved_at': null,
        }),
        throwsFormatException,
      );
      expect(
        () => parser.meetingDetails({
          'project_id': 'proposal-1',
          'project_kind': 'one_time',
          'exact_meeting_text': null,
          'exact_location': null,
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('resolveProjectParticipation', () {
    test('selects current state independently for each concrete kind', () {
      final result = resolveProjectParticipation(
        projectId: 'shared-id',
        projectKind: ProjectKind.oneTime,
        requests: [
          ownJoinRequestFixture(
            id: 'wrong-kind',
            projectId: 'shared-id',
            projectKind: ProjectKind.recurring,
          ),
          ownJoinRequestFixture(
            id: 'old',
            projectId: 'shared-id',
            status: JoinRequestStatus.rejected,
            createdAt: DateTime.utc(2026, 9, 1),
          ),
          ownJoinRequestFixture(
            id: 'pending',
            projectId: 'shared-id',
            createdAt: DateTime.utc(2026, 9, 2),
          ),
        ],
        memberships: [
          ownMembershipFixture(
            id: 'left',
            projectId: 'shared-id',
            status: MembershipStatus.left,
          ),
        ],
      );

      expect(result.latestRequest?.id, 'pending');
      expect(result.pendingRequest?.id, 'pending');
      expect(result.currentMembership, isNull);
      expect(result.canRequest, isFalse);
    });

    test('terminal request and left/removed membership allow retry', () {
      for (final membershipStatus in [
        MembershipStatus.left,
        MembershipStatus.removed,
      ]) {
        final result = resolveProjectParticipation(
          projectId: 'proposal-1',
          projectKind: ProjectKind.oneTime,
          requests: [
            ownJoinRequestFixture(status: JoinRequestStatus.withdrawn),
          ],
          memberships: [ownMembershipFixture(status: membershipStatus)],
        );
        expect(result.currentMembership, isNull);
        expect(result.canRequest, isTrue);
      }
    });

    test('current membership prevents a duplicate request', () {
      final result = resolveProjectParticipation(
        projectId: 'proposal-1',
        projectKind: ProjectKind.oneTime,
        requests: const [],
        memberships: [ownMembershipFixture()],
      );

      expect(result.currentMembership?.id, 'membership-1');
      expect(result.canRequest, isFalse);
    });
  });
}
