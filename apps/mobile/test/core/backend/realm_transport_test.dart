import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planets_mobile/core/backend/realm_transport.dart';
import 'package:planets_mobile/core/backend/secure_session_storage.dart';

void main() {
  test(
    'normal product traffic is fenced; only its own Auth maintenance survives',
    () async {
      final seen = <String>[];
      final transport = RealmTransport(
        origin: Uri.parse('http://127.0.0.1:55321'),
        inner: MockClient((r) async {
          seen.add('${r.method} ${r.url.path}');
          return http.Response('{}', 200);
        }),
      )..productBlocked = true;
      for (final path in [
        '/rest/v1/profiles',
        '/storage/v1/object/private/avatar',
        '/functions/v1/map-preview',
        '/auth/v1/otp',
      ]) {
        await expectLater(
          transport.get(Uri.parse('http://127.0.0.1:55321$path')),
          throwsA(isA<http.ClientException>()),
        );
      }
      await transport.get(Uri.parse('http://127.0.0.1:55321/auth/v1/user'));
      await transport.post(
        Uri.parse(
          'http://127.0.0.1:55321/auth/v1/token?grant_type=refresh_token',
        ),
      );
      await expectLater(
        transport.get(Uri.parse('http://127.0.0.1:56321/auth/v1/user')),
        throwsA(isA<http.ClientException>()),
      );
      expect(seen, hasLength(2));
      transport.close();
    },
  );
  test(
    'mock transport rejects provider/OTP/password/email/MFA mutations',
    () async {
      final transport = RealmTransport(
        origin: Uri.parse('http://127.0.0.1:56321'),
        mock: true,
        inner: MockClient((r) async => http.Response('{}', 200)),
      );
      for (final path in [
        '/auth/v1/otp',
        '/auth/v1/authorize',
        '/auth/v1/user',
        '/auth/v1/factors',
        '/auth/v1/token?grant_type=password',
      ]) {
        await expectLater(
          transport.post(Uri.parse('http://127.0.0.1:56321$path')),
          throwsA(isA<http.ClientException>()),
        );
      }
      await transport.get(Uri.parse('http://127.0.0.1:56321/rest/v1/profiles'));
      transport.close();
    },
  );
  test('in-flight mutations remain bound to old transport and unknown outcomes are retained', () async {
    final gate = Completer<http.Response>();
    final transport = RealmTransport(
      origin: Uri.parse('http://127.0.0.1:55321'),
      inner: MockClient((r) => gate.future),
    );
    final send = transport.post(
      Uri.parse(
        'http://127.0.0.1:55321/rest/v1/rpc/send_message?secret=never-retain',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    transport.productBlocked = true;
    var drained = false;
    final drain = transport.whenDrained.then((_) => drained = true);
    expect(drained, isFalse);
    gate.complete(http.Response('{}', 503));
    await send;
    await drain;
    expect(transport.uncertainOperations, {'send_message'});
    transport.close();
  });
  test('confidential namespaces separate equal UUIDs and ports without token values', () {
    final a = Uri.parse('http://127.0.0.1:55321'),
        b = Uri.parse('http://127.0.0.1:56321');
    expect(normalSessionKey(a), isNot(normalSessionKey(b)));
    expect(normalSessionKey(a), isNot(mockSessionKey(a, 'same', 'request')));
    expect(
      mockSessionKey(b, 'rootA', 'request'),
      isNot(mockSessionKey(b, 'rootB', 'request')),
    );
  });
  test('cancelled public map reads drain without inventing uncertain product edits', () async {
    for (final endpoint in ['map-provider', 'other-product-function']) {
      final transport = RealmTransport(
        origin: Uri.parse('http://127.0.0.1:55321'),
        inner: MockClient((_) async => throw http.ClientException('cancelled')),
      );
      addTearDown(transport.close);
      await expectLater(
        transport.post(
          Uri.parse('http://127.0.0.1:55321/functions/v1/$endpoint'),
        ),
        throwsA(isA<http.ClientException>()),
      );
      await transport.whenDrained;
      expect(
        transport.uncertainOperations,
        endpoint == 'map-provider' ? isEmpty : {'/functions/v1'},
      );
      transport.productBlocked = true;
      await expectLater(
        transport.post(
          Uri.parse('http://127.0.0.1:55321/functions/v1/$endpoint'),
        ),
        throwsA(isA<http.ClientException>()),
      );
    }
  });
}
