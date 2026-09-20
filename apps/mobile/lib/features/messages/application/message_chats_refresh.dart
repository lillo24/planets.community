import 'package:flutter_riverpod/flutter_riverpod.dart';

class MessageChatsRefreshController extends Notifier<int> {
  @override
  int build() => 0;

  void notifyChanged() => state++;
}

final messageChatsRefreshProvider =
    NotifierProvider<MessageChatsRefreshController, int>(
      MessageChatsRefreshController.new,
    );
