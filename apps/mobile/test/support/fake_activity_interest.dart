import 'package:planets_mobile/features/activity_interest/application/activity_interest_tracker.dart';
import 'package:planets_mobile/features/activity_interest/data/activity_interest_sink.dart';
import 'package:planets_mobile/features/activity_interest/domain/activity_interest_event.dart';

final class FakeActivityInterestPermission
    implements ActivityInterestPermissionPolicy {
  @override
  bool allowed = true;
}

final class MemoryActivityInterestSink implements ActivityInterestSink {
  final events = <ActivityInterestEvent>[];
  Future<void>? delay;
  Object? failure;
  int calls = 0;
  int disposals = 0;
  @override
  bool get available => true;
  @override
  Future<ActivityInterestDelivery> capture(
    ActivityInterestEvent event, {
    required bool Function() isAllowed,
  }) async {
    calls++;
    if (delay case final delay?) await delay;
    if (!isAllowed()) return ActivityInterestDelivery.permissionDenied;
    if (failure case final failure?) throw failure;
    events.add(event);
    return ActivityInterestDelivery.captured;
  }

  @override
  void dispose() => disposals++;
}

ActivityInterestTracker memoryActivityInterestTracker(
  MemoryActivityInterestSink sink, {
  FakeActivityInterestPermission? permission,
}) => ActivityInterestTracker(
  isAllowed: () => permission?.allowed ?? true,
  sinkFactory: () => sink,
);
