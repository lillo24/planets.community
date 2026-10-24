import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../../policies/application/policy_documents.dart';
import '../application/people_signals.dart';
import '../data/co_creation_rooms_gateway.dart';
import 'people_widgets.dart';

/// Volatile authorized pages. A covered/background/invalidated view cannot
/// adopt a late response. Every continuation rechecks current server authority.
class CoPlacesRead<T> extends ConsumerStatefulWidget {
  const CoPlacesRead({
    required this.load,
    required this.builder,
    this.more,
    this.onInvalidate,
    this.poll = true,
    this.retainCovered = false,
    super.key,
  });
  final Future<T> Function(WidgetRef, String, T?) load;
  final Widget Function(BuildContext, List<T>, Future<void> Function()) builder;
  final bool Function(T)? more;
  final VoidCallback? onInvalidate;
  final bool poll, retainCovered;
  @override
  ConsumerState<CoPlacesRead<T>> createState() => _ReadState<T>();
}

class _ReadState<T> extends ConsumerState<CoPlacesRead<T>>
    with WidgetsBindingObserver {
  List<T> pages = [];
  bool busy = true, failed = false;
  int generation = 0;
  bool? priorActive;
  Timer? timer;
  bool get active =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      TickerMode.valuesOf(context).enabled &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  bool get authorized {
    final auth = ref.read(authSessionProvider);
    return auth.phase == AuthSessionPhase.ready &&
        ref
            .read(policyAcceptanceProvider)
            .allows(auth.identity?.id, ref.read(policyVersionProvider));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.poll) {
      timer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (active && authorized) refresh();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = active;
    if (priorActive != now) {
      priorActive = now;
      // A form's owned search/picker dialog pauses adoption without destroying
      // unsubmitted input. Account/policy/hints/background still erase it.
      if (widget.retainCovered && pages.isNotEmpty) {
        generation++;
        setState(() {});
      } else {
        invalidate();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => invalidate();
  void invalidate() {
    generation++;
    pages = [];
    busy = false;
    failed = false;
    if (widget.onInvalidate != null) {
      Future.microtask(() {
        if (mounted) widget.onInvalidate!();
      });
    }
    if (mounted) setState(() {});
    if (active && authorized) Future.microtask(refresh);
  }

  Future<void> refresh() => load(false);
  Future<void> load(bool append) async {
    if (!active || !authorized) return;
    final token = ++generation,
        actor = ref.read(authSessionProvider).identity!.id;
    final gateway = ref.read(coCreationRoomsGatewayProvider);
    final before = append && pages.isNotEmpty ? pages.last : null;
    setState(() {
      busy = true;
      failed = false;
      if (!append) pages = [];
    });
    try {
      final value = await widget.load(ref, actor, before);
      if (!mounted ||
          token != generation ||
          !active ||
          !authorized ||
          ref.read(authSessionProvider).identity?.id != actor ||
          !identical(gateway, ref.read(coCreationRoomsGatewayProvider))) {
        return;
      }
      setState(() {
        pages = [if (append) ...pages, value];
        busy = false;
      });
    } catch (_) {
      if (mounted && token == generation && active) {
        setState(() {
          pages = [];
          failed = true;
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(peopleSignalsProvider, (_, _) => invalidate());
    ref.listen(
      authSessionProvider.select((s) => (s.identity?.id, s.phase)),
      (_, _) => invalidate(),
    );
    ref.listen(policyAcceptanceProvider, (_, _) => invalidate());
    ref.listen(policyVersionProvider, (_, _) => invalidate());
    ref.listen(coCreationRoomsGatewayProvider, (_, _) => invalidate());
    final l = AppLocalizations.of(context);
    return PeopleAccess(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy) const LinearProgressIndicator(),
          if (failed) ...[
            Text(l.coPeopleError),
            TextButton(onPressed: refresh, child: Text(l.coPeopleRetry)),
          ],
          if (pages.isNotEmpty &&
              authorized &&
              (active || widget.retainCovered))
            Offstage(
              offstage: !active,
              child: widget.builder(
                context,
                List.unmodifiable(pages),
                () async {
                  widget.onInvalidate?.call();
                  await refresh();
                },
              ),
            ),
          if (!busy &&
              pages.isNotEmpty &&
              widget.more?.call(pages.last) == true)
            TextButton(
              onPressed: () => load(true),
              child: Text(l.coPeopleMore),
            ),
        ],
      ),
    );
  }
}
