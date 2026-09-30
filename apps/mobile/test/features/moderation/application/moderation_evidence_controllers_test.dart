import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/moderation/application/moderation_evidence_controllers.dart';
import 'package:planets_mobile/features/moderation/data/moderation_evidence_gateway.dart';

import '../../../support/fake_moderation.dart';

const profileId = '00000000-0000-4000-8000-000000000001';

void main() {
  test('loads the unified history for the current profile', () async {
    final gateway = FakeModerationEvidenceGateway()
      ..items = [moderationEvidenceSummaryFixture()];
    final container = _container(gateway);
    addTearDown(container.dispose);

    expect(
      await container
          .read(moderationEvidenceRequestsProvider.notifier)
          .load(profileId),
      isTrue,
    );
    expect(gateway.pendingOnly, isFalse);
    expect(
      container.read(moderationEvidenceRequestsProvider).items,
      hasLength(1),
    );
  });

  test('account switch discards a late private list result', () async {
    final delay = Completer<void>();
    final gateway = FakeModerationEvidenceGateway()
      ..items = [moderationEvidenceSummaryFixture()]
      ..listDelay = delay.future;
    final container = _container(gateway);
    addTearDown(container.dispose);
    final pending = container
        .read(moderationEvidenceRequestsProvider.notifier)
        .load(profileId);
    await Future<void>.delayed(Duration.zero);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(
          const AuthIdentity(id: '00000000-0000-4000-8000-000000000099'),
        );
    delay.complete();

    expect(await pending, isFalse);
    expect(container.read(moderationEvidenceRequestsProvider).items, isEmpty);
  });
}

ProviderContainer _container(FakeModerationEvidenceGateway gateway) {
  final container = ProviderContainer(
    overrides: [moderationEvidenceGatewayProvider.overrideWithValue(gateway)],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: profileId));
  return container;
}
