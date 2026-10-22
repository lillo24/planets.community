import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../../policies/application/policy_documents.dart';
import '../application/people_attempt.dart';
import '../application/people_signals.dart';
import '../data/people_posts_gateway.dart';
import '../data/people_private_gateway.dart';
import '../data/co_creation_commands.dart';

final coCreationInboxAvailabilityProvider = FutureProvider.autoDispose<bool>((
  ref,
) {
  ref.watch(authSessionProvider.select((s) => (s.identity?.id, s.phase)));
  ref.listen(peopleSignalsProvider, (_, _) => ref.invalidateSelf());
  return ref.watch(peoplePostsGatewayProvider).available();
});

/// Native inboxes do not show admission/policy controls for a disabled domain.
/// Own-exit projections remain separate and never need this availability grant.
class CoCreationInboxGate extends ConsumerWidget {
  const CoCreationInboxGate({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ref
        .watch(coCreationInboxAvailabilityProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          data: (enabled) => enabled ? child : const SizedBox.shrink(),
          error: (_, _) => Row(
            children: [
              Expanded(child: Text(l.coPeopleContacts)),
              IconButton(
                tooltip: l.coPeopleError,
                onPressed: () =>
                    ref.invalidate(coCreationInboxAvailabilityProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        );
  }
}

class PeoplePage extends StatelessWidget {
  const PeoplePage({
    required this.title,
    required this.child,
    this.actions,
    super.key,
  });
  final String title;
  final List<Widget>? actions;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: pageAppBar(context, title: Text(title), actions: actions),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: child,
        ),
      ),
    ),
  );
}

class PeopleAccess extends ConsumerWidget {
  const PeopleAccess({
    required this.child,
    this.requirePolicy = true,
    super.key,
  });
  final Widget child;
  final bool requirePolicy;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(authSessionProvider), l = AppLocalizations.of(context);
    if (requirePolicy
        ? s.phase != AuthSessionPhase.ready
        : !s.isAuthenticated || s.identity == null) {
      return TextButton(
        onPressed: () => context.push(
          Uri(
            path: s.identity == null ? '/auth' : '/profile/edit',
            queryParameters: {
              'returnTo': GoRouterState.of(context).uri.toString(),
            },
          ).toString(),
        ),
        child: Text(l.coPeopleLogin),
      );
    }
    final policy = ref.watch(policyAcceptanceProvider);
    if (requirePolicy &&
        !policy.allows(s.identity?.id, ref.watch(policyVersionProvider))) {
      return TextButton(
        onPressed: () => context.push(
          policyAcceptanceDestination(GoRouterState.of(context).uri.toString()),
        ),
        child: Text(l.coPeoplePolicy),
      );
    }
    return KeyedSubtree(key: ValueKey(s.identity!.id), child: child);
  }
}

/// Bounded pages own no disk cache. Identity, policy and lifecycle invalidation
/// discard private bodies before a fresh canonical read. Pagination is explicit.
class PeopleList<T> extends ConsumerStatefulWidget {
  const PeopleList({
    required this.load,
    required this.row,
    this.private = true,
    this.header = const SizedBox.shrink(),
    this.emptyVisible = true,
    this.availabilityRequired = true,
    super.key,
  });
  final Future<List<T>> Function(WidgetRef, String?, T?) load;
  final Widget Function(BuildContext, T, Future<void> Function()) row;
  final bool private, emptyVisible;
  final bool availabilityRequired;
  final Widget header;
  @override
  ConsumerState<PeopleList<T>> createState() => _PeopleListState<T>();
}

class _PeopleListState<T> extends ConsumerState<PeopleList<T>>
    with WidgetsBindingObserver {
  List<T> items = [];
  Object? error;
  bool busy = true, more = false, available = false;
  int revision = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(refresh);
    timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted &&
          TickerMode.valuesOf(context).enabled &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
        refresh();
      }
    });
  }

  @override
  void dispose() {
    revision++;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      refresh();
    } else {
      revision++;
      if (mounted && widget.private) setState(() => items = []);
    }
  }

  Future<void> refresh() => load(false);
  Future<void> load(bool append) async {
    final generation = ++revision;
    final actor = ref.read(authSessionProvider).identity?.id;
    setState(() {
      busy = true;
      error = null;
      if (!append) items = [];
    });
    try {
      final enabled =
          !widget.availabilityRequired ||
          await ref.read(peoplePostsGatewayProvider).available();
      if (!mounted || generation != revision) return;
      if (!enabled) {
        setState(() {
          available = false;
          busy = false;
          items = [];
        });
        return;
      }
      final result = await widget.load(
        ref,
        actor,
        append && items.isNotEmpty ? items.last : null,
      );
      if (!mounted ||
          generation != revision ||
          ref.read(authSessionProvider).identity?.id != actor) {
        return;
      }
      setState(() {
        available = true;
        items = [if (append) ...items, ...result];
        more = result.length == 25;
        busy = false;
      });
    } catch (e) {
      if (mounted && generation == revision) {
        setState(() {
          error = e;
          busy = false;
          if (widget.private) items = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.private) {
      ref.listen(peopleSignalsProvider, (_, next) {
        revision++;
        items = [];
        tokenRefresh(next.asData?.value.connected == true);
      });
    }
    ref.listen(authSessionProvider.select((s) => (s.identity?.id, s.phase)), (
      _,
      _,
    ) {
      revision++;
      items = [];
      Future<void>.microtask(refresh);
    });
    if (widget.private) {
      ref.listen(policyAcceptanceProvider, (_, _) {
        revision++;
        items = [];
        Future<void>.microtask(refresh);
      });
    }
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.header,
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(l.coPeopleError),
        if (!busy && error == null && !available && widget.emptyVisible)
          Text(l.coPeopleBackendOff),
        if (!busy &&
            error == null &&
            available &&
            items.isEmpty &&
            widget.emptyVisible)
          Text(l.coPeopleEmpty),
        for (final item in items) widget.row(context, item, refresh),
        if (error != null)
          TextButton(onPressed: refresh, child: Text(l.coPeopleRetry)),
        if (more)
          TextButton(
            onPressed: busy ? null : () => load(true),
            child: Text(l.coPeopleMore),
          ),
        if (widget.emptyVisible && error == null)
          TextButton(
            onPressed: busy ? null : refresh,
            child: Text(l.coPeopleRefresh),
          ),
      ],
    );
  }

  void tokenRefresh(bool connected) {
    if (mounted) {
      setState(() {
        busy = connected;
        if (!connected) error = StateError('Co-creation connection lost.');
      });
    }
    if (connected) Future<void>.microtask(refresh);
  }
}

/// UI-level command boundary. A missing/malformed response freezes the intent.
class PeopleCommand extends ConsumerStatefulWidget {
  const PeopleCommand({
    required this.slot,
    required this.rpc,
    required this.intent,
    required this.label,
    required this.onSuccess,
    this.gateway,
    super.key,
  });
  final String slot, rpc, label;
  final Map<String, dynamic> intent;
  final Future<void> Function(Map<String, Object?>) onSuccess;
  final CoCreationCommandGateway Function(WidgetRef)? gateway;
  @override
  ConsumerState<PeopleCommand> createState() => _PeopleCommandState();
}

class _PeopleCommandState extends ConsumerState<PeopleCommand> {
  bool busy = false, failed = false;
  Future<void> send() async {
    final actor = ref.read(authSessionProvider).identity?.id;
    if (actor == null || busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final store = ref.read(peopleAttemptsProvider.notifier);
      final prior = ref.read(peopleAttemptsProvider)[widget.slot];
      if (prior?.pending == true &&
          (prior!.actor != actor ||
              prior.rpc != widget.rpc ||
              prior.intent['p_operation'] != widget.intent['p_operation'])) {
        throw StateError('Resolve the original co-creation operation first.');
      }
      final attempt = prior?.pending == true
          ? prior!
          : store.acquire(widget.slot, actor, widget.rpc, widget.intent);
      final result = await attempt.deliver(
        widget.gateway?.call(ref) ?? ref.read(peoplePrivateGatewayProvider),
      );
      if (!mounted || ref.read(authSessionProvider).identity?.id != actor) {
        return;
      }
      attempt.busy = true;
      try {
        await widget.onSuccess(result);
        attempt.completionPending = false;
        store.clear(widget.slot, expected: attempt);
      } finally {
        attempt.busy = false;
      }
    } catch (_) {
      if (mounted && ref.read(authSessionProvider).identity?.id == actor) {
        setState(() => failed = true);
      }
    } finally {
      if (mounted && ref.read(authSessionProvider).identity?.id == actor) {
        ref.read(peopleAttemptsProvider.notifier).updated();
      }
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prior = ref.watch(peopleAttemptsProvider)[widget.slot];
    final pending = prior?.pending == true;
    final matching =
        !pending ||
        (prior!.rpc == widget.rpc &&
            prior.intent['p_operation'] == widget.intent['p_operation']);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failed) Text(l.coPeopleError),
        if (pending && matching) Text(l.coPeoplePending),
        FilledButton(
          onPressed: busy || !matching || prior?.busy == true ? null : send,
          child: Text(pending && matching ? l.coPeopleRetry : widget.label),
        ),
      ],
    );
  }
}

String peopleStateLabel(AppLocalizations l, String state) => switch (state) {
  'draft' => l.coPeopleDraft,
  'open' => l.coPeopleOpen,
  'closed' => l.coPeopleStateClosed,
  'pending' => l.coPeopleStatePending,
  'accepted' => l.coPeopleAccepted,
  'declined' => l.coPeopleDeclined,
  'withdrawn' => l.coPeopleWithdrawn,
  _ => throw const FormatException('Unsupported people state.'),
};
