import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';

import '../../../support/fake_resource_listing.dart';

void main() {
  test('drafts permit missing publish content but enforce field bounds', () {
    expect(
      isValidResourceListingDraft(
        resourceListingInputFixture(
          title: '',
          description: '',
          countryCode: '',
          locality: '',
          administrativeArea: '',
          publicLocationLabel: '',
        ),
      ),
      isTrue,
    );
    expect(
      isPublishableResourceListingInput(
        resourceListingInputFixture(
          title: '',
          description: '',
          countryCode: '',
          locality: '',
          administrativeArea: '',
          publicLocationLabel: '',
        ),
      ),
      isFalse,
    );
    expect(
      isValidResourceListingDraft(resourceListingInputFixture(title: 'x')),
      isFalse,
    );
    expect(
      isValidResourceListingDraft(
        resourceListingInputFixture(countryCode: 'ITA'),
      ),
      isFalse,
    );
  });

  test('complete bounded input is publishable for both discovery modes', () {
    for (final mode in ResourceListingMode.values) {
      expect(
        isPublishableResourceListingInput(
          resourceListingInputFixture(mode: mode),
        ),
        isTrue,
      );
    }
  });
}
