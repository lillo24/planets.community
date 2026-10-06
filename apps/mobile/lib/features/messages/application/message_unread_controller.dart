import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/message_unread_gateway.dart';
import '../domain/message_unread_models.dart';
import 'message_chats_refresh.dart';

class MessageUnreadState {
  const MessageUnreadState({
    this.profileId,
    this.summary,
    this.failed = false,
    this.disconnected = false,
    this.stale = false,
  });
  final String? profileId;
  final MessageUnreadSummary? summary;
  final bool failed;
  final bool disconnected;
  final bool stale;
}

class MessageUnreadController extends Notifier<MessageUnreadState>
    with WidgetsBindingObserver {
  MessageUnreadSubscription? _subscription;
  Timer? _timer;
  int _revision = 0;
  int _request = 0;
  @override
  MessageUnreadState build() {
    final session = ref.watch(authSessionProvider);
    final id = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    final revision = ++_revision;
    _request++;
    _timer?.cancel();
    final previous = _subscription;
    _subscription = null;
    if (previous != null) unawaited(previous.close());
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _revision++;
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
      final subscription = _subscription;
      _subscription = null;
      if (subscription != null) unawaited(subscription.close());
    });
    if (id != null) {
      Future<void>.microtask(() {
        if (!_current(revision, id)) return;
        try {
          _subscription = ref
              .read(messageUnreadGatewayProvider)
              .subscribe(
                id,
                () {
                  if (!_current(revision, id)) return;
                  _schedule(id);
                },
                (connected) {
                  if (!_current(revision, id)) return;
                  state = MessageUnreadState(
                    profileId: id,
                    summary: state.summary,
                    failed: state.failed,
                    disconnected: !connected,
                    stale: state.stale,
                  );
                  if (connected) _schedule(id);
                },
              );
          unawaited(refresh(id));
        } catch (_) {
          if (_current(revision, id)) {
            state = MessageUnreadState(profileId: id, failed: true);
          }
        }
      });
    }
    return MessageUnreadState(profileId: id);
  }

  bool _current(int revision, String id) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == id;
  void _schedule(String id) {
    _request++; // Invalidate a response from before this hint immediately.
    state = MessageUnreadState(
      profileId: id,
      summary: state.summary,
      failed: state.failed,
      disconnected: state.disconnected,
      stale: true,
    );
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 180), () {
      ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
      unawaited(refresh(id));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final id = this.state.profileId;
    if (state == AppLifecycleState.resumed && id != null) _schedule(id);
  }

  Future<bool> refresh(String id) async {
    final revision = _revision;
    final request = ++_request;
    if (!_current(revision, id)) return false;
    try {
      final summary = await ref.read(messageUnreadGatewayProvider).summary(id);
      if (!_current(revision, id) || request != _request) return false;
      state = MessageUnreadState(
        profileId: id,
        summary: summary,
        disconnected: state.disconnected,
      );
      return true;
    } catch (_) {
      if (_current(revision, id) && request == _request) {
        state = MessageUnreadState(
          profileId: id,
          summary: state.summary,
          failed: true,
          disconnected: state.disconnected,
          stale: true,
        );
      }
      return false;
    }
  }

  Future<bool> acknowledge(
    String id,
    String kind,
    String chat,
    String boundary,
  ) async {
    final revision = _revision;
    if (!_current(revision, id)) return false;
    try {
      await ref
          .read(messageUnreadGatewayProvider)
          .acknowledge(id, kind, chat, boundary);
      if (!_current(revision, id)) return false;
      ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
      // Do not decrement locally or install a racing acknowledgement response.
      await refresh(id);
      return _current(revision, id);
    } catch (_) {
      if (_current(revision, id)) {
        // A revoked/expired boundary can race canonical access or another
        // device. Refresh own state while preserving the viewport's failed
        // token; neither a network failure nor a conflict clears it locally.
        ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
        await refresh(id);
      }
      return false;
    }
  }
}

final messageUnreadProvider =
    NotifierProvider<MessageUnreadController, MessageUnreadState>(
      MessageUnreadController.new,
    );
