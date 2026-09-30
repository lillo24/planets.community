import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/resource_loan_models.dart';

abstract interface class ResourceLoanGateway {
  Future<List<ResourceLoanReservation>> listOwnedSchedule({
    required String expectedOwnerProfileId,
    required String listingId,
  });

  Future<PendingLoanAvailability> checkPendingAvailability({
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  });
}

class SupabaseResourceLoanGateway implements ResourceLoanGateway {
  const SupabaseResourceLoanGateway(this._client);

  final SupabaseClient _client;
  static const parser = ResourceLoanPayloadParser();

  @override
  Future<List<ResourceLoanReservation>> listOwnedSchedule({
    required String expectedOwnerProfileId,
    required String listingId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_owned_resource_listing_loan_schedule',
      params: {
        'p_expected_owner_profile_id': expectedOwnerProfileId,
        'p_listing_id': listingId,
      },
    );
    return List.unmodifiable(response.map(parser.reservation));
  }

  @override
  Future<PendingLoanAvailability> checkPendingAvailability({
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'check_resource_exchange_pending_loan_availability',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_agreement_id': agreementId,
        'p_expected_pending_terms_id': expectedPendingTermsId,
      },
    );
    return parser.availability(response);
  }
}

class ResourceLoanPayloadParser {
  const ResourceLoanPayloadParser();

  static const _reservationKeys = {
    'listing_id',
    'agreement_id',
    'request_id',
    'terms_id',
    'requester_profile_id',
    'requester_display_name',
    'starts_at',
    'ends_at',
    'agreement_lifecycle',
    'is_overdue',
    'is_at_risk',
  };
  static const _availabilityKeys = {'is_lend', 'is_available'};
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  ResourceLoanReservation reservation(Object? value) {
    final row = _row(value, _reservationKeys);
    final start = _timestamp(row['starts_at']);
    final end = _timestamp(row['ends_at']);
    if (!end.isAfter(start)) {
      throw const FormatException('Invalid active loan period.');
    }
    final name = _string(row['requester_display_name']).trim();
    if (name.isEmpty) {
      throw const FormatException('Missing requester display name.');
    }
    return ResourceLoanReservation(
      listingId: _id(row['listing_id']),
      agreementId: _id(row['agreement_id']),
      requestId: _id(row['request_id']),
      termsId: _id(row['terms_id']),
      requesterProfileId: _id(row['requester_profile_id']),
      requesterDisplayName: name,
      startsAt: start,
      endsAt: end,
      agreementLifecycle: ResourceLoanLifecycle.fromWire(
        _string(row['agreement_lifecycle']),
      ),
      isOverdue: _boolean(row['is_overdue']),
      isAtRisk: _boolean(row['is_at_risk']),
    );
  }

  PendingLoanAvailability availability(Object? value) {
    if (value is! List || value.length != 1) {
      throw const FormatException(
        'Expected one pending loan availability row.',
      );
    }
    final row = _row(value.single, _availabilityKeys);
    return PendingLoanAvailability(
      isLend: _boolean(row['is_lend']),
      isAvailable: _boolean(row['is_available']),
    );
  }

  Map<String, dynamic> _row(Object? value, Set<String> keys) {
    if (value is! Map<String, dynamic> ||
        value.length != keys.length ||
        !value.keys.toSet().containsAll(keys)) {
      throw const FormatException('Unexpected Resource loan row.');
    }
    return value;
  }

  String _string(Object? value) {
    if (value is! String) throw const FormatException('Expected text.');
    return value;
  }

  String _id(Object? value) {
    final id = _string(value);
    if (!_uuid.hasMatch(id)) throw const FormatException('Expected UUID.');
    return id;
  }

  DateTime _timestamp(Object? value) {
    final raw = _string(value);
    if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
      throw const FormatException('Expected timestamp with zone.');
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) throw const FormatException('Invalid timestamp.');
    return parsed;
  }

  bool _boolean(Object? value) {
    if (value is! bool) throw const FormatException('Expected boolean.');
    return value;
  }
}

final resourceLoanGatewayProvider = Provider<ResourceLoanGateway>(
  (ref) => SupabaseResourceLoanGateway(ref.read(supabaseClientProvider)),
);
