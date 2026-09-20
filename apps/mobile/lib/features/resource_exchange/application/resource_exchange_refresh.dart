import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResourceExchangeRefreshController extends Notifier<int> {
  @override
  int build() => 0;

  void notifyChanged() => state++;
}

final resourceExchangeRefreshProvider =
    NotifierProvider<ResourceExchangeRefreshController, int>(
      ResourceExchangeRefreshController.new,
    );
