import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/planets_hero.dart';
import '../../features/auth/application/auth_session_controller.dart';
import '../../features/messages/presentation/messages_landing_screen.dart';
import '../../features/proposals/application/proposal_controllers.dart';
import '../../features/project_resource_needs/application/project_resource_needs_controllers.dart';
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
  int _index = 0;
  int _generation = 0;
  int _attempts = 0;
  Timer? _automatic;
  Timer? _probe;
  Timer? _debounce;
  bool _active = true;
  bool _locked = false;
  bool _saving = false;
  bool _failed = false;
  bool _fallback = false;
  bool _scrolling = false;
  Rect? _target;
  ScrollPosition? _movingPosition;
  String? _projectId;
  String? _resourceId;
  String? _focusedAnchor;
  ({Locale locale, Size size, double scale, bool reduced})? _layout;

  TutorialStep get _step =>
      ref.read(startupFlowProvider).registry.steps[_index];
  bool get _isDetail => const {
    TutorialStep.projectPurpose,
    TutorialStep.projectNeeds,
    TutorialStep.projectParticipation,
  }.contains(_step);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      _generation++;
      _automatic?.cancel();
      _automatic = null;
      _probe?.cancel();
      _movingPosition?.jumpTo(_movingPosition!.pixels);
      _movingPosition = null;
      _scrolling = false;
      _target = null;
      _focusedAnchor = null;
      _attempts = 0;
    }
    _layout = layout;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _automatic?.cancel();
    _probe?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _generation++;
    _automatic?.cancel();
    _automatic = null;
    _probe?.cancel();
    _movingPosition?.jumpTo(_movingPosition!.pixels);
    _movingPosition = null;
    _scrolling = false;
    if (_active) {
      _attempts = 0;
      _scheduleProbe();
    }
  }

  void _leave({bool completed = false}) {
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
    _automatic?.cancel();
    _probe?.cancel();
    if (widget.replay) {
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

  void _advance() {
    if (_locked || _saving || !_active) return;
    if (_step == TutorialStep.farewell) {
      unawaited(_save(dismiss: false));
      return;
    }
    _locked = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _locked = false);
    _automatic?.cancel();
    _automatic = null;
    _probe?.cancel();
    _generation++;
    _movingPosition?.jumpTo(_movingPosition!.pixels);
    _movingPosition = null;
    // Stop the old scroll before changing the focused target.
    setState(() {
      _index++;
      _attempts = 0;
      _target = null;
      _focusedAnchor = null;
      _fallback = false;
      _scrolling = false;
      _failed = false;
    });
    _scheduleProbe();
  }

  void _scheduleProbe() {
    if (!mounted ||
        !_active ||
        _saving ||
        _probe?.isActive == true ||
        _scrolling) {
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

  String _anchor() {
    if (_fallback) {
      return switch (_step) {
        TutorialStep.projectPurpose => 'tutorial-example-purpose',
        TutorialStep.projectNeeds => 'tutorial-example-needs',
        TutorialStep.projectParticipation => 'tutorial-example-participation',
        _ => 'tutorial-example-card',
      };
    }
    return switch (_step) {
      TutorialStep.introduction => 'planets-floating-logo',
      TutorialStep.home => 'browse-proposals-button',
      TutorialStep.projectCard => 'proposal-card-title-$_projectId',
      TutorialStep.projectPurpose => 'tutorial-project-purpose',
      TutorialStep.projectNeeds => 'tutorial-project-needs',
      TutorialStep.projectParticipation => 'participation-join-$_projectId',
      TutorialStep.projectCreate => 'proposal-create-action',
      TutorialStep.projectDrafts => 'my-proposals-action',
      TutorialStep.resourceModes => 'resource-mode-filter',
      TutorialStep.resourceCard => 'resource-card-title-$_resourceId',
      TutorialStep.resourceCreate => 'resource-create-action',
      TutorialStep.resourceDrafts => 'resource-my-listings-action',
      TutorialStep.messagesTabs => 'messages-tab-chat',
      TutorialStep.messagesScopes => 'message-chat-scope-toggle',
      TutorialStep.farewell => 'message-chat-scope-toggle',
    };
  }

  bool _dataPending() {
    if (_fallback) return false;
    if (_step == TutorialStep.projectCard) {
      final state = ref.read(publicProposalsProvider);
      return state.phase != ProposalLoadPhase.ready;
    }
    if (_isDetail) {
      final state = ref.read(proposalDetailProvider);
      final detail = state.proposalId == _projectId ? state.detail : null;
      if (state.phase != ProposalLoadPhase.ready ||
          detail == null ||
          !_eligible(detail.summary)) {
        return true;
      }
      if (_step == TutorialStep.projectNeeds && _projectId != null) {
        final needs = ref.read(publicProjectResourceNeedsProvider(_projectId!));
        return needs.phase == PublicProjectResourceNeedsPhase.loading ||
            needs.phase == PublicProjectResourceNeedsPhase.failure;
      }
      return false;
    }
    if (_step == TutorialStep.resourceCard) {
      final state = ref.read(publicResourceListingsProvider);
      return state.phase != ResourceListingLoadPhase.ready ||
          !state.resultsMatchFilters;
    }
    return false;
  }

  Future<void> _locate(int generation) async {
    if (_scrolling) return;
    _attempts++;
    final rootBox = _surface.currentContext?.findRenderObject() as RenderBox?;
    if (rootBox == null || !rootBox.hasSize) {
      _scheduleProbe();
      return;
    }
    final anchor = _find(Key(_anchor()));
    final box = anchor?.findRenderObject();
    Rect? rect;
    if (!_dataPending() &&
        box is RenderBox &&
        box.hasSize &&
        box.size.width > 0 &&
        box.size.height > 0) {
      rect = box.localToGlobal(Offset.zero, ancestor: rootBox) & box.size;
      final visible = (Offset.zero & rootBox.size).deflate(8);
      if (_focusedAnchor != _anchor() &&
          (rect.top >= visible.bottom ||
              rect.bottom <= visible.top ||
              rect.top < visible.top ||
              (rect.bottom > visible.bottom &&
                  rect.height <= visible.height))) {
        final scrollable = Scrollable.maybeOf(anchor!);
        if (scrollable != null &&
            scrollable.axisDirection != AxisDirection.right &&
            scrollable.axisDirection != AxisDirection.left) {
          _automatic?.cancel();
          _automatic = null;
          _scrolling = true;
          _focusedAnchor = _anchor();
          _movingPosition = scrollable.position;
          await Scrollable.ensureVisible(
            anchor,
            alignment: rect.height > visible.height ? 0 : .3,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
          );
          if (!mounted || generation != _generation) return;
          _scrolling = false;
          _movingPosition = null;
          _scheduleProbe();
          return;
        }
      }
      if (_step == TutorialStep.messagesTabs) {
        final requests = _find(const Key('messages-tab-requests'))
            ?.findRenderObject();
        if (requests is RenderBox && requests.hasSize) {
          rect = rect.expandToInclude(
            requests.localToGlobal(Offset.zero, ancestor: rootBox) &
                requests.size,
          );
        }
      }
      rect = rect.intersect(visible);
      if (rect.isEmpty) rect = null;
    }
    if (rect != null) {
      if (_target != rect) setState(() => _target = rect);
      if (_automatic == null &&
          _step != TutorialStep.farewell &&
          !_failed &&
          (!ref.read(startupFlowProvider).preference.restoreFailed ||
              widget.replay)) {
        final shownAnchor = _anchor();
        _automatic = Timer(const Duration(seconds: 4), () {
          _automatic = null;
          if (mounted &&
              generation == _generation &&
              _active &&
              ModalRoute.of(context)?.isCurrent == true &&
              !_dataPending() &&
              !_scrolling &&
              shownAnchor == _anchor()) {
            _advance();
          } else if (mounted) {
            _scheduleProbe();
          }
        });
      }
      return;
    }
    _automatic?.cancel();
    _automatic = null;
    if (_target != null) setState(() => _target = null);
    // Find lazily built detail/list anchors with short, interruptible scrolls.
    if (!_dataPending() &&
        !_fallback &&
        (_isDetail ||
            _step == TutorialStep.projectCard ||
            _step == TutorialStep.resourceCard)) {
      ScrollableState? scroll;
      void visit(Element element) {
        if (element is StatefulElement && element.state is ScrollableState) {
          final candidate = element.state as ScrollableState;
          if (candidate.axisDirection == AxisDirection.down) {
            scroll ??= candidate;
          }
        }
        element.visitChildren(visit);
      }

      (_surface.currentContext! as Element).visitChildren(visit);
      if (scroll != null &&
          scroll!.position.hasContentDimensions &&
          scroll!.position.pixels < scroll!.position.maxScrollExtent &&
          _attempts < 30) {
        _scrolling = true;
        final position = scroll!.position;
        _movingPosition = position;
        if (MediaQuery.disableAnimationsOf(context)) {
          position.jumpTo(
            (position.pixels + 160).clamp(0, position.maxScrollExtent),
          );
        } else {
          await position.animateTo(
            (position.pixels + 160).clamp(0, position.maxScrollExtent),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeInOut,
          );
        }
        if (!mounted || generation != _generation) return;
        _scrolling = false;
        _movingPosition = null;
        _scheduleProbe();
        return;
      }
    }
    // Bounded waiting: offline/empty/unjoinable/missing actions use labelled
    // illustration widgets, never synthetic records in real browse providers.
    if (!_fallback &&
        _attempts >= 25 &&
        (_isDetail ||
            _step == TutorialStep.projectCard ||
            _step == TutorialStep.resourceCard)) {
      setState(() {
        _fallback = true;
        _attempts = 0;
      });
    }
    _scheduleProbe();
  }

  static bool _eligible(ProposalSummary item) =>
      (item.status == ProposalStatus.upcoming ||
          item.status == ProposalStatus.happening) &&
      !item.capacity.isFull;

  String _surfaceGroup() => _isDetail
      ? 'detail-$_projectId'
      : switch (_step) {
          TutorialStep.projectCard ||
          TutorialStep.projectCreate ||
          TutorialStep.projectDrafts => 'projects',
          TutorialStep.resourceModes ||
          TutorialStep.resourceCard ||
          TutorialStep.resourceCreate ||
          TutorialStep.resourceDrafts => 'resources',
          TutorialStep.messagesTabs ||
          TutorialStep.messagesScopes ||
          TutorialStep.farewell => 'messages',
          _ => _step.name,
        };

  Widget _content() {
    if (_fallback) return TutorialIllustration(step: _step);
    switch (_step) {
      case TutorialStep.introduction:
        return const Scaffold(body: Center(child: PlanetsHero()));
      case TutorialStep.home:
        return const FoundationScreen();
      case TutorialStep.projectCard:
        final items = ref
            .watch(publicProposalsProvider)
            .ordinaryItems
            .where(_eligible);
        _projectId = items.isEmpty ? null : items.first.id;
        return const PublicProposalsScreen();
      case TutorialStep.projectPurpose:
      case TutorialStep.projectNeeds:
      case TutorialStep.projectParticipation:
        ref.watch(proposalDetailProvider);
        return _projectId == null
            ? TutorialIllustration(step: _step)
            : ProposalDetailScreen(proposalId: _projectId!);
      case TutorialStep.projectCreate:
      case TutorialStep.projectDrafts:
        return const PublicProposalsScreen();
      case TutorialStep.resourceModes:
      case TutorialStep.resourceCard:
      case TutorialStep.resourceCreate:
      case TutorialStep.resourceDrafts:
        final state = ref.watch(publicResourceListingsProvider);
        _resourceId = state.items.isEmpty ? null : state.items.first.id;
        return const PublicResourceListingsScreen();
      case TutorialStep.messagesTabs:
      case TutorialStep.messagesScopes:
      case TutorialStep.farewell:
        return const MessagesLandingScreen(controlsOnly: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.read(startupFlowProvider);
    if (flow.registry.steps.isEmpty) {
      return TutorialPages(returnTo: widget.returnTo);
    }
    final l = AppLocalizations.of(context);
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      old,
      next,
    ) {
      if (old != next) {
        _generation++;
        _automatic?.cancel();
        _probe?.cancel();
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
          if (!didPop && !_saving) _leave();
        },
        child: Scaffold(
          key: const Key('tutorial-screen'),
          body: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    BackButton(onPressed: _saving ? null : _leave),
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
                  child: Stack(
                    key: _surface,
                    fit: StackFit.expand,
                    children: [
                      ExcludeSemantics(
                        child: IgnorePointer(
                          child: KeyedSubtree(
                            key: ValueKey(
                              'tutorial-surface-${_surfaceGroup()}-$_fallback',
                            ),
                            child: _content(),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: GestureDetector(
                          key: const Key('tutorial-overlay'),
                          behavior: HitTestBehavior.opaque,
                          onTap: restoreFailed || _step == TutorialStep.farewell
                              ? null
                              : _advance,
                          child: CustomPaint(
                            key: const Key('tutorial-spotlight'),
                            painter: TutorialScrim(
                              _target,
                              Colors.black.withValues(alpha: .62),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                    onPressed: _saving
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
