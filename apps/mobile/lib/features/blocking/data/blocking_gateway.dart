import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/blocking_models.dart';

abstract interface class BlockingGateway {
  Future<BlockedProfile?> getOwnStatus({
    required String expectedBlockerProfileId,
    required String targetProfileId,
  });

  Future<BlockedProfilesPage> listOwn({
    required String expectedBlockerProfileId,
    int pageSize = blockingPageSize,
    BlockedProfile? cursor,
  });

  Future<void> block({
    required String expectedBlockerProfileId,
    required String targetProfileId,
  });

  Future<void> unblock({
    required String expectedBlockerProfileId,
    required String targetProfileId,
  });
}

class BlockingRpcContract {
  const BlockingRpcContract();

  Map<String, Object?> exactStatusParams(
    String expectedBlockerProfileId,
    String targetProfileId,
  ) => {
    'p_expected_blocker_profile_id': expectedBlockerProfileId,
    'p_target_profile_id': targetProfileId,
  };

  Map<String, Object?> targetParams(
    String expectedBlockerProfileId,
    String targetProfileId,
  ) => {
    'p_expected_blocker_profile_id': expectedBlockerProfileId,
    'p_blocked_profile_id': targetProfileId,
  };

  Map<String, Object?> listParams(
    String expectedBlockerProfileId,
    int pageSize,
    BlockedProfile? cursor,
  ) => {
    'p_expected_blocker_profile_id': expectedBlockerProfileId,
    'p_limit': pageSize,
    'p_cursor_blocked_at': cursor?.blockedAt.toUtc().toIso8601String(),
    'p_cursor_block_episode_id': cursor?.blockEpisodeId,
  };
}

class BlockingPayloadParser {
  const BlockingPayloadParser();

  BlockedProfile parseRow(Map<String, dynamic> row) => BlockedProfile(
    blockEpisodeId: _requiredString(row, 'block_episode_id'),
    profileId: _requiredString(row, 'blocked_profile_id'),
    displayName: _requiredString(row, 'blocked_display_name'),
    blockedAt: DateTime.parse(_requiredString(row, 'blocked_at')).toUtc(),
  );

  List<BlockedProfile> parseRows(Object? payload) {
    if (payload is! List) {
      throw const FormatException('Expected a blocked-profile list.');
    }
    return payload
        .map((row) {
          if (row is! Map) {
            throw const FormatException('Expected a blocked-profile row.');
          }
          return parseRow(Map<String, dynamic>.from(row));
        })
        .toList(growable: false);
  }
}

class SupabaseBlockingGateway implements BlockingGateway {
  SupabaseBlockingGateway(
    this._client, {
    this.contract = const BlockingRpcContract(),
    this.parser = const BlockingPayloadParser(),
  });

  final SupabaseClient _client;
  final BlockingRpcContract contract;
  final BlockingPayloadParser parser;

  @override
  Future<BlockedProfile?> getOwnStatus({
    required String expectedBlockerProfileId,
    required String targetProfileId,
  }) async {
    final payload = await _client.rpc(
      'get_own_blocked_profile_status',
      params: contract.exactStatusParams(
        expectedBlockerProfileId,
        targetProfileId,
      ),
    );
    final rows = parser.parseRows(payload);
    if (rows.length > 1) {
      throw const FormatException('Expected at most one outbound block row.');
    }
    return rows.firstOrNull;
  }

  @override
  Future<BlockedProfilesPage> listOwn({
    required String expectedBlockerProfileId,
    int pageSize = blockingPageSize,
    BlockedProfile? cursor,
  }) async {
    final payload = await _client.rpc(
      'list_own_blocked_profiles',
      params: contract.listParams(expectedBlockerProfileId, pageSize, cursor),
    );
    final rows = parser.parseRows(payload);
    return BlockedProfilesPage(items: rows, hasMore: rows.length == pageSize);
  }

  @override
  Future<void> block({
    required String expectedBlockerProfileId,
    required String targetProfileId,
  }) => _client.rpc(
    'block_user',
    params: contract.targetParams(expectedBlockerProfileId, targetProfileId),
  );

  @override
  Future<void> unblock({
    required String expectedBlockerProfileId,
    required String targetProfileId,
  }) => _client.rpc(
    'unblock_user',
    params: contract.targetParams(expectedBlockerProfileId, targetProfileId),
  );
}

final blockingGatewayProvider = Provider<BlockingGateway>((ref) {
  return SupabaseBlockingGateway(ref.watch(supabaseClientProvider));
});

String _requiredString(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Expected non-empty $key.');
  }
  return value;
}
