import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_matches_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/domain/project_resource_match_models.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';

import '../../../support/fake_project_resource_matches.dart';

void main() {
  const parser = ProjectResourceMatchPayloadParser();
  const contract = ProjectResourceMatchesRpcContract();

  for (final textKind in ProjectResourceTextMatchKind.values) {
    test('parses text reason ${textKind.wireValue}', () {
      final match = parser.match(
        _row(textMatchKind: textKind.wireValue),
        expectedResourceNeedId: matchNeedId,
      );
      expect(match.textMatchKind, textKind);
    });
  }

  for (final locationKind in ProjectResourceLocationMatchKind.values) {
    test('parses location reason ${locationKind.wireValue}', () {
      final match = parser.match(
        _row(locationMatchKind: locationKind.wireValue),
        expectedResourceNeedId: matchNeedId,
      );
      expect(match.locationMatchKind, locationKind);
    });
  }

  for (final mode in ResourceListingMode.values) {
    test('parses listing mode ${mode.wireValue}', () {
      final match = parser.match(
        _row(listingMode: mode.wireValue),
        expectedResourceNeedId: matchNeedId,
      );
      expect(match.listingMode, mode);
    });
  }

  test('parses public fields and optional administrative area', () {
    final match = parser.match(
      _row(administrativeArea: null, activeRequestCount: 4),
      expectedResourceNeedId: matchNeedId,
    );

    expect(match.administrativeArea, isNull);
    expect(match.locality, 'Bologna');
    expect(match.activeRequestCount, 4);
    expect(match.cursor.listingId, matchListingId);
  });

  test('rejects malformed identifiers and mismatched need identity', () {
    expect(
      () => parser.match(
        _row(listingId: 'not-a-uuid'),
        expectedResourceNeedId: matchNeedId,
      ),
      throwsFormatException,
    );
    expect(
      () => parser.match(
        _row(),
        expectedResourceNeedId: '30000000-0000-4000-8000-000000000099',
      ),
      throwsFormatException,
    );
  });

  test('rejects negative counts and unknown reason enums', () {
    expect(
      () => parser.match(
        _row(activeRequestCount: -1),
        expectedResourceNeedId: matchNeedId,
      ),
      throwsFormatException,
    );
    expect(
      () => parser.match(
        _row(textMatchKind: 'semantic_magic'),
        expectedResourceNeedId: matchNeedId,
      ),
      throwsFormatException,
    );
    expect(
      () => parser.match(
        _row(locationMatchKind: 'nearby'),
        expectedResourceNeedId: matchNeedId,
      ),
      throwsFormatException,
    );
  });

  test('rejects malformed public text, geography, and timestamps', () {
    for (final malformed in [
      {..._row(), 'title': ''},
      {..._row(), 'description': '  '},
      {..._row(), 'country_code': 'ITA'},
      {..._row(), 'locality': ''},
      {..._row(), 'administrative_area': ''},
      {..._row(), 'public_location_label': ''},
      {..._row(), 'published_at': 'not-a-timestamp'},
    ]) {
      expect(
        () => parser.match(malformed, expectedResourceNeedId: matchNeedId),
        throwsFormatException,
      );
    }
  });

  test('maps null mode and an empty complete cursor to exact RPC params', () {
    expect(
      contract.listParams(
        expectedCreatorProfileId: matchCreatorId,
        resourceNeedId: matchNeedId,
        locationScope: ProjectResourceLocationScope.anywhere,
        listingMode: ProjectResourceListingModeFilter.all,
        limit: 20,
      ),
      {
        'p_expected_creator_profile_id': matchCreatorId,
        'p_resource_need_id': matchNeedId,
        'p_location_scope': 'anywhere',
        'p_limit': 21,
        'p_listing_mode': null,
        'p_cursor_text_match_kind': null,
        'p_cursor_location_match_kind': null,
        'p_cursor_published_at': null,
        'p_cursor_listing_id': null,
      },
    );
  });

  test('maps mode and all four cursor values to exact RPC params', () {
    final params = contract.listParams(
      expectedCreatorProfileId: matchCreatorId,
      resourceNeedId: matchNeedId,
      locationScope: ProjectResourceLocationScope.sameAdministrativeArea,
      listingMode: ProjectResourceListingModeFilter.exchange,
      limit: 20,
      cursor: ProjectResourceMatchCursor(
        textMatchKind:
            ProjectResourceTextMatchKind.needDetailsInListingDescription,
        locationMatchKind: ProjectResourceLocationMatchKind.sameCountry,
        publishedAt: DateTime.utc(2026, 9, 20, 10),
        listingId: matchListingId,
      ),
    );

    expect(params, {
      'p_expected_creator_profile_id': matchCreatorId,
      'p_resource_need_id': matchNeedId,
      'p_location_scope': 'same_administrative_area',
      'p_limit': 21,
      'p_listing_mode': 'exchange',
      'p_cursor_text_match_kind': 'need_details_in_listing_description',
      'p_cursor_location_match_kind': 'same_country',
      'p_cursor_published_at': '2026-09-20T10:00:00.000Z',
      'p_cursor_listing_id': matchListingId,
    });
  });

  test('gateway is RPC-only and names the canonical E1 function', () {
    final source = File(
      'lib/features/project_resource_needs/data/project_resource_matches_gateway.dart',
    ).readAsStringSync();
    expect(source, contains("'list_project_resource_need_listing_matches'"));
    expect(source, isNot(contains('.from(')));
  });
}

Map<String, dynamic> _row({
  String resourceNeedId = matchNeedId,
  String listingId = matchListingId,
  String listingMode = 'donate',
  String? administrativeArea = 'Emilia-Romagna',
  int activeRequestCount = 2,
  String textMatchKind = 'need_title_in_listing_title',
  String locationMatchKind = 'same_locality',
}) => {
  'resource_need_id': resourceNeedId,
  'listing_id': listingId,
  'listing_mode': listingMode,
  'title': 'Cordless drill',
  'description': 'A drill suitable for wood and masonry.',
  'country_code': 'IT',
  'locality': 'Bologna',
  'administrative_area': administrativeArea,
  'public_location_label': 'Central Bologna',
  'published_at': '2026-09-20T10:00:00Z',
  'active_request_count': activeRequestCount,
  'text_match_kind': textMatchKind,
  'location_match_kind': locationMatchKind,
};
