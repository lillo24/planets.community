import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/features/resource_saved_searches/domain/resource_saved_search_models.dart';

void main() {
  test('normalizes blank and trimmed text without inventing a mode', () {
    final input = ResourceSavedSearchInput.normalized(
      query: '  drill  ',
      mode: null,
      locality: '   ',
    );

    expect(input.query, 'drill');
    expect(input.mode, isNull);
    expect(input.locality, isNull);
    expect(input.isValid, isTrue);
  });

  test('accepts every non-empty filter combination', () {
    for (final input in [
      const ResourceSavedSearchInput(query: 'q', mode: null, locality: null),
      const ResourceSavedSearchInput(
        query: null,
        mode: ResourceListingMode.donate,
        locality: null,
      ),
      const ResourceSavedSearchInput(
        query: null,
        mode: null,
        locality: 'Bologna',
      ),
      const ResourceSavedSearchInput(
        query: 'q',
        mode: ResourceListingMode.exchange,
        locality: 'Bologna',
      ),
    ]) {
      expect(input.isValid, isTrue);
    }
  });

  test('rejects empty and overlong inputs', () {
    expect(
      const ResourceSavedSearchInput(
        query: null,
        mode: null,
        locality: null,
      ).isValid,
      isFalse,
    );
    expect(
      ResourceSavedSearchInput(
        query: 'q' * 121,
        mode: null,
        locality: null,
      ).isValid,
      isFalse,
    );
    expect(
      ResourceSavedSearchInput(
        query: null,
        mode: null,
        locality: 'l' * 121,
      ).isValid,
      isFalse,
    );
  });

  test('saved search exposes the complete updated-at/id cursor', () {
    final updatedAt = DateTime.utc(2026, 9, 25, 12);
    final search = ResourceSavedSearch(
      id: 'id',
      query: 'tools',
      mode: null,
      locality: null,
      createdAt: DateTime.utc(2026, 9, 24),
      updatedAt: updatedAt,
    );

    expect(search.cursor.id, 'id');
    expect(search.cursor.updatedAt, updatedAt);
    expect(search.input.query, 'tools');
  });
}
