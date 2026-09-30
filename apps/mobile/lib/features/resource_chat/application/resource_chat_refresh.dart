import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResourceChatRefreshController extends Notifier<int> {
  @override
  int build() => 0;

  void notifyChanged() => state++;
}

final resourceChatRefreshProvider =
    NotifierProvider<ResourceChatRefreshController, int>(
      ResourceChatRefreshController.new,
    );
