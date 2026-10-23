import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/settings/application/presentation_mode_selection.dart';
import 'package:planets_mobile/features/settings/application/activities_split_preference_controller.dart';
import 'package:planets_mobile/features/settings/application/co_creation_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/activities_split_preference_store.dart';
import 'package:planets_mobile/features/settings/data/co_creation_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/activities_split_preference.dart';

import '../../../support/fake_settings.dart';

void main() {
  ProviderContainer app(
    FakeCoCreationPreferenceStore people,
    FakeActivitiesSplitPreferenceStore activities,
  ) => ProviderContainer(
    overrides: [
      coCreationPreferenceStoreProvider.overrideWithValue(people),
      activitiesSplitPreferenceStoreProvider.overrideWithValue(activities),
      initialActivitiesSplitPreferenceProvider.overrideWithValue(
        const ActivitiesSplitPreferenceState(mode: ActivitiesSplitMode.on),
      ),
    ],
  );
  test('selecting either presentation persists the other OFF', () async {
    final people = FakeCoCreationPreferenceStore(),
        activities = FakeActivitiesSplitPreferenceStore(value: 'on');
    final scope = app(people, activities);
    addTearDown(scope.dispose);
    final selection = scope.read(presentationModeSelectionProvider.notifier);
    expect(await selection.select(people: true, enabled: true), isTrue);
    expect(scope.read(coCreationPreferenceProvider).enabled, isTrue);
    expect(scope.read(activitiesSplitPreferenceProvider).enabled, isFalse);
    expect(activities.value, 'off');
    expect(await selection.select(people: false, enabled: true), isTrue);
    expect(scope.read(coCreationPreferenceProvider).enabled, isFalse);
    expect(people.value, 'off');
    expect(scope.read(activitiesSplitPreferenceProvider).enabled, isTrue);
  });
  test('failed deactivation cannot enable both presentations', () async {
    final people = FakeCoCreationPreferenceStore(),
        activities = FakeActivitiesSplitPreferenceStore(value: 'on')
          ..writeError = StateError('disk');
    final scope = app(people, activities);
    addTearDown(scope.dispose);
    expect(
      await scope
          .read(presentationModeSelectionProvider.notifier)
          .select(people: true, enabled: true),
      isFalse,
    );
    expect(scope.read(coCreationPreferenceProvider).enabled, isFalse);
    expect(people.writes, isEmpty);
  });
  test('parallel toggles share one serialized selection', () async {
    final delay = Completer<void>(),
        people = FakeCoCreationPreferenceStore(),
        activities = FakeActivitiesSplitPreferenceStore()
          ..writeDelay = delay.future;
    final scope = app(people, activities);
    addTearDown(scope.dispose);
    final selection = scope.read(presentationModeSelectionProvider.notifier);
    final first = selection.select(people: true, enabled: true);
    expect(await selection.select(people: false, enabled: true), isFalse);
    delay.complete();
    expect(await first, isTrue);
    expect(scope.read(presentationModeSelectionProvider), isFalse);
  });
}
