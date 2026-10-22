import '../domain/activity_interest_event.dart';

enum ActivityInterestDelivery {
  ready,
  captured,
  disabled,
  permissionDenied,
  unsupportedSdkPrivacy,
  invalidConfiguration,
  failed,
  disposed,
}

abstract interface class ActivityInterestSink {
  bool get available;
  Future<ActivityInterestDelivery> capture(
    ActivityInterestEvent event, {
    required bool Function() isAllowed,
  });
  void dispose();
}

final class NoopActivityInterestSink implements ActivityInterestSink {
  const NoopActivityInterestSink();
  @override
  bool get available => false;
  @override
  Future<ActivityInterestDelivery> capture(
    ActivityInterestEvent event, {
    required bool Function() isAllowed,
  }) async => ActivityInterestDelivery.disabled;
  @override
  void dispose() {}
}
