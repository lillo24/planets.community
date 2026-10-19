import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/discussion_hint_store.dart';

/// Permanent workspace entry plus a locally dismissed, account-scoped intro.
///
/// Dismissing this hint changes no backend consent or external permissions.
class DiscussionGeneralHint extends ConsumerStatefulWidget {
  const DiscussionGeneralHint({
    required this.actor,
    required this.onOpen,
    super.key,
  });
  final String actor;
  final VoidCallback? onOpen;
  @override
  ConsumerState<DiscussionGeneralHint> createState() =>
      _DiscussionGeneralHintState();
}

class _DiscussionGeneralHintState extends ConsumerState<DiscussionGeneralHint> {
  bool? dismissed;
  bool busy = true, writeRetry = false;
  Object? error;
  int epoch = 0;
  bool get current {
    final session = ref.read(authSessionProvider);
    return session.identity?.id == widget.actor &&
        session.phase == AuthSessionPhase.ready;
  }

  bool valid(int ticket, String actor) =>
      mounted && ticket == epoch && widget.actor == actor && current;

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void didUpdateWidget(DiscussionGeneralHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actor != widget.actor) reset();
  }

  void reset() {
    epoch++;
    dismissed = null;
    error = null;
    busy = true;
    writeRetry = false;
    if (current) Future.microtask(load);
  }

  Future<void> load() async {
    if (!mounted || !current) return;
    final actor = widget.actor, ticket = ++epoch;
    setState(() {
      busy = true;
      error = null;
      writeRetry = false;
    });
    try {
      final saved = await ref
          .read(discussionHintStoreProvider)
          .dismissed(actor);
      if (valid(ticket, actor)) setState(() => dismissed = saved);
    } catch (failure) {
      // This UI preference boundary keeps the useful introduction visible and
      // reports the failed restore explicitly; it never claims a saved value.
      if (valid(ticket, actor)) {
        setState(() {
          dismissed = false;
          error = failure;
        });
      }
    } finally {
      if (valid(ticket, actor)) setState(() => busy = false);
    }
  }

  Future<void> dismiss() async {
    if (busy || !current) return;
    final actor = widget.actor, ticket = ++epoch;
    setState(() {
      busy = true;
      error = null;
      writeRetry = true;
    });
    try {
      await ref.read(discussionHintStoreProvider).dismiss(actor);
      if (valid(ticket, actor)) setState(() => dismissed = true);
    } catch (failure) {
      if (valid(ticket, actor)) setState(() => error = failure);
    } finally {
      if (valid(ticket, actor)) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider.select((s) => (s.identity?.id, s.phase)), (
      _,
      _,
    ) {
      setState(reset);
    });
    ref.watch(authSessionProvider);
    if (!current) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const Key('discussion-general-workspace'),
          leading: const Icon(Icons.folder_shared_outlined),
          title: Text(l.discussionGroupWorkspace),
          onTap: widget.onOpen,
        ),
        if (busy) const LinearProgressIndicator(),
        if (dismissed == false)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.discussionExternalHint),
                TextButton(
                  key: const Key('discussion-general-hint-dismiss'),
                  onPressed: busy ? null : dismiss,
                  child: Text(l.discussionGeneralHintDismiss),
                ),
              ],
            ),
          ),
        if (error != null) ...[
          Text(
            writeRetry
                ? l.discussionGeneralHintSaveFailed
                : l.discussionGeneralHintLoadFailed,
          ),
          TextButton(
            onPressed: busy
                ? null
                : writeRetry
                ? dismiss
                : load,
            child: Text(l.discussionRetry),
          ),
        ],
      ],
    );
  }
}
