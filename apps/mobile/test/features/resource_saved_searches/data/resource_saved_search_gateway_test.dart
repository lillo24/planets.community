import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/features/resource_saved_searches/data/resource_saved_search_gateway.dart';
import 'package:planets_mobile/features/resource_saved_searches/domain/resource_saved_search_models.dart';

import '../../../support/fake_resource_saved_search.dart';

void main() {
  const parser = ResourceSavedSearchPayloadParser();
  const contract = ResourceSavedSearchRpcContract();

  test('strict parser accepts all supported optional filter shapes', () {
    final all = parser.savedSearch(_row());
    final queryOnly = parser.savedSearch({
      ..._row(),
      'listing_mode': null,
      'locality': null,
    });
    final modeOnly = parser.savedSearch({
      ..._row(),
      'query': null,
      'locality': null,
    });
    final localityOnly = parser.savedSearch({
      ..._row(),
      'query': null,
      'listing_mode': null,
    });

    expect(all.mode, ResourceListingMode.donate);
    expect(queryOnly.query, 'garden tools');
    expect(modeOnly.mode, ResourceListingMode.donate);
    expect(localityOnly.locality, 'Bologna');
    expect(all.cursor.id, resourceSavedSearchId);
  });

  test('strict parser rejects malformed contracts', () {
    for (final row in [
      {..._row(), 'saved_search_id': 'not-a-uuid'},
      {..._row(), 'query': ''},
      {..._row(), 'query': ' padded '},
      {..._row(), 'query': 'q' * 121},
      {..._row(), 'listing_mode': 'loan'},
      {..._row(), 'query': null, 'listing_mode': null, 'locality': null},
      {..._row(), 'created_at': 'not-a-date'},
      {
        ..._row(),
        'created_at': '2026-09-26T00:00:00Z',
        'updated_at': '2026-09-25T00:00:00Z',
      },
    ]) {
      expect(() => parser.savedSearch(row), throwsFormatException);
    }
  });

  test('maps nullable input and update target exactly', () {
    const input = ResourceSavedSearchInput(
      query: 'tools',
      mode: null,
      locality: null,
    );
    expect(contract.inputParams('profile-id', input), {
      'p_expected_profile_id': 'profile-id',
      'p_query': 'tools',
      'p_listing_mode': null,
      'p_locality': null,
    });
    expect(contract.targetParams('profile-id', resourceSavedSearchId), {
      'p_expected_profile_id': 'profile-id',
      'p_saved_search_id': resourceSavedSearchId,
    });
  });

  test('list contract requests page size plus one and a paired cursor', () {
    final params = contract.listParams(
      expectedProfileId: 'profile-id',
      pageSize: 20,
      cursor: ResourceSavedSearchCursor(
        updatedAt: DateTime.utc(2026, 9, 25, 12),
        id: resourceSavedSearchId,
      ),
    );

    expect(params, {
      'p_expected_profile_id': 'profile-id',
      'p_limit': 21,
      'p_cursor_updated_at': '2026-09-25T12:00:00.000Z',
      'p_cursor_id': resourceSavedSearchId,
    });
    expect(contract.listParams(expectedProfileId: 'profile-id', pageSize: 20), {
      'p_expected_profile_id': 'profile-id',
      'p_limit': 21,
      'p_cursor_updated_at': null,
      'p_cursor_id': null,
    });
  });

  test('gateway source uses exactly the five F1 RPCs and no table read', () {
    final source = File(
      'lib/features/resource_saved_searches/data/resource_saved_search_gateway.dart',
    ).readAsStringSync();
    expect(source, isNot(contains(".from('resource_saved_searches')")));
    for (final rpc in [
      'create_resource_saved_search',
      'update_resource_saved_search',
      'delete_resource_saved_search',
      'get_own_resource_saved_search',
      'list_own_resource_saved_searches',
    ]) {
      expect(source, contains("'$rpc'"));
    }
  });
}

Map<String, dynamic> _row() => {
  'saved_search_id': resourceSavedSearchId,
  'query': 'garden tools',
  'listing_mode': 'donate',
  'locality': 'Bologna',
  'created_at': '2026-09-24T10:00:00Z',
  'updated_at': '2026-09-25T10:00:00Z',
};
