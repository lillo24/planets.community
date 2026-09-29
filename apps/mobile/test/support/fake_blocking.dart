import 'dart:async';

import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';
import 'package:planets_mobile/features/blocking/domain/blocking_models.dart';

const blockerProfileId = '10000000-0000-4000-8000-000000000001';
const blockedProfileId = '10000000-0000-4000-8000-000000000002';
const anotherBlockedProfileId = '10000000-0000-4000-8000-000000000003';

BlockedProfile blockedProfileFixture({
  String profileId = blockedProfileId,
  String displayName = 'Taylor',
  DateTime? blockedAt,
}) => BlockedProfile(
  blockEpisodeId: '20000000-0000-4000-8000-${profileId.substring(24)}',
  profileId: profileId,
  displayName: displayName,
  blockedAt: blockedAt ?? DateTime.utc(2026, 9, 29, 12),
);

class FakeBlockingGateway implements BlockingGateway {
  List<BlockedProfile> items = [];
  Object? error;
  Future<void>? delay;
  int statusCalls = 0;
  int listCalls = 0;
  int blockCalls = 0;
  int unblockCalls = 0;
  BlockedProfile? lastCursor;

  @override
  Future<void> block({
    required String expectedBlockerProfileId,
    required String targetProfileId,
  }) async {
    blockCalls++;
    await _waitAndThrow();
    if (!items.any((item) => item.profileId == targetProfileId)) {
      items = [blockedProfileFixture(profileId: targetProfileId), ...items];
    }
  }

  @override
  Future<BlockedProfile?> getOwnStatus({
    required String expectedBlockerProfileId,
    required String targetProfileId,
  }) async {
    statusCalls++;
    await _waitAndThrow();
    return items.where((item) => item.profileId == targetProfileId).firstOrNull;
  }

  @override
  Future<BlockedProfilesPage> listOwn({
    required String expectedBlockerProfileId,
    int pageSize = blockingPageSize,
    BlockedProfile? cursor,
  }) async {
    listCalls++;
    lastCursor = cursor;
    await _waitAndThrow();
    final start = cursor == null
        ? 0
        : items.indexWhere(
                (item) => item.blockEpisodeId == cursor.blockEpisodeId,
              ) +
              1;
    final page = items.skip(start).take(pageSize).toList(growable: false);
    return BlockedProfilesPage(
      items: page,
      hasMore: start + page.length < items.length,
    );
  }

  @override
  Future<void> unblock({
    required String expectedBlockerProfileId,
    required String targetProfileId,
  }) async {
    unblockCalls++;
    await _waitAndThrow();
    items = items
        .where((item) => item.profileId != targetProfileId)
        .toList(growable: false);
  }

  Future<void> _waitAndThrow() async {
    if (delay case final pending?) await pending;
    if (error case final failure?) throw failure;
  }
}
