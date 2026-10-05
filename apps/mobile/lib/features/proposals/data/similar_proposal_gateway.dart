import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/cover_media_path.dart';
import '../../../core/backend/supabase_backend.dart';
import '../domain/proposal_time.dart';
import '../domain/similar_proposal.dart';

abstract interface class SimilarProposalGateway {
  Future<List<SimilarProposal>> lookup(SimilarProposalQuery query);
}

typedef SimilarProposalRpc = Future<dynamic> Function(
  String name, {
  required Map<String, dynamic> params,
});

class SupabaseSimilarProposalGateway implements SimilarProposalGateway {
  SupabaseSimilarProposalGateway(SupabaseClient client)
    : _rpc = ((name, {required params}) => client.rpc(name, params: params));
  const SupabaseSimilarProposalGateway.withRpc(this._rpc);
  final SimilarProposalRpc _rpc;

  @override
  Future<List<SimilarProposal>> lookup(SimilarProposalQuery query) async {
    final response = await _rpc(
      'list_similar_active_proposals',
      params: {
        'p_expected_profile_id': query.actorId,
        'p_title': query.title,
        'p_skill_ids': query.skillIds,
        'p_country_code': query.countryCode,
        'p_locality': query.locality,
        'p_excluded_proposal_id': query.excludedProposalId,
        'p_limit': 5,
      },
    ).timeout(const Duration(seconds: 30));
    if (response is! List || response.length > 5) {
      throw const FormatException(
        'Similar Proposal RPC expected a bounded list.',
      );
    }
    final result = response
        .map((value) {
          if (value is! Map<String, dynamic>) {
            throw const FormatException(
              'Similar Proposal row was not an object.',
            );
          }
          return parseSimilarProposal(value);
        })
        .toList(growable: false);
    if (result.map((row) => row.id).toSet().length != result.length) {
      throw const FormatException('Similar Proposal IDs were repeated.');
    }
    return List.unmodifiable(result);
  }
}

SimilarProposal parseSimilarProposal(Map<String, dynamic> row) {
  const fields = {
    'proposal_id',
    'cover_object_path',
    'title',
    'summary',
    'starts_at',
    'ends_at',
    'event_timezone',
    'country_code',
    'locality',
    'administrative_area',
    'public_location_label',
    'derived_status',
    'availability',
    'title_evidence',
    'shared_skill_ids',
    'location_relation',
  };
  if (row.length != fields.length || !fields.containsAll(row.keys)) {
    throw const FormatException('Similar Proposal response fields drifted.');
  }
  String text(String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Similar Proposal $key was malformed.');
    }
    return value;
  }

  String uuid(Object? value) {
    if (value is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
        ).hasMatch(value)) {
      throw const FormatException('Similar Proposal UUID was malformed.');
    }
    return value;
  }

  DateTime date(String key) {
    final value = DateTime.tryParse(text(key));
    if (value == null) {
      throw FormatException('Similar Proposal $key was malformed.');
    }
    return value;
  }

  final id = uuid(row['proposal_id']);
  final start = date('starts_at'), end = date('ends_at');
  final timezone = text('event_timezone');
  final area = row['administrative_area'];
  final skills = row['shared_skill_ids'];
  if (row['derived_status'] != 'upcoming' ||
      !end.isAfter(start) ||
      !isKnownProposalTimeZone(timezone) ||
      (area != null && (area is! String || area.isEmpty)) ||
      skills is! List ||
      skills.length > 50) {
    throw const FormatException(
      'Similar Proposal schedule/reasons were malformed.',
    );
  }
  final shared = skills.map(uuid).toList(growable: false);
  if (shared.toSet().length != shared.length) {
    throw const FormatException(
      'Similar Proposal shared skills were repeated.',
    );
  }
  return SimilarProposal(
    id: id,
    title: text('title'),
    summary: text('summary'),
    startsAt: start,
    endsAt: end,
    eventTimezone: timezone,
    countryCode: text('country_code'),
    locality: text('locality'),
    administrativeArea: area as String?,
    publicLocationLabel: text('public_location_label'),
    coverObjectPath: parseCoverObjectPath(
      row['cover_object_path'],
      parentId: id,
      parentSegment: 'projects',
    ),
    availability: switch (row['availability']) {
      'available' => SimilarAvailability.available,
      'full' => SimilarAvailability.full,
      'capacity_unknown' => SimilarAvailability.capacityUnknown,
      _ => throw const FormatException(
        'Similar Proposal availability was malformed.',
      ),
    },
    titleEvidence: switch (row['title_evidence']) {
      'title_topic' => SimilarTitleEvidence.titleTopic,
      'multiple_title_terms' => SimilarTitleEvidence.multipleTitleTerms,
      _ => throw const FormatException(
        'Similar Proposal title reason was malformed.',
      ),
    },
    locationRelation: switch (row['location_relation']) {
      'same_locality' => SimilarLocationRelation.sameLocality,
      'same_country' => SimilarLocationRelation.sameCountry,
      'not_provided' => SimilarLocationRelation.notProvided,
      'other' => SimilarLocationRelation.other,
      _ => throw const FormatException(
        'Similar Proposal location reason was malformed.',
      ),
    },
    sharedSkillIds: List.unmodifiable(shared),
  );
}

final similarProposalGatewayProvider = Provider<SimilarProposalGateway>(
  (ref) => SupabaseSimilarProposalGateway(ref.watch(supabaseClientProvider)),
);
