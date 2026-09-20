import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/resource_exchange/data/resource_exchange_gateway.dart';
import 'package:planets_mobile/features/resource_exchange/domain/resource_exchange_models.dart';

void main() {
  const parser = ResourceExchangePayloadParser();

  test('parses every agreement lifecycle and overdue booleans', () {
    for (final lifecycle in ResourceExchangeLifecycle.values) {
      final agreement = parser.agreement(_agreementRow(lifecycle: lifecycle));
      expect(agreement.lifecycle, lifecycle);
      expect(agreement.ownerLendReturnOverdue, isTrue);
      expect(agreement.requesterLendReturnOverdue, isFalse);
    }
  });

  test('cancelled agreement accepts either current terms shape', () {
    expect(
      parser
          .agreement(
            _agreementRow(
              lifecycle: ResourceExchangeLifecycle.cancelled,
              cancelledHasCurrent: false,
            ),
          )
          .currentTermsId,
      isNull,
    );
    expect(
      parser
          .agreement(
            _agreementRow(lifecycle: ResourceExchangeLifecycle.cancelled),
          )
          .currentTermsId,
      _termsId,
    );
  });

  test(
    'agreement parser rejects invalid pointers and lifecycle timestamps',
    () {
      expect(
        () =>
            parser.agreement(_agreementRow()..['current_terms_id'] = _termsId),
        throwsFormatException,
      );
      expect(
        () => parser.agreement(
          _agreementRow(lifecycle: ResourceExchangeLifecycle.completed)
            ..['completed_at'] = null,
        ),
        throwsFormatException,
      );
      expect(
        () => parser.agreement(
          _agreementRow(lifecycle: ResourceExchangeLifecycle.inProgress)
            ..['pending_terms_id'] = _pendingId,
        ),
        throwsFormatException,
      );
      expect(
        () => parser.agreement({..._agreementRow(), 'unexpected': true}),
        throwsFormatException,
      );
    },
  );

  test('terms parser accepts every transfer combination', () {
    for (final owner in ResourceOwnerTransferKind.values) {
      for (final requester in ResourceRequesterTransferKind.values) {
        final terms = parser.terms(
          _termsRow(owner: owner, requester: requester),
        );
        expect(terms.ownerTransferKind, owner);
        expect(terms.requesterTransferKind, requester);
      }
    }
  });

  test('terms parser rejects invalid dates, description, note, and flags', () {
    expect(
      () => parser.terms(
        _termsRow(owner: ResourceOwnerTransferKind.lend)
          ..['owner_lend_ends_at'] = '2026-09-20T10:00:00Z',
      ),
      throwsFormatException,
    );
    expect(
      () => parser.terms(
        _termsRow(requester: ResourceRequesterTransferKind.give)
          ..['requester_resource_description'] = 'x',
      ),
      throwsFormatException,
    );
    expect(
      () => parser.terms(_termsRow()..['private_note'] = 'x' * 1001),
      throwsFormatException,
    );
    expect(
      () => parser.terms(
        _termsRow()
          ..['is_current'] = true
          ..['is_pending'] = true,
      ),
      throwsFormatException,
    );
    for (final malformed in <Map<String, dynamic>>[
      _termsRow()..['is_current'] = null,
      _termsRow()..['is_pending'] = null,
      _termsRow()..remove('is_current'),
      _termsRow()..remove('is_pending'),
      _termsRow()..['is_current'] = 'false',
      _termsRow()..['is_pending'] = 0,
    ]) {
      expect(() => parser.terms(malformed), throwsFormatException);
    }
  });

  test('parses corrected pending, current, and historical boolean shapes', () {
    final pending = parser.terms(
      _termsRow()
        ..['is_current'] = false
        ..['is_pending'] = true,
    );
    final current = parser.terms(
      _termsRow()
        ..['is_current'] = true
        ..['is_pending'] = false,
    );
    final historical = parser.terms(
      _termsRow()
        ..['is_current'] = false
        ..['is_pending'] = false,
    );

    expect((pending.isCurrent, pending.isPending), (false, true));
    expect((current.isCurrent, current.isPending), (true, false));
    expect((historical.isCurrent, historical.isPending), (false, false));
  });

  test('sanitized real-OTP RPC projection parses and reconciles', () {
    final fixture = jsonDecode(
      File('test/fixtures/resource_exchange_terms_projection.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final agreement = parser.agreement(fixture['agreement']);
    final terms = (fixture['terms'] as List<dynamic>).map(parser.terms);
    final snapshot = ResourceExchangeSnapshot.reconcile(
      agreement: agreement,
      terms: terms,
    );

    expect(snapshot.currentTerms?.termsId, agreement.currentTermsId);
    expect(snapshot.pendingTerms, isNull);
    expect(snapshot.terms.map((item) => (item.isCurrent, item.isPending)), [
      (true, false),
      (false, false),
    ]);
  });

  test('mutation UUID result is strict', () {
    expect(parser.uuidResult(_termsId, 'terms'), _termsId);
    expect(
      () => parser.uuidResult('not-an-id', 'terms'),
      throwsFormatException,
    );
  });

  test('gateway owns exact RPC and CAS parameter contracts', () {
    final source = File(
      'lib/features/resource_exchange/data/resource_exchange_gateway.dart',
    ).readAsStringSync();

    for (final rpc in [
      'get_resource_exchange_agreement',
      'list_resource_exchange_agreement_terms',
      'propose_resource_exchange_terms',
      'accept_resource_exchange_terms',
      'reject_resource_exchange_terms',
      'withdraw_resource_exchange_terms',
      'cancel_resource_exchange_agreement',
    ]) {
      expect(source, contains("'$rpc'"));
    }
    for (final parameter in [
      'p_expected_profile_id',
      'p_agreement_id',
      'p_expected_current_terms_id',
      'p_expected_pending_terms_id',
      'p_owner_transfer_kind',
      'p_owner_lend_starts_at',
      'p_owner_lend_ends_at',
      'p_requester_transfer_kind',
      'p_requester_resource_description',
      'p_requester_lend_starts_at',
      'p_requester_lend_ends_at',
      'p_private_note',
    ]) {
      expect(source, contains("'$parameter'"));
    }
    expect(source, isNot(contains(".from('resource_exchange")));
  });
}

const _agreementId = '00000000-0000-4000-8000-000000000501';
const _requestId = '00000000-0000-4000-8000-000000000301';
const _listingId = '00000000-0000-4000-8000-000000000201';
const _ownerId = '00000000-0000-4000-8000-000000000101';
const _requesterId = '00000000-0000-4000-8000-000000000102';
const _termsId = '00000000-0000-4000-8000-000000000701';
const _pendingId = '00000000-0000-4000-8000-000000000702';

Map<String, dynamic> _agreementRow({
  ResourceExchangeLifecycle lifecycle = ResourceExchangeLifecycle.negotiating,
  bool cancelledHasCurrent = true,
}) {
  final hasCurrent = switch (lifecycle) {
    ResourceExchangeLifecycle.negotiating => false,
    ResourceExchangeLifecycle.cancelled => cancelledHasCurrent,
    _ => true,
  };
  return {
    'agreement_id': _agreementId,
    'request_id': _requestId,
    'listing_id': _listingId,
    'owner_profile_id': _ownerId,
    'requester_profile_id': _requesterId,
    'lifecycle_state': lifecycle.wireValue,
    'current_terms_id': hasCurrent ? _termsId : null,
    'pending_terms_id': null,
    'current_terms_accepted_at': hasCurrent ? '2026-09-20T10:00:00Z' : null,
    'created_at': '2026-09-19T10:00:00Z',
    'cancelled_at': lifecycle == ResourceExchangeLifecycle.cancelled
        ? '2026-09-20T12:00:00Z'
        : null,
    'cancelled_by_profile_id': lifecycle == ResourceExchangeLifecycle.cancelled
        ? _ownerId
        : null,
    'completed_at': lifecycle == ResourceExchangeLifecycle.completed
        ? '2026-09-20T12:00:00Z'
        : null,
    'owner_lend_return_overdue': true,
    'requester_lend_return_overdue': false,
  };
}

Map<String, dynamic> _termsRow({
  ResourceOwnerTransferKind owner = ResourceOwnerTransferKind.give,
  ResourceRequesterTransferKind requester = ResourceRequesterTransferKind.none,
}) => {
  'terms_id': _termsId,
  'version_number': 1,
  'proposed_by_profile_id': _ownerId,
  'listing_title_snapshot': 'Garden tools',
  'listing_description_snapshot': 'A durable set of garden tools.',
  'owner_transfer_kind': owner.wireValue,
  'owner_lend_starts_at': owner == ResourceOwnerTransferKind.lend
      ? '2026-09-20T10:00:00Z'
      : null,
  'owner_lend_ends_at': owner == ResourceOwnerTransferKind.lend
      ? '2026-09-21T10:00:00Z'
      : null,
  'requester_transfer_kind': requester.wireValue,
  'requester_resource_description': requester.requiresDescription
      ? 'A wheelbarrow'
      : null,
  'requester_lend_starts_at': requester == ResourceRequesterTransferKind.lend
      ? '2026-09-20T10:00:00Z'
      : null,
  'requester_lend_ends_at': requester == ResourceRequesterTransferKind.lend
      ? '2026-09-21T10:00:00Z'
      : null,
  'private_note': 'Meet near the community garden.',
  'created_at': '2026-09-20T09:00:00Z',
  'is_current': false,
  'is_pending': true,
};
