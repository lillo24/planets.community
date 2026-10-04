import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/monitoring/invitation_telemetry_filter.dart';

void main() {
  final token = 'A' * 43;
  for (final path in ['/join/project/$token', '/invite/project/$token']) {
    test('drops direct and encoded capability destinations', () {
      expect(
        containsInvitationSecret({
          'data': {'to': path},
        }),
        isTrue,
      );
      expect(
        containsInvitationSecret('/auth?returnTo=${Uri.encodeComponent(path)}'),
        isTrue,
      );
      expect(
        containsInvitationSecret(
          Uri.encodeComponent(Uri.encodeComponent(path)),
        ),
        isTrue,
      );
    });
  }
  test(
    'drops RPC secrets and standalone tokens, preserves public telemetry',
    () {
      expect(containsInvitationSecret({'p_token': token}), isTrue);
      expect(
        containsInvitationSecret({
          'nested': [
            {'invite_token': token},
          ],
        }),
        isTrue,
      );
      expect(containsInvitationSecret('Failed with token $token.'), isTrue);
      expect(
        containsInvitationSecret({
          'to': '/proposals/123?intent=join',
          'status': 409,
        }),
        isFalse,
      );
      expect(containsInvitationSecret('Malformed % value'), isFalse);
    },
  );
}
