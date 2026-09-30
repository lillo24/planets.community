import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/resource_loans/data/resource_loan_gateway.dart';
import 'package:planets_mobile/features/resource_loans/domain/resource_loan_models.dart';

import '../../../support/fake_resource_loan.dart';

void main() {
  const parser = ResourceLoanPayloadParser();

  test('parses both active lifecycle values and independent risk flags', () {
    for (final lifecycle in ResourceLoanLifecycle.values) {
      final row = _reservationRow()
        ..['agreement_lifecycle'] = lifecycle.wireValue;
      final reservation = parser.reservation(row);
      expect(reservation.agreementLifecycle, lifecycle);
      expect(reservation.isOverdue, isTrue);
      expect(reservation.isAtRisk, isTrue);
      expect(reservation.startsAt.isBefore(reservation.endsAt), isTrue);
    }
    final overdueOnly = parser.reservation(
      _reservationRow()..['is_at_risk'] = false,
    );
    final riskOnly = parser.reservation(
      _reservationRow()..['is_overdue'] = false,
    );
    expect((overdueOnly.isOverdue, overdueOnly.isAtRisk), (true, false));
    expect((riskOnly.isOverdue, riskOnly.isAtRisk), (false, true));
  });

  test('rejects malformed schedule rows and unsupported lifecycle', () {
    final invalid = <Map<String, dynamic>>[
      _reservationRow()..['listing_id'] = 'not-a-uuid',
      _reservationRow()..['requester_display_name'] = '  ',
      _reservationRow()..['ends_at'] = '2026-09-24T10:00:00Z',
      _reservationRow()..['agreement_lifecycle'] = 'completed',
      _reservationRow()..['is_overdue'] = null,
      _reservationRow()..['is_at_risk'] = 'false',
      _reservationRow()..remove('terms_id'),
      {..._reservationRow(), 'private_note': 'must not leak'},
    ];
    for (final row in invalid) {
      expect(() => parser.reservation(row), throwsFormatException);
    }
  });

  test('availability requires exactly one row and real booleans', () {
    final result = parser.availability([
      {'is_lend': true, 'is_available': false},
    ]);
    expect(result.isLend, isTrue);
    expect(result.isAvailable, isFalse);
    for (final response in <Object?>[
      [],
      [
        {'is_lend': true, 'is_available': false},
        {'is_lend': true, 'is_available': true},
      ],
      [
        {'is_lend': null, 'is_available': true},
      ],
      [
        {'is_lend': true, 'is_available': 'false'},
      ],
      [
        {'is_lend': true, 'is_available': true, 'requester': 'private'},
      ],
    ]) {
      expect(() => parser.availability(response), throwsFormatException);
    }
  });

  test('gateway owns only the two exact D1 RPC contracts', () {
    final source = File(
      'lib/features/resource_loans/data/resource_loan_gateway.dart',
    ).readAsStringSync();
    expect(source, contains("'list_owned_resource_listing_loan_schedule'"));
    expect(
      source,
      contains("'check_resource_exchange_pending_loan_availability'"),
    );
    for (final parameter in [
      'p_expected_owner_profile_id',
      'p_listing_id',
      'p_expected_profile_id',
      'p_agreement_id',
      'p_expected_pending_terms_id',
    ]) {
      expect(source, contains("'$parameter'"));
    }
    expect(source, isNot(contains(".from('resource_")));
  });
}

Map<String, dynamic> _reservationRow() => {
  'listing_id': loanListingId,
  'agreement_id': loanAgreementId,
  'request_id': loanRequestId,
  'terms_id': loanTermsId,
  'requester_profile_id': loanRequesterId,
  'requester_display_name': 'Anna',
  'starts_at': '2026-09-24T10:00:00Z',
  'ends_at': '2026-09-26T18:00:00Z',
  'agreement_lifecycle': 'agreed',
  'is_overdue': true,
  'is_at_risk': true,
};
