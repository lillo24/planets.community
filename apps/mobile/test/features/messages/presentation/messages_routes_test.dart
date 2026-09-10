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
}
