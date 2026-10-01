import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Project Needs is RPC-only and chat detail uses the mixed feed', () {
    final needsSource = File(
      'lib/features/project_chat/data/project_needs_gateway.dart',
    ).readAsStringSync();
    final chatSource = File(
      'lib/features/project_chat/data/project_chat_gateway.dart',
    ).readAsStringSync();

    for (final rpc in const [
      'list_project_live_requirement_coverage',
      'claim_project_requirement',
      'set_project_requirement_manual_coverage_as_manager',
      'get_own_project_requirement_attention',
      'acknowledge_project_requirement_attention',
    ]) {
      expect(needsSource, contains("'$rpc'"));
    }
    expect(needsSource, isNot(contains('.from(')));
    expect(chatSource, contains("'list_own_project_chat_feed'"));
    expect(chatSource, isNot(contains("'list_own_project_chat_messages'")));
  });
}
