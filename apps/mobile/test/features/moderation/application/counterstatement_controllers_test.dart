import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/moderation/application/counterstatement_controllers.dart';
import 'package:planets_mobile/features/moderation/data/counterstatement_gateway.dart';

import '../../../support/fake_moderation.dart';

const profileId = '00000000-0000-4000-8000-000000000001';
const requestId = '00000000-0000-4000-8000-000000000921';

void main() {
  test('blocks duplicate taps and retains one retry key', () async {
    final delay = Completer<void>();
    final gateway = FakeCounterstatementGateway()..submitDelay = delay.future;
    final container = _container(gateway);
    addTearDown(container.dispose);
    final controller = container.read(
      counterstatementDetailProvider(requestId).notifier,
    );
    expect(await controller.load(profileId), isTrue);

    final first = controller.submit(
      expectedProfileId: profileId,
      statement: 'My private response.',
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      await controller.submit(
        expectedProfileId: profileId,
        statement: 'My private response.',
      ),
      isFalse,
    );
    delay.complete();
    expect(await first, isTrue);
    expect(gateway.submitCount, 1);
    expect(gateway.clientSubmissionId, 'counterstatement-submission-id');
    expect(
      container
          .read(counterstatementDetailProvider(requestId))
          .detail
          ?.statement,
      'My private response.',
    );
  });

  test('account switch discards a late private response result', () async {
    final delay = Completer<void>();
    final gateway = FakeCounterstatementGateway()..submitDelay = delay.future;
    final container = _container(gateway);
    addTearDown(container.dispose);
    final controller = container.read(
      counterstatementDetailProvider(requestId).notifier,
    );
    await controller.load(profileId);
    final pending = controller.submit(
      expectedProfileId: profileId,
      statement: 'My private response.',
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
      container.read(counterstatementDetailProvider(requestId)).detail,
      isNull,
    );
  });

  test('a failed submit retries with the same client identity', () async {
    var generatedIds = 0;
    final gateway = FakeCounterstatementGateway()
      ..submitError = StateError('offline');
    final container = _container(
      gateway,
      submissionIdGenerator: () => 'retry-${++generatedIds}',
    );
    addTearDown(container.dispose);
    final controller = container.read(
      counterstatementDetailProvider(requestId).notifier,
    );
    await controller.load(profileId);

    expect(
      await controller.submit(
        expectedProfileId: profileId,
        statement: 'My private response.',
      ),
      isFalse,
    );
    gateway.submitError = null;
    expect(
      await controller.submit(
        expectedProfileId: profileId,
        statement: 'My private response.',
      ),
      isTrue,
    );
    expect(generatedIds, 1);
    expect(gateway.clientSubmissionId, 'retry-1');
  });
}

ProviderContainer _container(
  FakeCounterstatementGateway gateway, {
  CounterstatementSubmissionIdGenerator? submissionIdGenerator,
}) {
  final container = ProviderContainer(
    overrides: [
      counterstatementGatewayProvider.overrideWithValue(gateway),
      counterstatementSubmissionIdGeneratorProvider.overrideWithValue(
        submissionIdGenerator ?? () => 'counterstatement-submission-id',
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: profileId));
  return container;
}
