import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/planets_hero.dart';
import '../../features/auth/application/auth_session_controller.dart';
import '../../features/messages/presentation/messages_landing_screen.dart';
import '../../features/proposals/application/proposal_controllers.dart';
import '../../features/proposals/domain/proposal_models.dart';
import '../../features/proposals/presentation/public_proposals_screen.dart';
import '../../features/resource_listings/application/resource_listing_controllers.dart';
import '../../features/resource_listings/domain/resource_listing_models.dart';
import '../../features/resource_listings/presentation/public_resource_listings_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../foundation_screen.dart';
import 'startup_flow.dart';
import 'tutorial_pages.dart';
import 'tutorial_presentation.dart';
import 'tutorial_routes.dart';

class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({
    required this.returnTo,
    this.replay = false,
    super.key,
  });
  final String returnTo;
  final bool replay;
  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen>
    with WidgetsBindingObserver {
  final _surface = GlobalKey();
  final _scrollStorage = PageStorageBucket();
  int _index = 0;
  int _generation = 0;
  int _attempts = 0;
  Timer? _probe;
  Timer? _transition;
  bool _active = true;
  bool _locked = false;
  bool _saving = false;
  bool _failed = false;
  bool _scrolling = false;
  bool _detailStarted = false;
  bool _projectFallback = false;
  bool _detailFallback = false;
  bool _resourceFallback = false;
  List<Rect> _targets = const [];
  ScrollPosition? _movingPosition;
  String? _projectId;
  String? _resourceId;
  ({Locale locale, Size size, double scale, bool reduced})? _layout;

  TutorialStep get _step =>
      ref.read(startupFlowProvider).registry.steps[_index];
  bool get _isDetail => _step == TutorialStep.projectDetail;
  bool get _noSpotlight =>
      _step == TutorialStep.introduction || _step == TutorialStep.farewell;
  bool get _fallback => switch (_step) {
    TutorialStep.projectCard => _projectFallback,
    TutorialStep.projectDetail => _projectFallback || _detailFallback,
    TutorialStep.resources => _resourceFallback,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _interrupt() {
    _generation++;
    _probe?.cancel();
    // animateTo completes after jumpTo, but its stale generation cannot rearm.
    final position = _movingPosition;
    if (position != null && position.hasPixels) {
      position.jumpTo(position.pixels);
    }
    _movingPosition = null;
    _scrolling = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final layout = (
      locale: Localizations.localeOf(context),
      size: MediaQuery.sizeOf(context),
      scale: MediaQuery.textScalerOf(context).scale(14),
      reduced: MediaQuery.disableAnimationsOf(context),
    );
    if (_layout != null && _layout != layout) {
      _interrupt();
      _targets = const [];
      _attempts = 0;
    }
    _layout = layout;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _probe?.cancel();
    _transition?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _interrupt();
    if (_active) {
      _attempts = 0;
      _scheduleProbe();
    }
  }

  void _leave({bool completed = false}) {
    _interrupt();
    if (widget.replay && context.canPop()) {
      context.pop();
    } else {
      final flow = ref.read(startupFlowProvider);
      context.go(
        completed
            ? startupReturnDestination(widget.returnTo)
            : flow.cancelTutorial(tutorialExitDestination(widget.returnTo)),
      );
    }
  }

  Future<void> _save({required bool dismiss}) async {
    if (_saving) return;
    _interrupt();
    if (widget.replay) {
      setState(() => _saving = true);
      _leave();
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    final flow = ref.read(startupFlowProvider);
    final saved = dismiss
        ? await flow.dismissTutorial()
        : await flow.finishTutorial();
    if (!mounted) return;
    if (saved) {
      _leave(completed: !dismiss);
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  void _previous() {
    if (_saving || _locked || !_active) return;
    if (_index == 0) {
      _leave();
    } else {
      _move(_index - 1);
    }
  }

  void _advance() {
    if (_locked || _saving || !_active) return;
    if (_step == TutorialStep.farewell) {
      unawaited(_save(dismiss: false));
    } else {
      _move(_index + 1);
    }
  }

  void _move(int index) {
    _interrupt();
    setState(() {
      _locked = true;
      _index = index;
      _attempts = 0;
      _targets = const [];
      _failed = false;
    });
    // Only the short surface commit is debounced, never the explanation/read
    // or detail scroll. Previous/Next may interrupt that scroll afterwards.
    _transition?.cancel();
    _transition = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _locked = false);
    });
    _scheduleProbe();
  }

  void _scheduleProbe() {
    if (!mounted ||
        !_active ||
        _saving ||
        _probe?.isActive == true ||
        _scrolling ||
        _noSpotlight) {
      return;
    }
    final generation = _generation;
    _probe = Timer(const Duration(milliseconds: 80), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            generation == _generation &&
            _active &&
            !_saving &&
            ModalRoute.of(context)?.isCurrent == true) {
          unawaited(_locate(generation));
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  Element? _find(Key key) {
    Element? match;
    void visit(Element element) {
      if (element.widget.key == key) {
        match = element;
        return;
      }
      element.visitChildren((child) {
        if (match == null) visit(child);
      });
    }

    final root = _surface.currentContext;
    if (root != null) visit(root as Element);
    return match;
  }

  List<String> _anchors() => switch (_step) {
    TutorialStep.introduction || TutorialStep.farewell => const [],
    TutorialStep.home => const ['browse-proposals-button'],
    TutorialStep.homeResources => const ['browse-resources-button'],
    TutorialStep.projectCard => [
      _fallback ? 'tutorial-example-card' : 'proposal-card-$_projectId',
    ],
    TutorialStep.projectDetail => [
      if (_fallback)
        'tutorial-example-participation'
      else if (_find(Key('participation-join-$_projectId')) != null)
        'participation-join-$_projectId'
      else if (_find(Key('participation-full-$_projectId')) != null)
        'participation-full-$_projectId'
      else
        'participation-title-$_projectId',
    ],
    TutorialStep.projectCreate => const ['proposal-create-action'],
    TutorialStep.projectDrafts => const ['my-proposals-action'],
    TutorialStep.resources => [
      _fallback ? 'tutorial-example-card' : 'resource-card-$_resourceId',
      'resource-create-action',
      'resource-my-listings-action',
    ],
    TutorialStep.messagesTabs => const [
      'messages-tab-chat',
      'messages-tab-requests',
    ],
    TutorialStep.messagesScopes => const ['message-chat-scope-toggle'],
  };

  bool _dataPending() {
    if (_fallback) return false;
    if (_step == TutorialStep.projectCard) return _projectId == null;
    if (_isDetail) {
      final state = ref.read(proposalDetailProvider);
      return state.phase != ProposalLoadPhase.ready ||
          state.proposalId != _projectId ||
          state.detail == null ||
          state.detail!.summary.id != _projectId;
    }
    if (_step == TutorialStep.resources) return _resourceId == null;
    return false;
  }

  void _useFallback() {
    setState(() {
      if (_isDetail) _detailFallback = true;
      if (_step == TutorialStep.projectCard) _projectFallback = true;
      if (_step == TutorialStep.resources) _resourceFallback = true;
      _targets = const [];
      _attempts = 0;
    });
    _scheduleProbe();
  }

  Future<void> _scrollTo(
    ScrollPosition position,
    double offset,
    int generation, {
    required bool slow,
  }) async {
    _movingPosition = position;
    _scrolling = true;
    final distance = (offset - position.pixels).abs();
    final reduced = MediaQuery.disableAnimationsOf(context);
    await position.animateTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: reduced
          ? const Duration(milliseconds: 1)
          : Duration(
              milliseconds: slow
                  ? (distance / 70 * 1000).round().clamp(800, 12000)
                  : 250,
            ),
      curve: Curves.linear,
    );
    if (!mounted || generation != _generation) return;
    _movingPosition = null;
    _scrolling = false;
    _scheduleProbe();
  }

  Future<void> _locate(int generation) async {
    if (_scrolling || generation != _generation) return;
    _attempts++;
    final rootBox = _surface.currentContext?.findRenderObject() as RenderBox?;
    if (rootBox == null || !rootBox.hasSize) {
      _scheduleProbe();
      return;
    }
    if (_dataPending()) {
      if (_attempts >= 25) {
        _useFallback();
      } else {
        _scheduleProbe();
      }
      return;
    }
    if (_isDetail &&
        !_detailStarted &&
        !MediaQuery.disableAnimationsOf(context)) {
      _detailStarted = true;
      // Let the selected cover/title be read before moving through the body.
      _probe = Timer(const Duration(seconds: 1), _scheduleProbe);
      return;
    }
    _detailStarted = _detailStarted || _isDetail;
    final anchors = _anchors();
    final visible = (Offset.zero & rootBox.size).deflate(8);
    final rects = <Rect>[];
    for (var i = 0; i < anchors.length; i++) {
      final anchor = _find(Key(anchors[i]));
      final box = anchor?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || box.size.isEmpty) break;
      var rect = box.localToGlobal(Offset.zero, ancestor: rootBox) & box.size;
      var viewport = visible;
      final scrollable = Scrollable.maybeOf(anchor!);
      if (scrollable != null &&
          axisDirectionToAxis(scrollable.axisDirection) == Axis.vertical) {
        final scrollBox = scrollable.context.findRenderObject();
        if (scrollBox is RenderBox && scrollBox.hasSize) {
          viewport = viewport.intersect(
            scrollBox.localToGlobal(Offset.zero, ancestor: rootBox) &
                scrollBox.size,
          );
        }
        // Keep the resource card hole separate from its fixed Create action.
        if (_step == TutorialStep.resources && i == 0) {
          final fab = _find(const Key('resource-create-action'))
              ?.findRenderObject();
          if (fab is RenderBox && fab.hasSize) {
            viewport = Rect.fromLTRB(
              viewport.left,
              viewport.top,
              viewport.right,
              fab.localToGlobal(Offset.zero, ancestor: rootBox).dy - 14,
            );
          }
        }
        final tooLow =
            rect.bottom > viewport.bottom && rect.height <= viewport.height;
        if (rect.top < viewport.top - 1 ||
            rect.top >= viewport.bottom ||
            tooLow) {
          final delta = rect.top - viewport.top - 8;
          final next = (scrollable.position.pixels + delta).clamp(
            scrollable.position.minScrollExtent,
            scrollable.position.maxScrollExtent,
          );
          if ((next - scrollable.position.pixels).abs() > 1) {
            await _scrollTo(
              scrollable.position,
              next,
              generation,
              slow: _isDetail,
            );
            return;
          }
        }
      }
      rect = rect.intersect(viewport);
      if (rect.isEmpty) break;
      rects.add(rect);
    }
    if (rects.length == anchors.length) {
      // Chat/Requests is one contiguous group; Scambio is three distinct holes.
      final targets = _step == TutorialStep.messagesTabs
          ? [rects[0].expandToInclude(rects[1])]
          : rects;
      if (!listEquals(_targets, targets)) {
        setState(() => _targets = List.unmodifiable(targets));
      }
      return;
    }
    // Lazy details/cards may not be built yet. Scan only the real vertical list,
    // slowly in detail, without highlighting intermediate body/needs content.
    final scrollable = _firstVerticalScrollable();
    if (scrollable != null &&
        scrollable.position.pixels < scrollable.position.maxScrollExtent - 1) {
      await _scrollTo(
        scrollable.position,
        (scrollable.position.pixels + 160).clamp(
          0,
          scrollable.position.maxScrollExtent,
        ),
        generation,
        slow: _isDetail,
      );
      return;
    }
    if (_attempts >= 25 &&
        !_fallback &&
        (_isDetail ||
            _step == TutorialStep.projectCard ||
            _step == TutorialStep.resources)) {
      _useFallback();
    } else if (_attempts < 30) {
      _scheduleProbe();
    }
  }

  ScrollableState? _firstVerticalScrollable() {
    ScrollableState? result;
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (axisDirectionToAxis(state.axisDirection) == Axis.vertical) {
          result ??= state;
        }
      }
      element.visitChildren(visit);
    }

    final root = _surface.currentContext;
    if (root != null) visit(root as Element);
    return result;
  }

  String _surfaceGroup() => switch (_step) {
    TutorialStep.projectCard ||
    TutorialStep.projectCreate ||
    TutorialStep.projectDrafts => 'projects',
    TutorialStep.projectDetail => 'detail-$_projectId-$_fallback',
    TutorialStep.home || TutorialStep.homeResources => 'home',
    TutorialStep.messagesTabs || TutorialStep.messagesScopes => 'messages',
    _ => _step.name,
  };

  Widget _content() => switch (_step) {
    TutorialStep.introduction ||
    TutorialStep.farewell => const Scaffold(body: Center(child: PlanetsHero())),
    TutorialStep.home || TutorialStep.homeResources => const FoundationScreen(),
    TutorialStep.projectCard => _projectBrowse(select: true),
    TutorialStep.projectCreate ||
    TutorialStep.projectDrafts => _projectBrowse(),
    TutorialStep.projectDetail =>
      _fallback || _projectId == null
          ? const TutorialIllustration()
          : ProposalDetailScreen(
              key: PageStorageKey('proposal-detail-$_projectId'),
              proposalId: _projectId!,
            ),
    TutorialStep.resources => _resources(),
    TutorialStep.messagesTabs || TutorialStep.messagesScopes =>
      const MessagesLandingScreen(controlsOnly: true),
  };

  Widget _projectBrowse({bool select = false}) {
    final state = ref.watch(publicProposalsProvider);
    if (select &&
        _projectId == null &&
        !_projectFallback &&
        state.phase == ProposalLoadPhase.ready) {
      // Match the actual browse order, including the authenticated Requested
      // section. Never skip Full/actionless/photo-less public Projects.
      if (state.requestedItems.isNotEmpty) {
        _projectId = state.requestedItems.first.proposal.id;
      } else if (state.ordinaryItems.isNotEmpty) {
        _projectId = state.ordinaryItems.first.id;
      }
    }
    return PublicProposalsScreen(
      tutorialPlaceholder: _projectFallback
          ? const TutorialExampleCard()
          : null,
    );
  }

  Widget _resources() {
    final state = ref.watch(publicResourceListingsProvider);
    if (_resourceId == null &&
        !_resourceFallback &&
        state.phase == ResourceListingLoadPhase.ready &&
        state.resultsMatchFilters &&
        state.items.isNotEmpty) {
      _resourceId = state.items.first.id;
    }
    return PublicResourceListingsScreen(
      key: const PageStorageKey('public-resources-list'),
      tutorialPlaceholder: _resourceFallback
          ? const TutorialExampleCard(resource: true)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.read(startupFlowProvider);
    if (flow.registry.steps.isEmpty) {
      return TutorialPages(returnTo: widget.returnTo);
    }
    final l = AppLocalizations.of(context);
    void refreshFocus() {
      _interrupt();
      setState(() {
        _targets = const [];
        _attempts = 0;
      });
    }

    ref.listen(publicProposalsProvider, (_, _) {
      if (_step == TutorialStep.projectCard) refreshFocus();
    });
    ref.listen(proposalDetailProvider, (_, _) {
      if (_isDetail) refreshFocus();
    });
    ref.listen(publicResourceListingsProvider, (_, _) {
      if (_step == TutorialStep.resources) refreshFocus();
    });
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      old,
      next,
    ) {
      if (old != next) {
        _interrupt();
        // Leave without a status write. Router reconciliation owns the new
        // identity and protected destinations; no former actor content survives.
        Future<void>.microtask(() {
          if (mounted) _leave();
        });
      }
    });
    _scheduleProbe();
    final restoreFailed = flow.preference.restoreFailed && !widget.replay;
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _previous();
        },
        child: Scaffold(
          key: const Key('tutorial-screen'),
          body: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    BackButton(
                      key: const Key('tutorial-previous'),
                      onPressed: _saving || _locked ? null : _previous,
                    ),
                    Expanded(
                      child: Text(
                        l.tutorialStepProgress(
                          _index + 1,
                          flow.registry.steps.length,
                        ),
                      ),
                    ),
                    Flexible(
                      flex: 2,
                      child: TextButton(
                        key: const Key('tutorial-skip'),
                        onPressed: _saving ? null : () => _save(dismiss: true),
                        child: Text(l.tutorialSkip),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: PageStorage(
                    bucket: _scrollStorage,
                    child: Stack(
                      key: _surface,
                      fit: StackFit.expand,
                      children: [
                        ExcludeSemantics(
                          child: IgnorePointer(
                            child: KeyedSubtree(
                              key: ValueKey(
                                'tutorial-surface-${_surfaceGroup()}',
                              ),
                              child: _content(),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: GestureDetector(
                            key: const Key('tutorial-overlay'),
                            behavior: HitTestBehavior.opaque,
                            onTap:
                                restoreFailed || _step == TutorialStep.farewell
                                ? null
                                : _advance,
                            child: CustomPaint(
                              key: const Key('tutorial-spotlight'),
                              painter: TutorialScrim(
                                _targets,
                                _noSpotlight
                                    ? Colors.transparent
                                    : Colors.black.withValues(alpha: .62),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .28,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        children: [
                          if (_step == TutorialStep.introduction)
                            Text(
                              l.tutorialSlogan,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          Text(
                            tutorialCopy(l, _step),
                            key: ValueKey('tutorial-copy-${_step.name}'),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (_failed || restoreFailed)
                            Text(
                              l.startupPreferenceError,
                              key: const Key('tutorial-write-error'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton(
                    key: const Key('tutorial-next'),
                    onPressed: _saving || _locked
                        ? null
                        : restoreFailed
                        ? () async {
                            await flow.retryRestore();
                            if (mounted) setState(() {});
                          }
                        : _advance,
                    child: Text(
                      restoreFailed
                          ? l.retryAction
                          : _step == TutorialStep.farewell
                          ? l.tutorialStartExploring
                          : l.tutorialNext,
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
