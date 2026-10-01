import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/moderation/application/moderation_controllers.dart';
import 'package:planets_mobile/features/moderation/data/moderation_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_models.dart';

import '../../../support/fake_moderation.dart';

void main() {
  const profileId = '00000000-0000-4000-8000-000000000001';
  const target = ModerationReportTarget(
    kind: ModerationTargetKind.project,
    id: '00000000-0000-4000-8000-000000000101',
    label: 'Community garden',
  );

  test(
    'duplicate submit is blocked and one idempotency key is retained',
    () async {
      final delay = Completer<void>();
      final gateway = FakeModerationGateway()..submitDelay = delay.future;
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(moderationSubmissionProvider.notifier);

      final first = controller.submit(
        expectedProfileId: profileId,
        target: target,
        category: ModerationCategory.other,
        explanation: 'A sufficiently clear explanation.',
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        await controller.submit(
          expectedProfileId: profileId,
          target: target,
          category: ModerationCategory.other,
          explanation: 'A sufficiently clear explanation.',
        ),
        isFalse,
      );
      delay.complete();
      expect(await first, isTrue);
      expect(gateway.submitCount, 1);
      expect(gateway.clientSubmissionId, 'submission-id');
    },
  );

  test('account switch discards a late private submission result', () async {
    final delay = Completer<void>();
    final gateway = FakeModerationGateway()..submitDelay = delay.future;
    final container = _container(gateway);
    addTearDown(container.dispose);
    final controller = container.read(moderationSubmissionProvider.notifier);
    final pending = controller.submit(
      expectedProfileId: profileId,
      target: target,
      category: ModerationCategory.other,
      explanation: 'A sufficiently clear explanation.',
    );
    await Future<void>.delayed(Duration.zero);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(
          const AuthIdentity(id: '00000000-0000-4000-8000-000000000099'),
        );
    delay.complete();
    expect(await pending, isFalse);
    expect(
      container.read(moderationSubmissionProvider).phase,
      ModerationSubmissionPhase.idle,
    );
  });
}

ProviderContainer _container(FakeModerationGateway gateway) {
  final container = ProviderContainer(
    overrides: [
      moderationGatewayProvider.overrideWithValue(gateway),
      moderationSubmissionIdGeneratorProvider.overrideWithValue(
        () => 'submission-id',
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(
        const AuthIdentity(id: '00000000-0000-4000-8000-000000000001'),
      );
  return container;
}
