import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/discussion_gateway.dart';
import '../data/discussion_projects_gateway.dart';
import '../domain/discussion_models.dart';

/// One account subscription, shared by mounted C destinations. Each consumer
/// rereads its loaded window; no body, room identifier or read ACK is a hint.
final discussionSignalsProvider =
    StreamProvider.autoDispose<({bool connected, int event})>((ref) {
      final session = ref.watch(authSessionProvider);
      if (session.phase != AuthSessionPhase.ready || session.identity == null) {
        return const Stream.empty();
      }
      var event = 0;
      // Riverpod compares emitted values. Equal consecutive bool hints must still
      // invalidate every loaded window, including a later entitlement revocation.
      return ref
          .watch(discussionGatewayProvider)
          .signals(session.identity!.id)
          .map((connected) => (connected: connected, event: ++event));
    });

final discussionGroupSignalsProvider = StreamProvider.autoDispose
    .family<({bool connected, int event}), String>((ref, group) {
      final actor = discussionActor(ref);
      if (actor == null) return const Stream.empty();
      var event = 0;
      return ref
          .watch(discussionGatewayProvider)
          .groupSignals(actor, group)
          .map((connected) => (connected: connected, event: ++event));
    });

class DiscussionPager<T extends DiscussionPageRow> extends ChangeNotifier {
  DiscussionPager(this.fetch, this.authorized);
  final Future<List<T>> Function(Map<String, dynamic>?) fetch;
  final bool Function() authorized;
  List<T> rows = [];
  Map<String, dynamic>? cursor;
  Object? error;
  bool busy = false,
      more = true,
      disposed = false,
      invalidated = false,
      loaded = false;
  int revision = 0;
  Future<void> load() => _read(false);
  Future<void> refresh() => _read(true);
  void invalidate() {
    if (disposed) return;
    revision++;
    invalidated = true;
    if (!busy) unawaited(refresh());
  }

  Future<void> _read(bool replacing) async {
    if (disposed || busy || !authorized() || (!replacing && !more)) return;
    final epoch = ++revision;
    invalidated = false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      var next = replacing ? null : cursor;
      final window = <T>[];
      var hasMore = true;
      final pages = replacing ? (rows.length / 25).ceil().clamp(1, 1000000) : 1;
      for (var i = 0; i < pages && hasMore; i++) {
        final data = await fetch(next);
        if (disposed || epoch != revision || !authorized()) return;
        window.addAll(data);
        hasMore = data.length == 25;
        if (data.isNotEmpty) next = data.last.cursor;
      }
      final ids = <String>{};
      rows = [
        if (!replacing) ...rows,
        ...window,
      ].where((r) => ids.add(r.id)).toList(growable: false);
      cursor = next;
      more = hasMore;
      loaded = true;
    } catch (failure) {
      if (disposed || epoch != revision || !authorized()) return;
      error = failure;
      if (discussionFailure(failure) == DiscussionFailure.denied) {
        rows = [];
        cursor = null;
        more = false;
      }
    } finally {
      if (!disposed) {
        busy = false;
        notifyListeners();
        if (invalidated && authorized()) unawaited(refresh());
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    revision++;
    rows = [];
    cursor = null;
    super.dispose();
  }
}

/// The operation/actor/key/body are frozen until a reply resolves uncertainty.
/// Read refreshes cannot replace a pending command or adopt another intent.
class DiscussionAttempt {
  DiscussionAttempt(
    this.actor,
    this.action,
    Map<String, dynamic> intent, {
    String? key,
  }) : intent = Map.unmodifiable(intent),
       key = key ?? const Uuid().v4();
  final String actor, key;
  final DiscussionAction action;
  final Map<String, dynamic> intent;
  bool busy = false, cancelled = false;
  bool get ownExit =>
      action == DiscussionAction.leave ||
      action == DiscussionAction.respond && intent['p_response'] == 'declined';
  Object? error;
  DiscussionReceipt? receipt;
  bool get uncertain =>
      receipt == null &&
      error != null &&
      (error is FormatException ||
          error is TypeError ||
          discussionFailure(error!) == DiscussionFailure.unavailable);
}

class DiscussionCommands extends ChangeNotifier {
  DiscussionCommands(this.gateway, this.authorized);
  final DiscussionGateway gateway;
  final bool Function(String actor) authorized;
  final Map<String, DiscussionAttempt> attempts = {};
  bool disposed = false;
  int epoch = 0;
  Future<DiscussionReceipt?> run(
    String slot,
    String actor,
    DiscussionAction action,
    Map<String, dynamic> intent,
  ) async {
    if (disposed || !authorized(actor)) return null;
    final prior = attempts[slot];
    if (prior != null &&
        (prior.actor != actor ||
            prior.action != action ||
            !mapEquals(prior.intent, intent))) {
      throw StateError('An unresolved discussion action cannot change intent.');
    }
    final attempt = prior ?? DiscussionAttempt(actor, action, intent);
    attempts[slot] = attempt;
    if (attempt.busy) return null;
    final captured = epoch;
    attempt.busy = true;
    attempt.error = null;
    notifyListeners();
    try {
      final result =
          attempt.receipt ??
          await gateway.command(actor, attempt.key, action, attempt.intent);
      if (disposed ||
          attempt.cancelled ||
          captured != epoch ||
          !authorized(actor)) {
        return null;
      }
      attempt.receipt = result;
      return result;
    } catch (error) {
      if (!disposed &&
          !attempt.cancelled &&
          captured == epoch &&
          authorized(actor)) {
        attempt.error = error;
      }
      return null;
    } finally {
      if (!disposed && !attempt.cancelled && captured == epoch) {
        attempt.busy = false;
        notifyListeners();
      }
    }
  }

  void forget(String slot) {
    if (attempts[slot]?.busy == true || attempts[slot]?.uncertain == true) {
      return;
    }
    attempts.remove(slot);
    notifyListeners();
  }

  void clear() {
    epoch++;
    attempts.clear();
    if (!disposed) notifyListeners();
  }

  void clearRoom(String room) {
    final slots = attempts.entries
        .where(
          (entry) =>
              entry.value.intent['p_room_id'] == room && !entry.value.ownExit,
        )
        .map((entry) => entry.key)
        .toList();
    for (final slot in slots) {
      attempts[slot]!.cancelled = true;
      attempts.remove(slot);
    }
    if (!disposed) notifyListeners();
  }

  void clearProtected() {
    final slots = attempts.entries
        .where((entry) => !entry.value.ownExit)
        .map((entry) => entry.key)
        .toList();
    for (final slot in slots) {
      attempts[slot]!.cancelled = true;
      attempts.remove(slot);
    }
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    epoch++;
    attempts.clear();
    super.dispose();
  }
}

final discussionCommandsProvider = Provider<DiscussionCommands>((ref) {
  final commands = DiscussionCommands(
    ref.watch(discussionGatewayProvider),
    (actor) => ref.read(authSessionProvider).identity?.id == actor,
  );
  ref.listen(authSessionProvider.select((s) => (s.identity?.id, s.phase)), (
    previous,
    next,
  ) {
    if (previous?.$1 != next.$1) {
      commands.clear();
    } else {
      commands.clearProtected();
    }
  });
  ref.onDispose(commands.dispose);
  return commands;
});

class DiscussionChatController extends ChangeNotifier {
  DiscussionChatController(
    this.gateway,
    this.actor,
    this.roomId,
    this.authorized,
  );
  final DiscussionGateway gateway;
  final String actor, roomId;
  final bool Function() authorized;
  DiscussionRoom? room;
  StreamSubscription<bool>? groupSubscription;
  String? observedGroup;
  List<DiscussionMessage> messages = [];
  Object? error;
  String? token;
  bool busy = false,
      more = true,
      disposed = false,
      invalidated = false,
      latestAvailable = false;
  int revision = 0;
  void invalidate() {
    if (disposed) return;
    revision++;
    invalidated = true;
    if (!busy) unawaited(refresh());
  }

  Future<void> refresh({bool latest = false}) async {
    if (disposed || busy || !authorized()) return;
    final epoch = ++revision;
    invalidated = false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final context = await gateway.room(actor, roomId);
      if (disposed || epoch != revision || !authorized()) return;
      if (observedGroup != context.groupId && !context.isFormer) {
        unawaited(groupSubscription?.cancel());
        observedGroup = context.groupId;
        groupSubscription = gateway.groupSignals(actor, context.groupId).listen(
          (connected) {
            if (connected) invalidate();
          },
        );
      }
      if (context.isFormer) {
        unawaited(groupSubscription?.cancel());
        groupSubscription = null;
        observedGroup = null;
      }
      if (!context.canReadHistory) {
        if (disposed || epoch != revision || !authorized()) return;
        room = context;
        messages = [];
        token = null;
        more = false;
        latestAvailable = false;
        return;
      }
      final page = await gateway.history(actor, roomId);
      if (page.admissionId != context.admissionId) {
        throw const FormatException(
          'The discussion admission changed during refresh.',
        );
      }
      if (disposed || epoch != revision || !authorized()) return;
      final sameEpisode = room?.admissionId == context.admissionId && room?.access == context.access && !context.isFormer;
      final overlap =
          messages.isEmpty ||
          page.messages.any((m) => messages.any((old) => old.id == m.id));
      room = context;
      if (latest || !sameEpisode || messages.isEmpty) {
        messages = page.messages.reversed.toList();
        more = page.messages.length == 30;
        latestAvailable = false;
        token = page.token;
      } else if (!overlap && page.messages.length == 30) {
        latestAvailable = true;
        token = null;
      } else {
        final byId = {
          for (final m in messages) m.id: m,
          for (final m in page.messages) m.id: m,
        };
        messages = byId.values.toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
        latestAvailable = false;
        token = page.token;
      }
    } catch (failure) {
      if (disposed || epoch != revision || !authorized()) return;
      error = failure;
      token = null;
      if (discussionFailure(failure) == DiscussionFailure.denied) {
        room = null;
        messages = [];
        more = false;
      }
    } finally {
      if (!disposed) {
        busy = false;
        notifyListeners();
        if (invalidated && authorized()) unawaited(refresh());
      }
    }
  }

  Future<void> older() async {
    if (disposed || busy || !more || messages.isEmpty || !authorized()) return;
    final epoch = ++revision;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final page = await gateway.history(
        actor,
        roomId,
        before: messages.first.sequence,
      );
      if (disposed || epoch != revision || !authorized()) return;
      final ids = {for (final m in messages) m.id};
      if (page.admissionId != room?.admissionId) {
        room = null;
        messages = [];
        token = null;
        more = false;
        throw const FormatException(
          'The discussion admission changed during paging.',
        );
      }
      if (page.messages.any((m) => m.sequence >= messages.first.sequence)) {
        throw const FormatException('The older page crossed its frontier.');
      }
      messages = [
        ...page.messages.reversed.where((m) => ids.add(m.id)),
        ...messages,
      ];
      more = page.messages.length == 30;
    } catch (failure) {
      if (!disposed && epoch == revision && authorized()) {
        error = failure;
        if (discussionFailure(failure) == DiscussionFailure.denied) {
          room = null;
          messages = [];
          token = null;
          more = false;
        }
      }
    } finally {
      if (!disposed) {
        busy = false;
        notifyListeners();
        if (invalidated && authorized()) unawaited(refresh());
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    revision++;
    room = null;
    messages = [];
    token = null;
    unawaited(groupSubscription?.cancel());
    super.dispose();
  }
}

String? discussionActor(Ref ref) {
  final s = ref.read(authSessionProvider);
  return s.phase == AuthSessionPhase.ready ? s.identity?.id : null;
}

final discussionGroupsProvider =
    Provider.autoDispose<DiscussionPager<DiscussionGroup>?>((ref) {
      final s = ref.watch(authSessionProvider);
      final actor = s.phase == AuthSessionPhase.ready ? s.identity?.id : null;
      if (actor == null) return null;
      final p = DiscussionPager<DiscussionGroup>(
        (cursor) => ref.read(discussionGatewayProvider).groups(actor, cursor),
        () => discussionActor(ref) == actor,
      );
      ref.listen(discussionSignalsProvider, (_, next) {
        if (next.asData?.value.connected == true) p.invalidate();
      });
      ref.onDispose(p.dispose);
      return p;
    });
final discussionInvitationsProvider =
    Provider.autoDispose<DiscussionPager<DiscussionInvitation>?>((ref) {
      final s = ref.watch(authSessionProvider);
      final actor = s.phase == AuthSessionPhase.ready ? s.identity?.id : null;
      if (actor == null) return null;
      final p = DiscussionPager<DiscussionInvitation>(
        (cursor) =>
            ref.read(discussionGatewayProvider).invitations(actor, cursor),
        () => discussionActor(ref) == actor,
      );
      ref.listen(discussionSignalsProvider, (_, next) {
        if (next.asData?.value.connected == true) p.invalidate();
      });
      ref.onDispose(p.dispose);
      return p;
    });
final discussionRoomsProvider = Provider.autoDispose
    .family<DiscussionPager<DiscussionRoom>?, String>((ref, group) {
      final s = ref.watch(authSessionProvider);
      final actor = s.phase == AuthSessionPhase.ready ? s.identity?.id : null;
      if (actor == null) return null;
      final p = DiscussionPager<DiscussionRoom>(
        (cursor) =>
            ref.read(discussionGatewayProvider).rooms(actor, group, cursor),
        () => discussionActor(ref) == actor,
      );
      ref.listen(discussionSignalsProvider, (_, next) {
        if (next.asData?.value.connected == true) p.invalidate();
      });
      ref.listen(discussionGroupSignalsProvider(group), (_, next) {
        if (next.asData?.value.connected == true) p.invalidate();
      });
      ref.onDispose(p.dispose);
      return p;
    });
final discussionChatProvider = Provider.autoDispose
    .family<DiscussionChatController?, String>((ref, room) {
      final s = ref.watch(authSessionProvider);
      final actor = s.phase == AuthSessionPhase.ready ? s.identity?.id : null;
      if (actor == null) return null;
      final c = DiscussionChatController(
        ref.read(discussionGatewayProvider),
        actor,
        room,
        () => discussionActor(ref) == actor,
      );
      ref.listen(discussionSignalsProvider, (_, next) {
        if (next.asData?.value.connected == true) c.invalidate();
      });
      ref.onDispose(c.dispose);
      return c;
    });

final discussionHiddenRoomsProvider = Provider.autoDispose
    .family<DiscussionPager<DiscussionRoom>?, String>((ref, group) {
      final session = ref.watch(authSessionProvider);
      final actor = session.phase == AuthSessionPhase.ready
          ? session.identity?.id
          : null;
      if (actor == null) return null;
      final p = DiscussionPager<DiscussionRoom>(
        (cursor) => ref
            .read(discussionGatewayProvider)
            .rooms(actor, group, cursor, hidden: true),
        () => discussionActor(ref) == actor,
      );
      ref.listen(discussionSignalsProvider, (_, next) {
        if (next.asData?.value.connected == true) p.invalidate();
      });
      ref.listen(discussionGroupSignalsProvider(group), (_, next) {
        if (next.asData?.value.connected == true) p.invalidate();
      });
      ref.onDispose(p.dispose);
      return p;
    });
final discussionProjectsProvider = Provider.autoDispose
    .family<DiscussionPager<DiscussionProjectRow>?, String>((ref, group) {
      final session = ref.watch(authSessionProvider);
      final actor = session.phase == AuthSessionPhase.ready
          ? session.identity?.id
          : null;
      if (actor == null) return null;
      final p = DiscussionPager<DiscussionProjectRow>(
        (cursor) => ref
            .read(discussionProjectsGatewayProvider)
            .projects(actor, group, cursor),
        () => discussionActor(ref) == actor,
      );
      ref.listen(discussionSignalsProvider, (_, next) {
        if (next.asData?.value.connected == true) p.invalidate();
      });
      ref.onDispose(p.dispose);
      return p;
    });
