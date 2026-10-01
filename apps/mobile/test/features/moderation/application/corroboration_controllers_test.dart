import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/moderation/application/corroboration_controllers.dart';
import 'package:planets_mobile/features/moderation/data/corroboration_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/corroboration_models.dart';

import '../../../support/fake_moderation.dart';

const profileId = '00000000-0000-4000-8000-000000000001';

void main() {
  const requestId = '00000000-0000-4000-8000-000000000911';

  test('blocks duplicate taps and retains one retry key', () async {
    final delay = Completer<void>();
    final gateway = FakeCorroborationGateway()..submitDelay = delay.future;
    final container = _container(gateway);
    addTearDown(container.dispose);
    final controller = container.read(
      corroborationDetailProvider(requestId).notifier,
    );
    expect(await controller.load(profileId), isTrue);

    final first = controller.submit(
      expectedProfileId: profileId,
      choice: CorroborationChoice.unsure,
      explanation: '',
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      await controller.submit(
        expectedProfileId: profileId,
        choice: CorroborationChoice.unsure,
        explanation: '',
      ),
      isFalse,
    );
    delay.complete();
    expect(await first, isTrue);
    expect(gateway.submitCount, 1);
    expect(gateway.clientSubmissionId, 'corroboration-submission-id');
  });

  test('account switch discards a late private response result', () async {
    final delay = Completer<void>();
    final gateway = FakeCorroborationGateway()..submitDelay = delay.future;
    final container = _container(gateway);
    addTearDown(container.dispose);
    final controller = container.read(
      corroborationDetailProvider(requestId).notifier,
    );
    await controller.load(profileId);
    final pending = controller.submit(
      expectedProfileId: profileId,
      choice: CorroborationChoice.agree,
      explanation: 'Private context.',
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
      container.read(corroborationDetailProvider(requestId)).detail,
      isNull,
    );
  });
}

ProviderContainer _container(FakeCorroborationGateway gateway) {
  final container = ProviderContainer(
    overrides: [
      corroborationGatewayProvider.overrideWithValue(gateway),
      corroborationSubmissionIdGeneratorProvider.overrideWithValue(
        () => 'corroboration-submission-id',
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: profileId));
  return container;
}
