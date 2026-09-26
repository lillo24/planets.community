import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/proposal_models.dart';

const proposalPageSize = 20;

abstract interface class ProposalGateway {
  Future<List<ProposalSkillCategory>> loadSkillCatalog();

  Future<List<ProposalSummary>> listPublicProposals({
    required int limit,
    ProposalCursor? cursor,
    String? query,
    String? locality,
    Set<String>? skillIds,
  });

  Future<List<RequestedProposalSummary>> listOwnPendingRequestedProposals(
    String expectedProfileId, {
    String? query,
    String? locality,
    Set<String>? skillIds,
  });

  Future<ProposalDetail?> getPublicProposal(String proposalId);

  Future<List<OwnProposal>> listOwnProposals(String expectedCreatorId);

  Future<OwnProposal?> getOwnProposal(
    String expectedCreatorId,
    String proposalId,
  );

  Future<String> createDraft(String expectedCreatorId, ProposalInput input);

  Future<void> updateOwnProposal(
    String expectedCreatorId,
    String proposalId,
    ProposalInput input,
  );

  Future<void> publishProposal(String expectedCreatorId, String proposalId);

  Future<void> cancelProposal(String expectedCreatorId, String proposalId);
}

class ProposalPayloadParser {
  const ProposalPayloadParser();

  ProposalSummary publicSummary(Map<String, dynamic> row) => ProposalSummary(
    id: _uuid(row, 'proposal_id'),
    title: _string(row, 'title'),
    summary: _string(row, 'summary'),
    startsAt: _date(row, 'starts_at'),
    endsAt: _date(row, 'ends_at'),
    eventTimezone: _string(row, 'event_timezone'),
    countryCode: _string(row, 'country_code'),
    locality: _string(row, 'locality'),
    administrativeArea: _optionalString(row, 'administrative_area'),
    publicLocationLabel: _string(row, 'public_location_label'),
    status: ProposalStatus.fromWire(_string(row, 'derived_status')),
    skills: skills(row['skills']),
  );

  ProposalDetail publicDetail(Map<String, dynamic> row) => ProposalDetail(
    summary: publicSummary(row),
    creatorProfileId: _uuid(row, 'creator_profile_id'),
    creatorDisplayName: _optionalString(row, 'creator_display_name'),
    description: _string(row, 'description'),
    exactMeetingText: _optionalString(row, 'exact_meeting_text'),
    exactLocationRestricted: _boolean(row, 'exact_location_restricted'),
  );

  List<ProposalSkill> skills(dynamic value) {
    if (value is! List) {
      throw const FormatException('Proposal skills were not a list.');
    }
    return value
        .map((entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException(
              'Proposal skill entry was not an object.',
            );
          }
          return ProposalSkill(
            id: _uuid(entry, 'id'),
            slug: _string(entry, 'slug'),
            label: _string(entry, 'label'),
            categoryId: _uuid(entry, 'category_id'),
            categorySlug: _string(entry, 'category_slug'),
            categoryLabel: _string(entry, 'category_label'),
            importance: ProposalSkillImportance.fromWire(
              _string(entry, 'importance'),
            ),
          );
        })
        .toList(growable: false);
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Proposal $key was not a string.');
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw FormatException('Proposal $key was malformed.');
    }
    return value;
  }

  String _uuid(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw FormatException('Proposal $key was not a UUID.');
    }
    return value;
  }

  DateTime _date(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Proposal $key was not a timestamp.');
    }
    return parsed;
  }

  bool _boolean(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) {
      throw FormatException('Proposal $key was not a boolean.');
    }
    return value;
  }
}

class SupabaseProposalGateway implements ProposalGateway {
  const SupabaseProposalGateway(
    this._client, {
    this.parser = const ProposalPayloadParser(),
  });

  final SupabaseClient _client;
  final ProposalPayloadParser parser;

  @override
  Future<List<ProposalSkillCategory>> loadSkillCatalog() async {
    final results = await Future.wait<dynamic>([
      _client
          .from('skill_categories')
          .select('id, slug, label, sort_order')
          .order('sort_order'),
      _client
          .from('skills')
          .select('id, category_id, slug, label, sort_order')
          .order('sort_order'),
    ]);
    final categoryRows = (results[0] as List).cast<Map<String, dynamic>>();
    final skillRows = (results[1] as List).cast<Map<String, dynamic>>();
    final skills = skillRows.map(_catalogSkillFromRow).toList(growable: false);

    return categoryRows
        .map(
          (row) => ProposalSkillCategory(
            id: row['id'] as String,
            slug: row['slug'] as String,
            label: row['label'] as String,
            sortOrder: row['sort_order'] as int,
            skills: skills
                .where((skill) => skill.categoryId == row['id'])
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<ProposalSummary>> listPublicProposals({
    required int limit,
    ProposalCursor? cursor,
    String? query,
    String? locality,
    Set<String>? skillIds,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_public_proposals',
      params: {
        'p_limit': limit,
        'p_cursor_starts_at': cursor?.startsAt.toUtc().toIso8601String(),
        'p_cursor_id': cursor?.id,
        'p_query': query,
        'p_locality': locality,
        'p_skill_ids': skillIds?.toList(growable: false),
      },
    );
    return response
        .cast<Map<String, dynamic>>()
        .map(parser.publicSummary)
        .toList(growable: false);
  }

  @override
  Future<List<RequestedProposalSummary>> listOwnPendingRequestedProposals(
    String expectedProfileId, {
    String? query,
    String? locality,
    Set<String>? skillIds,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_pending_requested_proposals',
      params: {
        'p_expected_requester_profile_id': expectedProfileId,
        'p_query': query,
        'p_locality': locality,
        'p_skill_ids': skillIds?.toList(growable: false),
      },
    );
    return response
        .cast<Map<String, dynamic>>()
        .map(
          (row) => RequestedProposalSummary(
            requestId: row['request_id'] as String,
            requestCreatedAt: DateTime.parse(
              row['request_created_at'] as String,
            ),
            proposal: parser.publicSummary(row),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<ProposalDetail?> getPublicProposal(String proposalId) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_public_proposal',
      params: {'p_proposal_id': proposalId},
    );
    final rows = response.cast<Map<String, dynamic>>();
    return rows.isEmpty ? null : parser.publicDetail(rows.single);
  }

  @override
  Future<List<OwnProposal>> listOwnProposals(String expectedCreatorId) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_proposals',
      params: {'p_expected_creator_profile_id': expectedCreatorId},
    );
    return response
        .cast<Map<String, dynamic>>()
        .map(_ownProposalFromRow)
        .toList(growable: false);
  }

  @override
  Future<OwnProposal?> getOwnProposal(
    String expectedCreatorId,
    String proposalId,
  ) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_own_proposal',
      params: {
        'p_expected_creator_profile_id': expectedCreatorId,
        'p_proposal_id': proposalId,
      },
    );
    final rows = response.cast<Map<String, dynamic>>();
    return rows.isEmpty ? null : _ownProposalFromRow(rows.single);
  }

  @override
  Future<String> createDraft(
    String expectedCreatorId,
    ProposalInput input,
  ) async {
    return _client.rpc<String>(
      'create_proposal_draft',
      params: _contentParams(expectedCreatorId, input),
    );
  }

  @override
  Future<void> updateOwnProposal(
    String expectedCreatorId,
    String proposalId,
    ProposalInput input,
  ) async {
    await _client.rpc<void>(
      'update_own_proposal',
      params: {
        ..._contentParams(expectedCreatorId, input),
        'p_proposal_id': proposalId,
      },
    );
  }

  @override
  Future<void> publishProposal(
    String expectedCreatorId,
    String proposalId,
  ) async {
    await _client.rpc<void>(
      'publish_proposal',
      params: {
        'p_expected_creator_profile_id': expectedCreatorId,
        'p_proposal_id': proposalId,
      },
    );
  }

  @override
  Future<void> cancelProposal(
    String expectedCreatorId,
    String proposalId,
  ) async {
    await _client.rpc<void>(
      'cancel_proposal',
      params: {
        'p_expected_creator_profile_id': expectedCreatorId,
        'p_proposal_id': proposalId,
      },
    );
  }

  Map<String, dynamic> _contentParams(
    String expectedCreatorId,
    ProposalInput input,
  ) {
    final skillEntries = input.skillImportanceById.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return {
      'p_expected_creator_profile_id': expectedCreatorId,
      'p_title': input.title,
      'p_summary': input.summary,
      'p_description': input.description,
      'p_starts_at': input.startsAt?.toUtc().toIso8601String(),
      'p_ends_at': input.endsAt?.toUtc().toIso8601String(),
      'p_event_timezone': input.eventTimezone,
      'p_country_code': input.countryCode,
      'p_locality': input.locality,
      'p_administrative_area': input.administrativeArea,
      'p_public_location_label': input.publicLocationLabel,
      'p_exact_meeting_text': input.exactMeetingText,
      'p_exact_location_visibility': input.exactLocationVisibility.wireValue,
      'p_skill_ids': skillEntries.map((entry) => entry.key).toList(),
      'p_skill_importances': skillEntries
          .map((entry) => entry.value.wireValue)
          .toList(),
    };
  }

  OwnProposal _ownProposalFromRow(Map<String, dynamic> row) => OwnProposal(
    id: row['proposal_id'] as String,
    lifecycle: ProposalLifecycle.fromWire(row['lifecycle_state'] as String),
    title: row['title'] as String?,
    summary: row['summary'] as String?,
    description: row['description'] as String?,
    startsAt: _optionalDate(row['starts_at']),
    endsAt: _optionalDate(row['ends_at']),
    eventTimezone: row['event_timezone'] as String?,
    countryCode: row['country_code'] as String?,
    locality: row['locality'] as String?,
    administrativeArea: row['administrative_area'] as String?,
    publicLocationLabel: row['public_location_label'] as String?,
    status: row['derived_status'] == null
        ? null
        : ProposalStatus.fromWire(row['derived_status'] as String),
    skills: parser.skills(row['skills']),
    exactMeetingText: row['exact_meeting_text'] as String?,
    exactLocationVisibility: ExactLocationVisibility.fromWire(
      row['exact_location_visibility'] as String,
    ),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    publishedAt: _optionalDate(row['published_at']),
    cancelledAt: _optionalDate(row['cancelled_at']),
  );

  ProposalCatalogSkill _catalogSkillFromRow(Map<String, dynamic> row) =>
      ProposalCatalogSkill(
        id: row['id'] as String,
        categoryId: row['category_id'] as String,
        slug: row['slug'] as String,
        label: row['label'] as String,
        sortOrder: row['sort_order'] as int,
      );

  DateTime? _optionalDate(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);
}

final proposalGatewayProvider = Provider<ProposalGateway>((ref) {
  return SupabaseProposalGateway(ref.watch(supabaseClientProvider));
});
