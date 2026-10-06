import 'package:flutter/foundation.dart';

enum SimilarAvailability { available, full, capacityUnknown }

enum SimilarTitleEvidence { titleTopic, multipleTitleTerms }

enum SimilarLocationRelation { sameLocality, sameCountry, notProvided, other }

/// SIM01's public preview, deliberately independent of full Proposal/count data.
class SimilarProposal {
  const SimilarProposal({
    required this.id,
    required this.title,
    required this.summary,
    required this.startsAt,
    required this.endsAt,
    required this.eventTimezone,
    required this.countryCode,
    required this.locality,
    required this.administrativeArea,
    required this.publicLocationLabel,
    required this.coverObjectPath,
    required this.availability,
    required this.titleEvidence,
    required this.sharedSkillIds,
    required this.locationRelation,
  });
  final String id,
      title,
      summary,
      eventTimezone,
      countryCode,
      locality,
      publicLocationLabel;
  final String? administrativeArea, coverObjectPath;
  final DateTime startsAt, endsAt;
  final SimilarAvailability availability;
  final SimilarTitleEvidence titleEvidence;
  final List<String> sharedSkillIds;
  final SimilarLocationRelation locationRelation;
}

/// In-memory effective request identity. No description or private logistics.
class SimilarProposalQuery {
  SimilarProposalQuery({
    required this.actorId,
    required this.title,
    Iterable<String> skillIds = const [],
    this.countryCode,
    this.locality,
    this.excludedProposalId,
  }) : skillIds = List.unmodifiable(skillIds.toSet().toList()..sort()) {
    if (title.runes.length > 100 || skillIds.length > 50) {
      throw const FormatException('Similar Proposal input exceeds its bounds.');
    }
  }
  final String actorId, title;
  final List<String> skillIds;
  final String? countryCode, locality, excludedProposalId;

  static SimilarProposalQuery? fromForm({
    required String actorId,
    required String title,
    required Iterable<String> skillIds,
    required String country,
    required String locality,
    required String? excludedProposalId,
  }) {
    if (title.trim().isEmpty || title.runes.length > 100) return null;
    final normalizedCountry = country.trim().toUpperCase();
    final normalizedLocality = locality
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    return SimilarProposalQuery(
      actorId: actorId,
      title: title,
      skillIds: skillIds,
      countryCode: RegExp(r'^[A-Z]{2}$').hasMatch(normalizedCountry)
          ? normalizedCountry
          : null,
      locality: locality.runes.length <= 120 && normalizedLocality.isNotEmpty
          ? normalizedLocality
          : null,
      excludedProposalId: excludedProposalId,
    );
  }

  bool sameAs(SimilarProposalQuery? other) =>
      other != null &&
      actorId == other.actorId &&
      title == other.title &&
      listEquals(skillIds, other.skillIds) &&
      countryCode == other.countryCode &&
      locality == other.locality &&
      excludedProposalId == other.excludedProposalId;
}
