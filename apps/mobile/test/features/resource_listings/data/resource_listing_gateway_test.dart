import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';

import '../../../support/fake_resource_listing.dart';

void main() {
  const parser = ResourceListingPayloadParser();
  const contract = ResourceListingRpcContract();

  test('parses strict public summary and paired cursor', () {
    final summary = parser.publicSummary(_publicRow());

    expect(summary.id, resourceListingId);
    expect(summary.mode, ResourceListingMode.donate);
    expect(summary.administrativeArea, 'Emilia-Romagna');
    expect(summary.cursor.id, resourceListingId);
    expect(summary.cursor.publishedAt, DateTime.parse(_publishedAt));
    expect(summary.activeRequestCount, 3);
    expect(summary.coverObjectPath, _coverObjectPath);
  });

  test('public detail preserves present and absent owner display name', () {
    final visible = parser.publicDetail({
      ..._publicRow(),
      'owner_profile_id': resourceOwnerProfileId,
      'owner_display_name': 'Casey',
    });
    final hidden = parser.publicDetail({
      ..._publicRow(),
      'owner_profile_id': resourceOwnerProfileId,
      'owner_display_name': null,
    });

    expect(visible.ownerDisplayName, 'Casey');
    expect(hidden.ownerDisplayName, isNull);
  });

  for (final lifecycle in ResourceListingLifecycle.values) {
    test('parses owner listing lifecycle ${lifecycle.wireValue}', () {
      final listing = parser.ownListing(_ownRow(lifecycle.wireValue));
      expect(listing.lifecycle, lifecycle);
      expect(listing.ownerProfileId, resourceOwnerProfileId);
    });
  }

  test('unknown modes and lifecycles fail explicitly', () {
    expect(
      () => parser.publicSummary({..._publicRow(), 'listing_mode': 'loan'}),
      throwsFormatException,
    );
    expect(() => parser.ownListing(_ownRow('reopened')), throwsFormatException);
  });

  test('owner lifecycle timestamp mismatches fail explicitly', () {
    expect(
      () => parser.ownListing({..._ownRow('closed'), 'closed_at': null}),
      throwsFormatException,
    );
  });

  test('missing required fields and malformed identifiers fail explicitly', () {
    expect(
      () => parser.publicSummary({..._publicRow(), 'title': null}),
      throwsFormatException,
    );
    expect(
      () => parser.publicSummary({..._publicRow(), 'listing_id': 'not-a-uuid'}),
      throwsFormatException,
    );
    expect(
      () =>
          parser.publicSummary({..._publicRow(), 'published_at': 'not-a-date'}),
      throwsFormatException,
    );
  });

  test('active request count rejects negative and malformed values', () {
    expect(
      () => parser.publicSummary({..._publicRow(), 'active_request_count': -1}),
      throwsFormatException,
    );
    expect(
      () =>
          parser.publicSummary({..._publicRow(), 'active_request_count': '3'}),
      throwsFormatException,
    );
  });

  test('cover path is nullable and rejects another Resource identity', () {
    expect(
      parser.publicSummary({
        ..._publicRow(),
        'cover_object_path': null,
      }).coverObjectPath,
      isNull,
    );
    expect(
      () => parser.publicSummary({
        ..._publicRow(),
        'cover_object_path':
            '$resourceOwnerProfileId/resources/10000000-0000-4000-8000-000000000099/30000000-0000-4000-8000-000000000001.webp',
      }),
      throwsFormatException,
    );
  });

  test('maps public filters and both cursor values to the 04C1 RPC', () {
    final params = contract.publicListParams(
      limit: 20,
      cursor: ResourceListingCursor(
        publishedAt: DateTime.utc(2026, 9, 14, 12),
        id: resourceListingId,
      ),
      mode: ResourceListingMode.exchange,
      locality: 'Bologna',
      query: 'shovel',
    );

    expect(params, {
      'p_limit': 20,
      'p_cursor_published_at': '2026-09-14T12:00:00.000Z',
      'p_cursor_id': resourceListingId,
      'p_listing_mode': 'exchange',
      'p_locality': 'Bologna',
      'p_query': 'shovel',
    });
  });

  test('maps owner content and expected identity to RPC parameters', () {
    final input = resourceListingInputFixture(
      mode: ResourceListingMode.exchange,
    );
    expect(contract.contentParams(resourceOwnerProfileId, input), {
      'p_expected_owner_profile_id': resourceOwnerProfileId,
      'p_listing_mode': 'exchange',
      'p_title': input.title,
      'p_description': input.description,
      'p_country_code': input.countryCode,
      'p_locality': input.locality,
      'p_administrative_area': input.administrativeArea,
      'p_public_location_label': input.publicLocationLabel,
    });
    expect(
      contract.ownerListingParams(resourceOwnerProfileId, resourceListingId),
      {
        'p_expected_owner_profile_id': resourceOwnerProfileId,
        'p_listing_id': resourceListingId,
      },
    );
  });

  test('gateway source never directly accesses resource_listings', () {
    final source = File(
      'lib/features/resource_listings/data/resource_listing_gateway.dart',
    ).readAsStringSync();
    expect(source, isNot(contains(".from('resource_listings')")));
    for (final rpc in [
      'create_resource_listing_draft',
      'update_own_resource_listing',
      'publish_resource_listing',
      'close_resource_listing',
      'list_own_resource_listings',
      'get_own_resource_listing',
      'list_public_resource_listings',
      'get_public_resource_listing',
    ]) {
      expect(source, contains("'$rpc'"));
    }
  });
}

const _publishedAt = '2026-09-14T12:00:00Z';
const _coverObjectPath =
    '$resourceOwnerProfileId/resources/$resourceListingId/30000000-0000-4000-8000-000000000001.webp';

Map<String, dynamic> _publicRow() => {
  'listing_id': resourceListingId,
  'cover_object_path': _coverObjectPath,
  'listing_mode': 'donate',
  'title': 'Garden tools',
  'description': 'A rake and a shovel ready for a new garden.',
  'country_code': 'IT',
  'locality': 'Bologna',
  'administrative_area': 'Emilia-Romagna',
  'public_location_label': 'Central Bologna',
  'published_at': _publishedAt,
  'active_request_count': 3,
};

Map<String, dynamic> _ownRow(String lifecycle) => {
  ..._publicRow(),
  'owner_profile_id': resourceOwnerProfileId,
  'lifecycle_state': lifecycle,
  'created_at': '2026-09-01T10:00:00Z',
  'updated_at': '2026-09-14T12:00:00Z',
  'published_at': lifecycle == 'draft' ? null : _publishedAt,
  'closed_at': lifecycle == 'closed' ? '2026-09-15T12:00:00Z' : null,
};
