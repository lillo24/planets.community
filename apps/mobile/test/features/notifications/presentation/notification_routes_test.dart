import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/notifications/presentation/notification_routes.dart';

void main() {
  test('Notifications routes stay within their guarded Home namespace', () {
    expect(isNotificationsPath('/notifications'), isTrue);
    expect(isNotificationsPath('/notifications/preferences'), isTrue);
    expect(isNotificationsPath('/messages'), isFalse);
    expect(isNotificationsPath('/proposals/notification-1'), isFalse);
  });
}
