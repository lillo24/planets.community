import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/resource_exchange_models.dart';

abstract interface class ResourceExchangeGateway {
  Future<ResourceExchangeAgreement> getAgreement({
    required String expectedProfileId,
    required String requestId,
  });

  Future<List<ResourceExchangeTerms>> listTerms({
    required String expectedProfileId,
    required String agreementId,
  });

  Future<List<ResourceExchangeEvent>> listEvents({
    required String expectedProfileId,
    required String agreementId,
  });

  Future<String> recordMilestone({
    required String expectedProfileId,
    required String agreementId,
    required String expectedTermsId,
    required ResourceExchangeLegKind legKind,
    required ResourceExchangeMilestoneKind eventKind,
  });

  Future<String> proposeTerms({
    required String expectedProfileId,
    required String agreementId,
    required String? expectedCurrentTermsId,
    required String? expectedPendingTermsId,
    required ResourceExchangeTermsInput input,
  });

  Future<String> acceptPendingTerms({
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  });

  Future<String> rejectPendingTerms({
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  });

  Future<String> withdrawPendingTerms({
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  });

  Future<String> cancelAgreement({
    required String expectedProfileId,
    required String agreementId,
  });
}

class SupabaseResourceExchangeGateway implements ResourceExchangeGateway {
  const SupabaseResourceExchangeGateway(this._client);

  final SupabaseClient _client;
  static const parser = ResourceExchangePayloadParser();

  @override
  Future<ResourceExchangeAgreement> getAgreement({
    required String expectedProfileId,
    required String requestId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_resource_exchange_agreement',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_request_id': requestId,
      },
    );
    if (response.length != 1) {
      throw const FormatException('Expected one Resource exchange agreement.');
    }
    return parser.agreement(response.single);
  }

  @override
  Future<List<ResourceExchangeTerms>> listTerms({
    required String expectedProfileId,
    required String agreementId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_resource_exchange_agreement_terms',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_agreement_id': agreementId,
      },
    );
    return List.unmodifiable(response.map(parser.terms));
  }

  @override
  Future<List<ResourceExchangeEvent>> listEvents({
    required String expectedProfileId,
    required String agreementId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_resource_exchange_agreement_events',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_agreement_id': agreementId,
      },
    );
    return List.unmodifiable(response.map(parser.event));
  }

  @override
  Future<String> recordMilestone({
    required String expectedProfileId,
    required String agreementId,
    required String expectedTermsId,
    required ResourceExchangeLegKind legKind,
    required ResourceExchangeMilestoneKind eventKind,
  }) async {
    final response = await _client.rpc<String>(
      'record_resource_exchange_milestone',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_agreement_id': agreementId,
        'p_expected_terms_id': expectedTermsId,
        'p_leg_kind': legKind.wireValue,
        'p_event_kind': eventKind.wireValue,
      },
    );
    return parser.uuidResult(response, 'Resource exchange milestone');
  }

  @override
  Future<String> proposeTerms({
    required String expectedProfileId,
    required String agreementId,
    required String? expectedCurrentTermsId,
    required String? expectedPendingTermsId,
    required ResourceExchangeTermsInput input,
  }) async {
    final response = await _client.rpc<String>(
      'propose_resource_exchange_terms',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_agreement_id': agreementId,
        'p_expected_current_terms_id': expectedCurrentTermsId,
        'p_expected_pending_terms_id': expectedPendingTermsId,
        'p_owner_transfer_kind': input.ownerTransferKind.wireValue,
        'p_owner_lend_starts_at': _timestamp(input.ownerLendStartsAt),
        'p_owner_lend_ends_at': _timestamp(input.ownerLendEndsAt),
        'p_requester_transfer_kind': input.requesterTransferKind.wireValue,
        'p_requester_resource_description': input.requesterResourceDescription,
        'p_requester_lend_starts_at': _timestamp(input.requesterLendStartsAt),
        'p_requester_lend_ends_at': _timestamp(input.requesterLendEndsAt),
        'p_private_note': input.privateNote,
      },
    );
    return parser.uuidResult(response, 'proposed Resource exchange terms');
  }

  @override
  Future<String> acceptPendingTerms({
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  }) => _pendingMutation(
    rpc: 'accept_resource_exchange_terms',
    expectedProfileId: expectedProfileId,
    agreementId: agreementId,
    expectedPendingTermsId: expectedPendingTermsId,
  );

  @override
  Future<String> rejectPendingTerms({
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  }) => _pendingMutation(
    rpc: 'reject_resource_exchange_terms',
    expectedProfileId: expectedProfileId,
    agreementId: agreementId,
    expectedPendingTermsId: expectedPendingTermsId,
  );

  @override
  Future<String> withdrawPendingTerms({
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  }) => _pendingMutation(
    rpc: 'withdraw_resource_exchange_terms',
    expectedProfileId: expectedProfileId,
    agreementId: agreementId,
    expectedPendingTermsId: expectedPendingTermsId,
  );

  Future<String> _pendingMutation({
    required String rpc,
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  }) async {
    final response = await _client.rpc<String>(
      rpc,
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_agreement_id': agreementId,
        'p_expected_pending_terms_id': expectedPendingTermsId,
      },
    );
    return parser.uuidResult(response, 'Resource exchange terms mutation');
  }

  @override
  Future<String> cancelAgreement({
    required String expectedProfileId,
    required String agreementId,
  }) async {
    final response = await _client.rpc<String>(
      'cancel_resource_exchange_agreement',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_agreement_id': agreementId,
      },
    );
    return parser.uuidResult(response, 'cancelled Resource exchange agreement');
  }

  static String? _timestamp(DateTime? value) =>
      value?.toUtc().toIso8601String();
}

class ResourceExchangePayloadParser {
  const ResourceExchangePayloadParser();

  static const _agreementKeys = {
    'agreement_id',
    'request_id',
    'listing_id',
    'owner_profile_id',
    'requester_profile_id',
    'lifecycle_state',
    'current_terms_id',
    'pending_terms_id',
    'current_terms_accepted_at',
    'created_at',
    'cancelled_at',
    'cancelled_by_profile_id',
    'completed_at',
    'owner_lend_return_overdue',
    'requester_lend_return_overdue',
  };
  static const _termsKeys = {
    'terms_id',
    'version_number',
    'proposed_by_profile_id',
    'listing_title_snapshot',
    'listing_description_snapshot',
    'owner_transfer_kind',
    'owner_lend_starts_at',
    'owner_lend_ends_at',
    'requester_transfer_kind',
    'requester_resource_description',
    'requester_lend_starts_at',
    'requester_lend_ends_at',
    'private_note',
    'created_at',
    'is_current',
    'is_pending',
  };
  static const _eventKeys = {
    'event_id',
    'event_kind',
    'terms_id',
    'leg_kind',
    'actor_profile_id',
    'actor_display_name',
    'created_at',
  };

  ResourceExchangeAgreement agreement(Object? value) {
    final row = _row(value, 'Resource exchange agreement');
    _exact(row, _agreementKeys, 'Resource exchange agreement');
    final lifecycle = ResourceExchangeLifecycle.fromWire(
      _string(row, 'lifecycle_state'),
    );
    final currentTermsId = _optionalUuid(row, 'current_terms_id');
    final pendingTermsId = _optionalUuid(row, 'pending_terms_id');
    final currentTermsAcceptedAt = _optionalDate(
      row,
      'current_terms_accepted_at',
    );
    final cancelledAt = _optionalDate(row, 'cancelled_at');
    final cancelledBy = _optionalUuid(row, 'cancelled_by_profile_id');
    final completedAt = _optionalDate(row, 'completed_at');

    if ((lifecycle == ResourceExchangeLifecycle.negotiating &&
            currentTermsId != null) ||
        ((lifecycle == ResourceExchangeLifecycle.agreed ||
                lifecycle == ResourceExchangeLifecycle.inProgress ||
                lifecycle == ResourceExchangeLifecycle.completed) &&
            currentTermsId == null) ||
        (currentTermsId == null) != (currentTermsAcceptedAt == null) ||
        (lifecycle == ResourceExchangeLifecycle.completed) !=
            (completedAt != null) ||
        (lifecycle == ResourceExchangeLifecycle.cancelled) !=
            (cancelledAt != null) ||
        (cancelledAt == null) != (cancelledBy == null) ||
        (lifecycle.isFrozen && pendingTermsId != null)) {
      throw const FormatException(
        'Resource exchange agreement lifecycle was inconsistent.',
      );
    }

    return ResourceExchangeAgreement(
      agreementId: _uuid(row, 'agreement_id'),
      requestId: _uuid(row, 'request_id'),
      listingId: _uuid(row, 'listing_id'),
      ownerProfileId: _uuid(row, 'owner_profile_id'),
      requesterProfileId: _uuid(row, 'requester_profile_id'),
      lifecycle: lifecycle,
      currentTermsId: currentTermsId,
      pendingTermsId: pendingTermsId,
      currentTermsAcceptedAt: currentTermsAcceptedAt,
      createdAt: _date(row, 'created_at'),
      cancelledAt: cancelledAt,
      cancelledByProfileId: cancelledBy,
      completedAt: completedAt,
      ownerLendReturnOverdue: _bool(row, 'owner_lend_return_overdue'),
      requesterLendReturnOverdue: _bool(row, 'requester_lend_return_overdue'),
    );
  }

  ResourceExchangeTerms terms(Object? value) {
    final row = _row(value, 'Resource exchange terms');
    _exact(row, _termsKeys, 'Resource exchange terms');
    final version = _positiveInt(row, 'version_number');
    final ownerKind = ResourceOwnerTransferKind.fromWire(
      _string(row, 'owner_transfer_kind'),
    );
    final ownerStartsAt = _optionalDate(row, 'owner_lend_starts_at');
    final ownerEndsAt = _optionalDate(row, 'owner_lend_ends_at');
    final requesterKind = ResourceRequesterTransferKind.fromWire(
      _string(row, 'requester_transfer_kind'),
    );
    final requesterDescription = _optionalString(
      row,
      'requester_resource_description',
    );
    final requesterStartsAt = _optionalDate(row, 'requester_lend_starts_at');
    final requesterEndsAt = _optionalDate(row, 'requester_lend_ends_at');
    final privateNote = _optionalString(row, 'private_note');
    final isCurrent = _bool(row, 'is_current');
    final isPending = _bool(row, 'is_pending');

    if (!_validTransfer(
          isLend: ownerKind == ResourceOwnerTransferKind.lend,
          startsAt: ownerStartsAt,
          endsAt: ownerEndsAt,
        ) ||
        !_validRequesterTransfer(
          kind: requesterKind,
          description: requesterDescription,
          startsAt: requesterStartsAt,
          endsAt: requesterEndsAt,
        ) ||
        (privateNote != null && privateNote.length > 1000) ||
        (isCurrent && isPending)) {
      throw const FormatException('Resource exchange terms were inconsistent.');
    }

    return ResourceExchangeTerms(
      termsId: _uuid(row, 'terms_id'),
      versionNumber: version,
      proposedByProfileId: _uuid(row, 'proposed_by_profile_id'),
      listingTitleSnapshot: _string(row, 'listing_title_snapshot'),
      listingDescriptionSnapshot: _string(row, 'listing_description_snapshot'),
      ownerTransferKind: ownerKind,
      ownerLendStartsAt: ownerStartsAt,
      ownerLendEndsAt: ownerEndsAt,
      requesterTransferKind: requesterKind,
      requesterResourceDescription: requesterDescription,
      requesterLendStartsAt: requesterStartsAt,
      requesterLendEndsAt: requesterEndsAt,
      privateNote: privateNote,
      createdAt: _date(row, 'created_at'),
      isCurrent: isCurrent,
      isPending: isPending,
    );
  }

  ResourceExchangeEvent event(Object? value) {
    final row = _row(value, 'Resource exchange event');
    _exact(row, _eventKeys, 'Resource exchange event');
    final kind = ResourceExchangeEventKind.fromWire(_string(row, 'event_kind'));
    final termsId = _optionalUuid(row, 'terms_id');
    final legKind = row['leg_kind'] == null
        ? null
        : ResourceExchangeLegKind.fromWire(_string(row, 'leg_kind'));
    final validShape = switch (kind) {
      ResourceExchangeEventKind.agreementCreated ||
      ResourceExchangeEventKind.agreementCancelled =>
        termsId == null && legKind == null,
      ResourceExchangeEventKind.termsProposed ||
      ResourceExchangeEventKind.termsSuperseded ||
      ResourceExchangeEventKind.termsAccepted ||
      ResourceExchangeEventKind.termsRejected ||
      ResourceExchangeEventKind.termsWithdrawn ||
      ResourceExchangeEventKind.agreementCompleted =>
        termsId != null && legKind == null,
      ResourceExchangeEventKind.resourceProvided ||
      ResourceExchangeEventKind.resourceReceived ||
      ResourceExchangeEventKind.resourceReturned ||
      ResourceExchangeEventKind.resourceReturnReceived =>
        termsId != null && legKind != null,
    };
    if (!validShape) {
      throw const FormatException(
        'Resource exchange event shape was inconsistent.',
      );
    }
    return ResourceExchangeEvent(
      eventId: _uuid(row, 'event_id'),
      kind: kind,
      termsId: termsId,
      legKind: legKind,
      actorProfileId: _uuid(row, 'actor_profile_id'),
      actorDisplayName: _string(row, 'actor_display_name'),
      createdAt: _date(row, 'created_at'),
    );
  }

  String uuidResult(Object? value, String label) {
    if (value is! String || !_uuidPattern.hasMatch(value)) {
      throw FormatException('$label did not return a UUID.');
    }
    return value;
  }

  bool _validRequesterTransfer({
    required ResourceRequesterTransferKind kind,
    required String? description,
    required DateTime? startsAt,
    required DateTime? endsAt,
  }) {
    if (kind == ResourceRequesterTransferKind.none) {
      return description == null && startsAt == null && endsAt == null;
    }
    if (description == null ||
        description.trim().length < 2 ||
        description.trim().length > 500) {
      return false;
    }
    return _validTransfer(
      isLend: kind == ResourceRequesterTransferKind.lend,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  bool _validTransfer({
    required bool isLend,
    required DateTime? startsAt,
    required DateTime? endsAt,
  }) => isLend
      ? startsAt != null && endsAt != null && endsAt.isAfter(startsAt)
      : startsAt == null && endsAt == null;

  Map<String, dynamic> _row(Object? value, String label) {
    if (value is! Map) throw FormatException('$label was not an object.');
    return value.cast<String, dynamic>();
  }

  void _exact(Map<String, dynamic> row, Set<String> keys, String label) {
    if (row.length != keys.length || !row.keys.toSet().containsAll(keys)) {
      throw FormatException('$label had an unexpected shape.');
    }
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key was not a non-empty string.');
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _string(row, key);

  String _uuid(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    if (!_uuidPattern.hasMatch(value)) {
      throw FormatException('$key was not a UUID.');
    }
    return value;
  }

  String? _optionalUuid(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _uuid(row, key);

  bool _bool(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) throw FormatException('$key was not a boolean.');
    return value;
  }

  int _positiveInt(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! int || value <= 0) {
      throw FormatException('$key was not a positive integer.');
    }
    return value;
  }

  DateTime _date(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String) throw FormatException('$key was not a timestamp.');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('$key was not a timestamp.');
    return parsed;
  }

  DateTime? _optionalDate(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _date(row, key);
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

final resourceExchangeGatewayProvider = Provider<ResourceExchangeGateway>((
  ref,
) {
  return SupabaseResourceExchangeGateway(ref.watch(supabaseClientProvider));
});
