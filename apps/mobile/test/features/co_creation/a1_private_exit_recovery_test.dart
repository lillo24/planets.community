import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/co_creation/application/people_signals.dart';
import 'package:planets_mobile/features/co_creation/data/people_posts_gateway.dart';
import 'package:planets_mobile/features/co_creation/data/people_private_gateway.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_message_items.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_policy.dart';

const _actor = 'a1010000-0000-4000-8000-000000000001';

class _Session extends AuthSessionController {
  @override
  AuthSessionState build() =>
      const AuthSessionState.ready(AuthIdentity(id: _actor));
}

void main() {
  testWidgets(
    'disabled experiment retains metadata-only contact close in Requests',
    (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(_Session.new),
            preacceptedPolicyFixture,
            peopleSignalsProvider.overrideWith((ref) => const Stream.empty()),
            peoplePostsGatewayProvider.overrideWithValue(
              PeoplePostsGateway((name, args) async {
                if (name == 'get_cocreate_availability')
                  return {'enabled': false};
                throw StateError('Disabled domain must not expose $name');
              }),
            ),
            peoplePrivateGatewayProvider.overrideWithValue(
              PeoplePrivateGateway((name, args) async {
                calls.add(name);
                if (name == 'list_own_cocreate_interest_exits') return [];
                if (name == 'list_own_cocreate_contact_exits')
                  return [
                    {
                      'contact_id': 'a1080000-0000-4000-8000-000000000001',
                      'created_at': '2026-10-24T10:00:00Z',
                    },
                  ];
                throw StateError('Recovery must not read transcripts: $name');
              }),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: PeopleRequestItems()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Accepted contact'), findsOneWidget);
      expect(calls.toSet(), {
        'list_own_cocreate_interest_exits',
        'list_own_cocreate_contact_exits',
      });
      expect(tester.takeException(), isNull);
    },
  );
}
