import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProjectChatRefreshController extends Notifier<int> {
  @override
  int build() => 0;

  void notifyChanged() => state++;
}

final projectChatRefreshProvider =
    NotifierProvider<ProjectChatRefreshController, int>(
      ProjectChatRefreshController.new,
    );
