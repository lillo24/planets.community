import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/page_app_bar.dart';
import '../../l10n/generated/app_localizations.dart';
import 'startup_flow.dart';

class TutorialPages extends ConsumerStatefulWidget {
  const TutorialPages({required this.returnTo, super.key});

  final String returnTo;

  @override
  ConsumerState<TutorialPages> createState() => _TutorialPagesState();
}

class _TutorialPagesState extends ConsumerState<TutorialPages> {
  int _page = 0;
  bool _saving = false;
  bool _failed = false;

  void _cancel() =>
      context.go(ref.read(startupFlowProvider).cancelTutorial(widget.returnTo));

  Future<void> _advance() async {
    final flow = ref.read(startupFlowProvider);
    if (_page < flow.registry.pages.length - 1) {
      setState(() => _page++);
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    final saved = await flow.finishTutorial();
    if (!mounted) return;
    if (saved) {
      context.go(startupReturnDestination(widget.returnTo));
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.read(startupFlowProvider);
    final l10n = AppLocalizations.of(context);
    // Router excludes the empty registry. No placeholder or completion write.
    if (flow.registry.pages.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _cancel();
        },
        child: Scaffold(
          key: const Key('tutorial-screen'),
          appBar: pageAppBar(context, onClose: _cancel),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: flow.preference.restoreFailed
                      ? Center(child: Text(l10n.startupPreferenceError))
                      : flow.registry.pages[_page](context),
                ),
                if (_failed)
                  Text(
                    l10n.startupPreferenceError,
                    key: const Key('tutorial-write-error'),
                  ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: FilledButton(
                    key: const Key('tutorial-next'),
                    onPressed: _saving
                        ? null
                        : flow.preference.restoreFailed
                        ? () async {
                            await flow.retryRestore();
                          }
                        : _advance,
                    child: Text(
                      flow.preference.restoreFailed
                          ? l10n.retryAction
                          : _page == flow.registry.pages.length - 1
                          ? l10n.tutorialFinish
                          : l10n.tutorialNext,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
