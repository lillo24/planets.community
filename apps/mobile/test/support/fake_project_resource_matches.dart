import 'dart:async';

import 'package:planets_mobile/features/project_resource_needs/data/project_resource_matches_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/domain/project_resource_match_models.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';

const matchCreatorId = '10000000-0000-4000-8000-000000000001';
const matchProjectId = '20000000-0000-4000-8000-000000000001';
const matchNeedId = '30000000-0000-4000-8000-000000000001';
const matchListingId = '40000000-0000-4000-8000-000000000001';

class ProjectResourceMatchCall {
  const ProjectResourceMatchCall({
    required this.expectedCreatorProfileId,
    required this.resourceNeedId,
    required this.locationScope,
    required this.listingMode,
    required this.limit,
    required this.cursor,
  });

  final String expectedCreatorProfileId;
  final String resourceNeedId;
  final ProjectResourceLocationScope locationScope;
  final ProjectResourceListingModeFilter listingMode;
  final int limit;
  final ProjectResourceMatchCursor? cursor;
}

class FakeProjectResourceMatchesGateway
    implements ProjectResourceMatchesGateway {
  ProjectResourceMatchPage page = const ProjectResourceMatchPage(
    items: [],
    hasMore: false,
  );
  final List<ProjectResourceMatchPage> queuedPages = [];
  final List<ProjectResourceMatchCall> calls = [];
  Object? error;
  Future<void>? delay;

  @override
  Future<ProjectResourceMatchPage> listMatches({
    required String expectedCreatorProfileId,
    required String resourceNeedId,
    required ProjectResourceLocationScope locationScope,
    required ProjectResourceListingModeFilter listingMode,
    required int limit,
    ProjectResourceMatchCursor? cursor,
  }) async {
    calls.add(
      ProjectResourceMatchCall(
        expectedCreatorProfileId: expectedCreatorProfileId,
        resourceNeedId: resourceNeedId,
        locationScope: locationScope,
        listingMode: listingMode,
        limit: limit,
        cursor: cursor,
      ),
    );
    if (delay case final pending?) await pending;
    if (error case final failure?) throw failure;
    if (queuedPages.isNotEmpty) return queuedPages.removeAt(0);
    return page;
  }
}

ProjectResourceListingMatch projectResourceMatchFixture({
  String resourceNeedId = matchNeedId,
  String listingId = matchListingId,
  ResourceListingMode listingMode = ResourceListingMode.donate,
  String title = 'Cordless drill',
  String description = 'A drill suitable for wood and masonry.',
  String countryCode = 'IT',
  String locality = 'Bologna',
  String? administrativeArea = 'Emilia-Romagna',
  String publicLocationLabel = 'Central Bologna',
  DateTime? publishedAt,
  int activeRequestCount = 2,
  ProjectResourceTextMatchKind textMatchKind =
      ProjectResourceTextMatchKind.needTitleInListingTitle,
  ProjectResourceLocationMatchKind locationMatchKind =
      ProjectResourceLocationMatchKind.sameLocality,
}) => ProjectResourceListingMatch(
  resourceNeedId: resourceNeedId,
  listingId: listingId,
  listingMode: listingMode,
  title: title,
  description: description,
  countryCode: countryCode,
  locality: locality,
  administrativeArea: administrativeArea,
  publicLocationLabel: publicLocationLabel,
  publishedAt: publishedAt ?? DateTime.utc(2026, 9, 20, 10),
  activeRequestCount: activeRequestCount,
  textMatchKind: textMatchKind,
  locationMatchKind: locationMatchKind,
);

Completer<void> pendingMatchRequest() => Completer<void>();
