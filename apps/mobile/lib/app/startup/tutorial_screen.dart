import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/loading_state.dart';
import '../../core/widgets/planets_hero.dart';
import '../../features/auth/application/auth_session_controller.dart';
import '../../features/messages/presentation/messages_landing_screen.dart';
import '../../features/cover_media/application/cover_image_loader.dart';
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
import 'tutorial_motion.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _surface = GlobalKey();
  final _scrollStorage = PageStorageBucket();
  int _index = 0;
  int _generation = 0;
  int _attempts = 0;
  Timer? _probe;
  Timer? _transition;
  Timer? _hold;
  late final _reveal =
      AnimationController(vsync: this, duration: tutorialSpotlightFade)
        ..addStatusListener((status) {
          if (mounted && status == AnimationStatus.completed) {
            setState(() => _revealPhase = TutorialRevealPhase.ready);
          }
        });
  TutorialRevealPhase _revealPhase = TutorialRevealPhase.entering;
  bool _newPage = true;
  bool _pageRecognized = false;
  final _warmedCovers = <String>{};
  Size? _surfaceSize;
  bool _active = true;
  bool _locked = false;
  bool _saving = false;
  bool _failed = false;
  bool _scrolling = false;
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
    TutorialStep.projectCard ||
    TutorialStep.projectCreate ||
    TutorialStep.projectDrafts => _projectFallback,
    TutorialStep.projectDetail => _projectFallback || _detailFallback,
    TutorialStep.resources => _resourceFallback,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Public, nonblocking and filter-preserving; browse reuses this controller.
    Future<void>.microtask(() {
      if (!mounted) return;
      if (ref.read(publicProposalsProvider).phase == ProposalLoadPhase.idle) {
        unawaited(ref.read(publicProposalsProvider.notifier).load());
      }
    });
  }

  void _interrupt({bool preserveReveal = false}) {
    _generation++;
    _probe?.cancel();
    if (!preserveReveal) {
      _hold?.cancel();
      _reveal.stop();
      if (_revealPhase == TutorialRevealPhase.unobscured) {
        _revealPhase = TutorialRevealPhase.entering;
        _pageRecognized = false;
      }
    }
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
      _interrupt(preserveReveal: true);
      _targets = const [];
      _attempts = 0;
      if (layout.reduced && _pageRecognized) {
        _reveal.value = 1;
        _revealPhase = TutorialRevealPhase.ready;
      }
    }
    _layout = layout;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _probe?.cancel();
    _transition?.cancel();
    _hold?.cancel();
    _reveal.dispose();
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
    final previousPage = _surfaceGroup();
    _interrupt();
    setState(() {
      _locked = true;
      _index = index;
      _attempts = 0;
      _targets = const [];
      _failed = false;
      _newPage = previousPage != _surfaceGroup();
      _pageRecognized = !_newPage;
      _revealPhase = TutorialRevealPhase.entering;
      _reveal.value = 0;
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

  void _measureSurface(Size size) {
    final previous = _surfaceSize;
    _surfaceSize = size;
    if (previous == null || previous == size) return;
    // The actual canvas can resize independently of MediaQuery (explanation
    // reflow, split view or test/native viewport constraints).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _interrupt(preserveReveal: true);
      setState(() {
        _targets = const [];
        _attempts = 0;
      });
      _scheduleProbe();
    });
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
    TutorialStep.messagesTabs => const ['messages-requests-action'],
    TutorialStep.messagesScopes => const ['message-chat-scope-toggle'],
  };

  bool _dataPending() {
    if (_fallback) return false;
    if (_step == TutorialStep.projectCard ||
        _step == TutorialStep.projectCreate ||
        _step == TutorialStep.projectDrafts) {
      return _projectId == null;
    }
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
      if (_step == TutorialStep.projectCard ||
          _step == TutorialStep.projectCreate ||
          _step == TutorialStep.projectDrafts) {
        _projectFallback = true;
      }
      if (_step == TutorialStep.resources) _resourceFallback = true;
      _targets = const [];
      _attempts = 0;
      _pageRecognized = false;
      _revealPhase = TutorialRevealPhase.entering;
      _newPage = true;
      _reveal.value = 0;
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
    final destination = offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (reduced) {
      position.jumpTo(destination);
    } else {
      await position.animateTo(
        destination,
        duration: slow
            ? tutorialScrollDuration(distance)
            : const Duration(milliseconds: 250),
        curve: Curves.linear,
      );
    }
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
    if (!_pageRecognized) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pageRecognized = true;
      } else {
        // This probe runs after meaningful content has painted. Rebuilds and
        // later metric/image changes do not restart an already recognized page.
        if (_revealPhase != TutorialRevealPhase.unobscured) {
          setState(() => _revealPhase = TutorialRevealPhase.unobscured);
          _hold = Timer(tutorialPageHold, () {
            if (!mounted ||
                !_active ||
                _revealPhase != TutorialRevealPhase.unobscured) {
              return;
            }
            _pageRecognized = true;
            _scheduleProbe();
          });
        }
        return;
      }
    }
    final anchors = _anchors();
    final visible = (Offset.zero & rootBox.size).deflate(8);
    final rects = <Rect>[];
    for (var i = 0; i < anchors.length; i++) {
      final anchor = _find(Key(anchors[i]));
      // Toolbar keys include their 48dp hit padding. Measure the actual visible
      // icon for a snug Drafts/Requests hole instead of shifting global rects.
      final iconTarget =
          anchors[i] == 'my-proposals-action' ||
          anchors[i] == 'resource-my-listings-action' ||
          anchors[i] == 'messages-requests-action';
      final box = (iconTarget ? _iconElement(anchor) : anchor)
          ?.findRenderObject();
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
        // A tall card can start inside the viewport yet expose only a sliver
        // after list reordering or a taller discovery header. Reveal enough
        // actual content before accepting its clipped spotlight.
        final tooLittle =
            rect.height > viewport.height &&
            rect.intersect(viewport).height <
                (viewport.height * .5).clamp(0, 96);
        if (rect.top < viewport.top - 1 ||
            rect.top >= viewport.bottom ||
            tooLow ||
            tooLittle) {
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
      rect = rect.inflate(iconTarget ? 3 : 6).intersect(viewport);
      if (rect.isEmpty) break;
      rects.add(rect);
    }
    if (rects.length == anchors.length) {
      // Each target remains separate, including the three Scambio controls.
      final targets = rects;
      if (!listEquals(_targets, targets)) {
        setState(() {
          _targets = List.unmodifiable(targets);
          if (_revealPhase == TutorialRevealPhase.entering ||
              _revealPhase == TutorialRevealPhase.unobscured) {
            _revealPhase = TutorialRevealPhase.fading;
            if (MediaQuery.disableAnimationsOf(context)) {
              _reveal.value = 1;
              _revealPhase = TutorialRevealPhase.ready;
            } else {
              _reveal.duration = _newPage
                  ? tutorialSpotlightFade
                  : tutorialFocusFade;
              _reveal.forward(from: 0);
            }
          } else if (_revealPhase == TutorialRevealPhase.fading &&
              !_reveal.isAnimating) {
            _reveal.forward();
          }
        });
      }
      if (_revealPhase == TutorialRevealPhase.fading && !_reveal.isAnimating) {
        _reveal.forward();
      }
      return;
    }
    // Public browse cards can be lazy. The tutorial's real detail uses eager
    // section layout, so its measured participation distance needs one motion.
    final scrollable = _firstVerticalScrollable();
    if (scrollable != null &&
        scrollable.position.pixels < scrollable.position.maxScrollExtent - 1) {
      await _scrollTo(
        scrollable.position,
        (scrollable.position.pixels + scrollable.position.viewportDimension)
            .clamp(0, scrollable.position.maxScrollExtent),
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

  Element? _iconElement(Element? parent) {
    Element? result;
    void visit(Element element) {
      if (element.widget is Icon) {
        result ??= element;
      } else {
        element.visitChildren(visit);
      }
    }

    if (parent != null) visit(parent);
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
    TutorialStep.introduction => const Scaffold(
      body: Center(child: PlanetsHero()),
    ),
    TutorialStep.farewell => const Scaffold(body: PlanetsHero.farewell()),
    TutorialStep.home || TutorialStep.homeResources => const FoundationScreen(),
    TutorialStep.projectCard => _projectBrowse(),
    TutorialStep.projectCreate ||
    TutorialStep.projectDrafts => _projectBrowse(),
    TutorialStep.projectDetail =>
      _fallback
          ? const TutorialIllustration()
          : _projectId == null
          ? Scaffold(
              appBar: AppBar(
                title: Text(AppLocalizations.of(context).proposalDetailTitle),
              ),
              body: LoadingState(
                message: AppLocalizations.of(context).proposalLoading,
              ),
            )
          : ProposalDetailScreen(
              key: PageStorageKey('proposal-detail-$_projectId'),
              proposalId: _projectId!,
              tutorialPreview: true,
            ),
    TutorialStep.resources => _resources(),
    TutorialStep.messagesTabs || TutorialStep.messagesScopes =>
      const MessagesLandingScreen(controlsOnly: true),
  };

  void _selectProject(PublicProposalsState state) {
    if (_projectId == null &&
        !_fallback &&
        state.phase == ProposalLoadPhase.ready) {
      // Match the actual browse order, including the authenticated Requested
      // section. Never skip Full/actionless/photo-less public Projects.
      if (state.requestedItems.isNotEmpty) {
        _projectId = state.requestedItems.first.proposal.id;
      } else if (state.ordinaryItems.isNotEmpty) {
        _projectId = state.ordinaryItems.first.id;
      }
      if (_projectId != null) _attempts = 0;
    }
  }

  void _primeProjects(PublicProposalsState state) {
    if (!identical(state, ref.read(publicProposalsProvider)) ||
        state.phase != ProposalLoadPhase.ready) {
      return;
    }
    final visible = [
      ...state.requestedItems.map((item) => item.proposal),
      ...state.ordinaryItems,
    ];
    for (final proposal in visible.take(3)) {
      final path = proposal.coverObjectPath;
      if (path != null && _warmedCovers.add(path)) {
        // The same authorized public FutureProvider/cache used by cover widgets;
        // errors remain visible there and never become fabricated thumbnails.
        unawaited(
          ref
              .read(publicCoverBytesProvider(path).future)
              .then<void>((_) {}, onError: (Object error, StackTrace stack) {}),
        );
      }
    }
    if (visible.isNotEmpty && _projectId == null && !_projectFallback) {
      _projectId = visible.first.id;
      final detail = ref.read(proposalDetailProvider);
      // Preserve a different detail belonging to a covered caller during
      // warmup. Visiting this tour's detail can load its selected ID normally.
      if (detail.phase == ProposalLoadPhase.idle ||
          detail.proposalId == _projectId) {
        unawaited(
          ref.read(proposalDetailProvider.notifier).ensureLoaded(_projectId!),
        );
      }
    }
  }

  Widget _projectBrowse() => PublicProposalsScreen(
    tutorialPlaceholder: _projectFallback ? const TutorialExampleCard() : null,
  );

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
    final projects = ref.watch(publicProposalsProvider);
    // Provider reads/mutations are scheduled outside build; frozen tour
    // selection remains the first actual canonical visible result.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _active) _primeProjects(projects);
    });
    if (_step == TutorialStep.projectCard || _isDetail) {
      // Next stays available while loading. Keep selection active in detail
      // until the first public read settles, without substituting an example.
      _selectProject(ref.watch(publicProposalsProvider));
    }
    void refreshFocus() {
      _interrupt(preserveReveal: true);
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
                    const SizedBox(width: 16),
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _measureSurface(constraints.biggest);
                      return PageStorage(
                        bucket: _scrollStorage,
                        child: Stack(
                          key: _surface,
                          fit: StackFit.expand,
                          children: [
                            ExcludeSemantics(
                              child: IgnorePointer(
                                child:
                                    NotificationListener<
                                      ScrollMetricsNotification
                                    >(
                                      onNotification: (_) {
                                        if (_isDetail) {
                                          // Async detail sections can move participation
                                          // after initial focus. Re-locate real controls
                                          // from layout metrics without loading data here.
                                          _attempts = 0;
                                          if (_targets.isNotEmpty) {
                                            setState(() => _targets = const []);
                                          }
                                          _scheduleProbe();
                                        }
                                        return false;
                                      },
                                      child: KeyedSubtree(
                                        key: ValueKey(
                                          'tutorial-surface-${_surfaceGroup()}',
                                        ),
                                        child: _content(),
                                      ),
                                    ),
                              ),
                            ),
                            Positioned.fill(
                              child: GestureDetector(
                                key: const Key('tutorial-overlay'),
                                behavior: HitTestBehavior.opaque,
                                onTap:
                                    restoreFailed ||
                                        _step == TutorialStep.farewell
                                    ? null
                                    : _advance,
                                child: AnimatedBuilder(
                                  animation: _reveal,
                                  builder: (context, child) => CustomPaint(
                                    key: const Key('tutorial-spotlight'),
                                    painter: TutorialScrim(
                                      _targets,
                                      _noSpotlight
                                          ? Colors.transparent
                                          : Colors.black.withValues(
                                              alpha: .62 * _reveal.value,
                                            ),
                                      opacity: _noSpotlight ? 0 : _reveal.value,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontSize: 19, height: 1.4),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('tutorial-previous'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                          onPressed: _saving || _locked ? null : _previous,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(l.tutorialPrevious),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                          key: const Key('tutorial-next'),
                          onPressed: _saving || _locked
                              ? null
                              : restoreFailed
                              ? () async {
                                  await flow.retryRestore();
                                  if (mounted) setState(() {});
                                }
                              : _advance,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              restoreFailed
                                  ? l.retryAction
                                  : _step == TutorialStep.farewell
                                  ? l.tutorialStartExploring
                                  : l.tutorialNext,
                            ),
                          ),
                        ),
                      ),
                    ],
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
