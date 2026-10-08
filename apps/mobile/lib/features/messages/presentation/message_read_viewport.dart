import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/message_unread_controller.dart';

/// Only the rendered newest viewport may acknowledge its server snapshot.
/// Hidden branches, PopupRoutes (including sheets), older scroll and background
/// lifecycle states cannot consume a new boundary. Failure retains exact retry.
class MessageReadViewport extends ConsumerStatefulWidget {
  const MessageReadViewport({
    required this.profileId,
    required this.kind,
    required this.chatId,
    required this.boundary,
    required this.scrollController,
    required this.child,
    super.key,
  });
  final String? profileId;
  final String kind;
  final String? chatId;
  final String? boundary;
  final ScrollController scrollController;
  final Widget child;
  @override
  ConsumerState<MessageReadViewport> createState() =>
      _MessageReadViewportState();
}

class _MessageReadViewportState extends ConsumerState<MessageReadViewport>
    with WidgetsBindingObserver {
  Timer? _timer;
  String? _done;
  String? _failed;
  bool _busy = false;
  bool get _visible =>
      mounted &&
      widget.profileId != null &&
      widget.chatId != null &&
      widget.boundary != null &&
      ref.read(authSessionProvider).identity?.id == widget.profileId &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      TickerMode.valuesOf(context).enabled &&
      ModalRoute.of(context)?.isCurrent == true &&
      widget.scrollController.hasClients &&
      widget.scrollController.position.hasContentDimensions &&
      !widget.scrollController.position.isScrollingNotifier.value &&
      widget.scrollController.position.extentAfter <= 1;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.scrollController.addListener(_schedule);
  }

  @override
  void didUpdateWidget(MessageReadViewport old) {
    super.didUpdateWidget(old);
    if (old.profileId != widget.profileId || old.chatId != widget.chatId) {
      _done = null;
      _failed = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.scrollController.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
    } else {
      _timer?.cancel();
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 220), () => unawaited(_ack()));
  }

  Future<void> _ack({bool retry = false}) async {
    if (!_visible || _busy || (!retry && _failed != null)) return;
    final boundary = retry ? _failed : widget.boundary;
    if (boundary == null || boundary == _done) return;
    final profile = widget.profileId!;
    final chat = widget.chatId!;
    _busy = true;
    final succeeded = await ref
        .read(messageUnreadProvider.notifier)
        .acknowledge(profile, widget.kind, chat, boundary);
    _busy = false;
    if (!mounted ||
        widget.profileId != profile ||
        widget.chatId != chat ||
        ref.read(authSessionProvider).identity?.id != profile) {
      return;
    }
    setState(() {
      if (succeeded) {
        _done = boundary;
        _failed = null;
      } else {
        _failed = boundary;
      }
    });
    if (succeeded && widget.boundary != boundary) _schedule();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(messageUnreadProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _schedule();
    });
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_failed != null)
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: TextButton(
                  onPressed: () => _ack(retry: true),
                  child: Text(l10n.messageReadRetry),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
