import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all required identity surfaces compose the shared blocking action', () {
    final contracts = <String, List<String>>{
      'lib/features/proposals/presentation/public_proposals_screen.dart': [
        'proposal-blocking-action',
      ],
      'lib/features/recurring_activities/presentation/public_recurring_activities_screen.dart':
          ['tavoli-blocking-action'],
      'lib/features/resource_listings/presentation/public_resource_listings_screen.dart':
          [
            'resource-listing-blocking-action',
            'resource-request-blocked-explanation',
          ],
      'lib/features/participation/presentation/creator_participation_screen.dart':
          ['participation-block-', 'participation-member-block-'],
      'lib/features/resource_requests/presentation/resource_request_screen.dart':
          ['resource-request-blocking-action'],
      'lib/features/resource_chat/presentation/resource_chat_screen.dart': [
        'resource-chat-blocking-action',
        'acceptedResourceCoordination',
      ],
      'lib/features/project_chat/presentation/project_chat_screen.dart': [
        'project-chat-block-',
        'project-chat-report-',
      ],
    };

    for (final entry in contracts.entries) {
      final source = File(entry.key).readAsStringSync();
      expect(source, contains('BlockingActionButton'));
      for (final marker in entry.value) {
        expect(source, contains(marker), reason: '${entry.key}: $marker');
      }
    }
  });

  test('shared copy does not describe inbound or reciprocal state', () {
    final action = File(
      'lib/features/blocking/presentation/blocking_action.dart',
    ).readAsStringSync();
    final catalog = Map<String, Object?>.from(
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map,
    );
    final blockingCopy = catalog.entries
        .where((entry) => entry.key.startsWith('blocking'))
        .map((entry) => entry.value)
        .whereType<String>()
        .join('\n');
    expect(action, isNot(contains('target blocks')));
    expect(blockingCopy, isNot(contains('blocked you')));
    expect(blockingCopy, isNot(contains('one of you')));
    expect(
      blockingCopy,
      contains("This interaction isn't available right now."),
    );
  });
}
