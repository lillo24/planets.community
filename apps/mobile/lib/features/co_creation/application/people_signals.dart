import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/private_broadcast_payload.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/people_private_gateway.dart';
import '../domain/people_private.dart';

/// A single actor-only metadata subscription shared by Messages and rooms.
/// Hints grant no history and carry no room IDs or message bodies.
final peopleSignalsProvider =
    StreamProvider.autoDispose<({bool connected, int event})>((ref) {
      final session = ref.watch(authSessionProvider);
      if (session.phase != AuthSessionPhase.ready || session.identity == null) {
        return const Stream.empty();
      }
      final client = ref.watch(peoplePrivateGatewayProvider).signalClient;
      if (client == null) return const Stream.empty();
      final actor = session.identity!.id;
      final stream = StreamController<({bool connected, int event})>();
      var event = 0;
      void add(bool connected) {
        if (!stream.isClosed) {
          stream.add((connected: connected, event: ++event));
        }
      }

      final channel = client.channel(
        'cocreate:profile:$actor',
        opts: const RealtimeChannelConfig(private: true),
      );
      channel
          .onBroadcast(
            event: 'cocreate.changed',
            callback: (value) {
              try {
                final payload = privateBroadcastPayload(
                  value,
                  'cocreate.changed',
                  const {'profile_id'},
                );
                if (peopleUuid(payload['profile_id']) != actor) {
                  throw const FormatException('Mismatched co-creation signal.');
                }
                add(true);
              } on FormatException {
                add(false);
              } on TypeError {
                add(false);
              }
            },
          )
          .subscribe(
            (status, _) => add(status == RealtimeSubscribeStatus.subscribed),
          );
      ref.onDispose(() {
        unawaited(client.removeChannel(channel));
        unawaited(stream.close());
      });
      return stream.stream;
    });
