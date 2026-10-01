import '../../resource_listings/domain/resource_listing_models.dart';

enum ProjectResourceTextMatchKind {
  titlePhrase('title_phrase'),
  needTitleInListingTitle('need_title_in_listing_title'),
  needTitleInListingDescription('need_title_in_listing_description'),
  needDetailsInListingTitle('need_details_in_listing_title'),
  needDetailsInListingDescription('need_details_in_listing_description');

  const ProjectResourceTextMatchKind(this.wireValue);

  final String wireValue;

  static ProjectResourceTextMatchKind fromWire(String value) => switch (value) {
    'title_phrase' => ProjectResourceTextMatchKind.titlePhrase,
    'need_title_in_listing_title' =>
      ProjectResourceTextMatchKind.needTitleInListingTitle,
    'need_title_in_listing_description' =>
      ProjectResourceTextMatchKind.needTitleInListingDescription,
    'need_details_in_listing_title' =>
      ProjectResourceTextMatchKind.needDetailsInListingTitle,
    'need_details_in_listing_description' =>
      ProjectResourceTextMatchKind.needDetailsInListingDescription,
    _ => throw const FormatException(
      'Unsupported Project resource text-match kind.',
    ),
  };
}

enum ProjectResourceLocationMatchKind {
  sameLocality('same_locality'),
  sameAdministrativeArea('same_administrative_area'),
  sameCountry('same_country'),
  otherOrUnknown('other_or_unknown');

  const ProjectResourceLocationMatchKind(this.wireValue);

  final String wireValue;

  static ProjectResourceLocationMatchKind fromWire(String value) =>
      switch (value) {
        'same_locality' => ProjectResourceLocationMatchKind.sameLocality,
        'same_administrative_area' =>
          ProjectResourceLocationMatchKind.sameAdministrativeArea,
        'same_country' => ProjectResourceLocationMatchKind.sameCountry,
        'other_or_unknown' => ProjectResourceLocationMatchKind.otherOrUnknown,
        _ => throw const FormatException(
          'Unsupported Project resource location-match kind.',
        ),
      };
}

enum ProjectResourceLocationScope {
  sameLocality('same_locality'),
  sameAdministrativeArea('same_administrative_area'),
  sameCountry('same_country'),
  anywhere('anywhere');

  const ProjectResourceLocationScope(this.wireValue);

  final String wireValue;
}

enum ProjectResourceListingModeFilter {
  all(null),
  donate('donate'),
  exchange('exchange');

  const ProjectResourceListingModeFilter(this.wireValue);

  final String? wireValue;
}

class ProjectResourceMatchCursor {
  const ProjectResourceMatchCursor({
    required this.textMatchKind,
    required this.locationMatchKind,
    required this.publishedAt,
    required this.listingId,
  });

  final ProjectResourceTextMatchKind textMatchKind;
  final ProjectResourceLocationMatchKind locationMatchKind;
  final DateTime publishedAt;
  final String listingId;
}

class ProjectResourceListingMatch {
  const ProjectResourceListingMatch({
    required this.resourceNeedId,
    required this.listingId,
    required this.listingMode,
    required this.title,
    required this.description,
    required this.countryCode,
    required this.locality,
    required this.administrativeArea,
    required this.publicLocationLabel,
    required this.publishedAt,
    required this.activeRequestCount,
    required this.textMatchKind,
    required this.locationMatchKind,
    this.coverObjectPath,
  });

  final String resourceNeedId;
  final String listingId;
  final ResourceListingMode listingMode;
  final String title;
  final String description;
  final String countryCode;
  final String locality;
  final String? administrativeArea;
  final String publicLocationLabel;
  final DateTime publishedAt;
  final int activeRequestCount;
  final ProjectResourceTextMatchKind textMatchKind;
  final ProjectResourceLocationMatchKind locationMatchKind;
  final String? coverObjectPath;

  ProjectResourceMatchCursor get cursor => ProjectResourceMatchCursor(
    textMatchKind: textMatchKind,
    locationMatchKind: locationMatchKind,
    publishedAt: publishedAt,
    listingId: listingId,
  );

  PublicResourceListingSummary get listingSummary =>
      PublicResourceListingSummary(
        id: listingId,
        mode: listingMode,
        title: title,
        description: description,
        countryCode: countryCode,
        locality: locality,
        administrativeArea: administrativeArea,
        publicLocationLabel: publicLocationLabel,
        publishedAt: publishedAt,
        activeRequestCount: activeRequestCount,
        coverObjectPath: coverObjectPath,
      );
}

class ProjectResourceMatchPage {
  const ProjectResourceMatchPage({required this.items, required this.hasMore});

  final List<ProjectResourceListingMatch> items;
  final bool hasMore;

  ProjectResourceMatchCursor? get cursor =>
      items.isEmpty ? null : items.last.cursor;
}
