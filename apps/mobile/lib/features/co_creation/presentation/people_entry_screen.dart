import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../settings/application/co_creation_preference_controller.dart';
import '../data/people_intro_preference.dart';
import 'people_interests_intro.dart';

/// Only the root discovery entry owns the automatic illustration. Never place
/// this wrapper on Messages, room, auth or editor continuations.
class PeopleEntryScreen extends ConsumerStatefulWidget {
  const PeopleEntryScreen({
    required this.ordinaryEntry,
    required this.child,
    super.key,
  });
  final bool ordinaryEntry;
  final Widget child;

  @override
  ConsumerState<PeopleEntryScreen> createState() => _PeopleEntryScreenState();
}

class _PeopleEntryScreenState extends ConsumerState<PeopleEntryScreen> {
  bool _started = false, _intro = false, _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.ordinaryEntry &&
        ref.read(coCreationPreferenceProvider).enabled &&
        !ref.read(peopleIntroSessionProvider)) {
      _loading = true;
      _prepare();
    }
  }

  bool get _ordinaryNow {
    final uri = GoRouter.of(context).routeInformationProvider.value.uri;
    return widget.ordinaryEntry &&
        uri.path == '/people' &&
        !uri.hasQuery &&
        ref.read(coCreationPreferenceProvider).enabled &&
        (ModalRoute.isCurrentOf(context) ?? false);
  }

  Future<void> _prepare() async {
    try {
      final store = ref.read(peopleIntroPreferenceStoreProvider);
      final seen = await store.readSeen();
      if (!mounted) return;
      final show =
          !seen &&
          _ordinaryNow &&
          ref.read(peopleIntroSessionProvider.notifier).claim();
      setState(() {
        _loading = false;
        _intro = show;
      });
      if (show) await store.markSeen();
    } catch (_) {
      // Local storage is an explicit UI boundary. Report failure and keep the
      // optional illustration from blocking discovery or protected navigation.
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).coIntroStorageError),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(coCreationPreferenceProvider).enabled;
    if (!enabled) return widget.child;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_intro) return widget.child;
    return PeopleInterestsIntro(
      onExplore: () => setState(() => _intro = false),
      onClose: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
    );
  }
}
