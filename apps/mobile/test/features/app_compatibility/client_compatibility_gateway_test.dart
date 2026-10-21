import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planets_mobile/features/app_compatibility/data/client_compatibility_gateway.dart';
import 'package:planets_mobile/features/app_compatibility/domain/client_compatibility.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late PlatformClientCompatibilityGateway gateway;
  const channel = MethodChannel('de.ffuf.in_app_update/methods');
  setUp(() {
    client = SupabaseClient(
      'https://example.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/functions/v1/client-compatibility');
        expect(
          request.body,
          '{"platform":"android","application_id":"community.planets.app"}',
        );
        return http.Response(
          '{"schema_version":1,"platform":"android","application_id":"community.planets.app","minimum_version":"1.0.0","minimum_build":"11","update_url":"https://play.google.com/store/apps/details?id=community.planets.app"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    gateway = PlatformClientCompatibilityGateway(client);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await client.dispose();
  });
  test(
    'reads installed native metadata and the exact public policy endpoint',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'PLANETS',
        packageName: 'community.planets.app',
        version: '1.0.0',
        buildNumber: '10',
        buildSignature: '',
      );
      final installed = await gateway.installedClient(ClientPlatform.android);
      expect((await gateway.policy(installed)).supports(installed), isFalse);
    },
  );
  for (final inProgress in [false, true]) {
    test(
      'native Immediate Update delegates UI and supports resumed=$inProgress',
      () async {
        final calls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call.method);
              if (call.method == 'checkForUpdate') {
                return {
                  'updateAvailability': inProgress ? 3 : 2,
                  'immediateAllowed': !inProgress,
                  'flexibleAllowed': false,
                  'availableVersionCode': 11,
                  'installStatus': inProgress ? 2 : 0,
                  'packageName': 'community.planets.app',
                  'clientVersionStalenessDays': 0,
                  'updatePriority': 0,
                };
              }
              if (call.method == 'performImmediateUpdate') {
                throw PlatformException(code: 'USER_DENIED_UPDATE');
              }
              fail('Unexpected native update method ${call.method}');
            });
        expect(
          await gateway.immediateAndroidUpdate(),
          ImmediateUpdateOutcome.cancelled,
        );
        expect(calls, ['checkForUpdate', 'performImmediateUpdate']);
      },
    );
  }
  test(
    'unavailable Play update never starts a substitute custom flow',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'checkForUpdate');
            return {
              'updateAvailability': 1,
              'immediateAllowed': false,
              'flexibleAllowed': false,
              'availableVersionCode': 10,
              'installStatus': 0,
              'packageName': 'community.planets.app',
              'clientVersionStalenessDays': null,
              'updatePriority': 0,
            };
          });
      expect(
        await gateway.immediateAndroidUpdate(),
        ImmediateUpdateOutcome.unavailable,
      );
    },
  );
}
