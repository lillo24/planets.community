import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/messages/presentation/messages_routes.dart';

void main() {
  test('participation request messages have a stable semantic route', () {
    expect(
      participationRequestMessageRoute('request/with space'),
      '/messages/requests/request%2Fwith%20space',
    );
    expect(isMessagesPath('/messages/requests/request-1'), isTrue);
    expect(isMessagesPath('/proposals/request-1'), isFalse);
  });

  test('project chats and group info have encoded stable routes', () {
    expect(
      projectChatRoute('chat/with space'),
      '/messages/chats/chat%2Fwith%20space',
    );
    expect(
      projectChatInfoRoute('chat/with space'),
      '/messages/chats/chat%2Fwith%20space/info',
    );
    expect(isMessagesPath('/messages/chats/chat-1'), isTrue);
    expect(isMessagesPath('/messages/chats/chat-1/info'), isTrue);
  });
}
