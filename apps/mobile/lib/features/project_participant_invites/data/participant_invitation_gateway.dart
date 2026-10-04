import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../participation/domain/participation_models.dart';
import '../domain/participant_invitation_models.dart';

abstract interface class ParticipantInvitationGateway {
  Future<ParticipantInvitePreview> preview(String token);
  Future<ParticipantAdmissionResult> accept(
    String profileId,
    String token,
    String actionId,
  );
  Future<ParticipantLink?> current(String profileId, String projectId);
  Future<ParticipantLink> create(String profileId, String projectId);
  Future<ParticipantLink> regenerate(String profileId, String projectId);
  Future<void> revoke(String profileId, String projectId, String invitationId);
  Future<List<ParticipantLinkHistory>> history(
    String profileId,
    String projectId, {
    ParticipantLinkHistory? before,
  });
  Future<String?> currentChat(String profileId, String projectId);
}

class ParticipantInvitationParser {
  const ParticipantInvitationParser();
  static final tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
  Map<String, dynamic> _row(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Participant invitation row is malformed.');
    }
    return value;
  }

  Map<String, dynamic> _single(Object? value) {
    if (value is! List || value.length != 1) {
      throw const FormatException(
        'Expected one participant invitation result.',
      );
    }
    return _row(value.single);
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid participant invitation $key.');
    }
    return value;
  }

  DateTime _date(Map<String, dynamic> row, String key) {
    final value = DateTime.tryParse(_string(row, key));
    if (value == null) {
      throw FormatException('Invalid participant invitation $key timestamp.');
    }
    return value;
  }

  ParticipantInvitePreview preview(Object? response) {
    final row = _single(response);
    if (row['available'] is! bool) {
      throw const FormatException(
        'Invalid participant invitation availability.',
      );
    }
    if (row['available'] == false) {
      if ([
        'project_id',
        'project_kind',
        'project_title',
      ].any((key) => !row.containsKey(key) || row[key] != null)) {
        throw const FormatException(
          'Unavailable participant preview must disclose no Project.',
        );
      }
      return const ParticipantInvitePreview(available: false);
    }
    return ParticipantInvitePreview(
      available: true,
      projectId: _string(row, 'project_id'),
      kind: ProjectKind.fromWire(_string(row, 'project_kind')),
      title: _string(row, 'project_title'),
    );
  }

  ParticipantAdmissionResult admission(Object? response) {
    final row = _single(response);
    final outcome = switch (_string(row, 'outcome')) {
      'joined' => ParticipantAdmissionOutcome.joined,
      'already_joined' => ParticipantAdmissionOutcome.alreadyJoined,
      'creator' => ParticipantAdmissionOutcome.creator,
      _ => throw const FormatException(
        'Invalid participant admission outcome.',
      ),
    };
    if (row['replayed'] is! bool ||
        !row.containsKey('membership_id') ||
        !row.containsKey('membership_status')) {
      throw const FormatException('Invalid participant admission receipt.');
    }
    final creator = outcome == ParticipantAdmissionOutcome.creator;
    if (creator &&
        (row['membership_id'] != null || row['membership_status'] != null)) {
      throw const FormatException(
        'Creator admission cannot invent membership.',
      );
    }
    return ParticipantAdmissionResult(
      projectId: _string(row, 'project_id'),
      membershipId: creator ? null : _string(row, 'membership_id'),
      outcome: outcome,
      status: creator
          ? null
          : MembershipStatus.fromWire(_string(row, 'membership_status')),
      replayed: row['replayed'] as bool,
    );
  }

  ParticipantLink link(Object? response) {
    final row = _single(response);
    final token = _string(row, 'invite_token');
    if (!tokenPattern.hasMatch(token)) {
      throw const FormatException('Malformed participant sharing secret.');
    }
    return ParticipantLink(
      id: _string(row, 'invitation_id'),
      token: token,
      createdAt: _date(row, 'created_at'),
    );
  }

  List<ParticipantLinkHistory> history(Object? response) {
    if (response is! List || response.length > 20) {
      throw const FormatException(
        'Invalid participant invitation history page.',
      );
    }
    return response
        .map((value) {
          final row = _row(value);
          final revoked = row['revoked_at'] != null;
          for (final key in [
            'revoked_at',
            'revoked_by_profile_id',
            'revocation_reason',
          ]) {
            if (!row.containsKey(key) || (revoked != (row[key] != null))) {
              throw const FormatException('Invalid revocation history.');
            }
          }
          final reason = revoked ? _string(row, 'revocation_reason') : null;
          if (reason != null && reason != 'revoked' && reason != 'replaced') {
            throw const FormatException('Invalid revocation reason.');
          }
          return ParticipantLinkHistory(
            id: _string(row, 'invitation_id'),
            issuerId: _string(row, 'issued_by_profile_id'),
            createdAt: _date(row, 'created_at'),
            revokedAt: revoked ? _date(row, 'revoked_at') : null,
            revokerId: revoked ? _string(row, 'revoked_by_profile_id') : null,
            reason: reason,
          );
        })
        .toList(growable: false);
  }
}

class SupabaseParticipantInvitationGateway
    implements ParticipantInvitationGateway {
  const SupabaseParticipantInvitationGateway(
    this.client, {
    this.parser = const ParticipantInvitationParser(),
  });
  final SupabaseClient client;
  final ParticipantInvitationParser parser;
  Map<String, dynamic> _manager(String account, String project) => {
    'p_expected_profile_id': account,
    'p_project_id': project,
  };
  @override
  Future<ParticipantInvitePreview> preview(String token) async =>
      parser.preview(
        await client.rpc<dynamic>(
          'get_project_participant_invitation_preview',
          params: {'p_token': token},
        ),
      );
  @override
  Future<ParticipantAdmissionResult> accept(
    String profileId,
    String token,
    String actionId,
  ) async => parser.admission(
    await client.rpc<dynamic>(
      'accept_project_participant_invitation',
      params: {
        'p_expected_profile_id': profileId,
        'p_token': token,
        'p_client_action_id': actionId,
      },
    ),
  );
  @override
  Future<ParticipantLink?> current(String profileId, String projectId) async {
    final response = await client.rpc<dynamic>(
      'get_current_project_participant_invitation',
      params: _manager(profileId, projectId),
    );
    if (response is List && response.isEmpty) return null;
    return parser.link(response);
  }

  @override
  Future<ParticipantLink> create(String profileId, String projectId) async =>
      parser.link(
        await client.rpc<dynamic>(
          'create_project_participant_invitation',
          params: _manager(profileId, projectId),
        ),
      );
  @override
  Future<ParticipantLink> regenerate(
    String profileId,
    String projectId,
  ) async => parser.link(
    await client.rpc<dynamic>(
      'regenerate_project_participant_invitation',
      params: _manager(profileId, projectId),
    ),
  );
  @override
  Future<void> revoke(
    String profileId,
    String projectId,
    String invitationId,
  ) async {
    final result = await client.rpc<dynamic>(
      'revoke_project_participant_invitation',
      params: {
        ..._manager(profileId, projectId),
        'p_invitation_id': invitationId,
      },
    );
    if (result != invitationId) {
      throw const FormatException('Participant revocation was not confirmed.');
    }
  }

  @override
  Future<List<ParticipantLinkHistory>> history(
    String profileId,
    String projectId, {
    ParticipantLinkHistory? before,
  }) async => parser.history(
    await client.rpc<dynamic>(
      'list_project_participant_invitation_history',
      params: {
        ..._manager(profileId, projectId),
        'p_limit': 20,
        if (before != null)
          'p_before_created_at': before.createdAt.toUtc().toIso8601String(),
        if (before != null) 'p_before_invitation_id': before.id,
      },
    ),
  );
  @override
  Future<String?> currentChat(String profileId, String projectId) async {
    final response = await client.rpc<dynamic>(
      'get_own_project_group_chat',
      params: _manager(profileId, projectId),
    );
    if (response is! List || response.length > 1) {
      throw const FormatException('Malformed Project chat read.');
    }
    if (response.isEmpty) return null;
    final row = response.single;
    if (row is! Map<String, dynamic> ||
        row['project_id'] != projectId ||
        row['has_current_entitlement'] is! bool) {
      throw const FormatException('Malformed Project chat entitlement.');
    }
    if (row['has_current_entitlement'] == false) return null;
    if (row['chat_id'] is! String || (row['chat_id'] as String).isEmpty) {
      throw const FormatException('Malformed Project chat identity.');
    }
    return row['chat_id'] as String;
  }
}

ParticipantInviteFailure participantInviteFailure(Object error) {
  if (error is PostgrestException) {
    return switch (error.code) {
      'PT409' =>
        error.message == 'This Project is full.'
            ? ParticipantInviteFailure.full
            : ParticipantInviteFailure.unavailable,
      '42501' => ParticipantInviteFailure.forbidden,
      '55000' => ParticipantInviteFailure.profileRequired,
      '22023' => ParticipantInviteFailure.invalidInput,
      _ => ParticipantInviteFailure.network,
    };
  }
  return error is FormatException
      ? ParticipantInviteFailure.malformed
      : ParticipantInviteFailure.network;
}

final participantInvitationGatewayProvider =
    Provider<ParticipantInvitationGateway>(
      (ref) => SupabaseParticipantInvitationGateway(
        ref.watch(supabaseClientProvider),
      ),
    );
