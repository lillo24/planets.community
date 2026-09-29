import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';

void main() {
  const parser = BlockingPayloadParser();
  const contract = BlockingRpcContract();

  test('parses only the safe outbound row shape', () {
    final item = parser.parseRow({
      'block_episode_id': '20000000-0000-4000-8000-000000000001',
      'blocked_profile_id': '10000000-0000-4000-8000-000000000002',
      'blocked_display_name': 'Taylor',
      'blocked_at': '2026-09-29T12:00:00Z',
    });
    expect(item.profileId, '10000000-0000-4000-8000-000000000002');
    expect(item.displayName, 'Taylor');
    expect(item.blockedAt, DateTime.utc(2026, 9, 29, 12));
    expect(() => parser.parseRows({'not': 'a list'}), throwsFormatException);
  });

  test('maps expected identity, exact target, and paired list cursor', () {
    expect(contract.exactStatusParams('viewer', 'target'), {
      'p_expected_blocker_profile_id': 'viewer',
      'p_target_profile_id': 'target',
    });
    final cursor = parser.parseRow({
      'block_episode_id': '20000000-0000-4000-8000-000000000001',
      'blocked_profile_id': '10000000-0000-4000-8000-000000000002',
      'blocked_display_name': 'Taylor',
      'blocked_at': '2026-09-29T12:00:00Z',
    });
    expect(contract.listParams('viewer', 20, cursor), {
      'p_expected_blocker_profile_id': 'viewer',
      'p_limit': 20,
      'p_cursor_blocked_at': '2026-09-29T12:00:00.000Z',
      'p_cursor_block_episode_id': cursor.blockEpisodeId,
    });
  });

  test('gateway source uses only canonical blocking RPCs', () {
    final source = File('lib/features/blocking/data/blocking_gateway.dart')
        .readAsStringSync();
    expect(source, isNot(contains(".from('user_block_episodes')")));
    for (final rpc in [
      'get_own_blocked_profile_status',
      'list_own_blocked_profiles',
      'block_user',
      'unblock_user',
    ]) {
      expect(source, contains("'$rpc'"));
    }
    expect(source, isNot(contains('inbound')));
    expect(source, isNot(contains('reciprocal')));
  });
}
