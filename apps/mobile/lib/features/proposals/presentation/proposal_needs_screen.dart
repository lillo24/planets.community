import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/draft_departure_coordinator.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../../project_delegates/domain/project_delegate_models.dart';
import '../../project_resource_needs/presentation/project_resource_needs_screen.dart';
import '../../project_resource_needs/presentation/project_resource_needs_section.dart';
import '../application/proposal_controllers.dart';
import '../application/proposal_skills_controller.dart';
import 'proposal_editor_controls.dart';

/// Composes people skills with the existing, independently authorized materials UI.
class ProposalNeedsScreen extends ConsumerStatefulWidget {
  const ProposalNeedsScreen({required this.projectId, super.key});
  final String projectId;
  @override
  ConsumerState<ProposalNeedsScreen> createState() =>
      _ProposalNeedsScreenState();
}

class _ProposalNeedsScreenState extends ConsumerState<ProposalNeedsScreen>
    with WidgetsBindingObserver {
  late final String? _actor;
  late final DraftDepartureCoordinator _departure;
  DraftDepartureOwner? _owner;

  ProposalSkillsController get _controller =>
      ref.read(proposalSkillsProvider(widget.projectId).notifier);

  @override
  void initState() {
    super.initState();
    _actor = ref.read(authSessionProvider).identity?.id;
    _departure = ref.read(draftDepartureProvider);
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(() {
      if (mounted && _actor != null) _controller.load(_actor);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_owner != null || _actor == null) return;
    _owner = DraftDepartureOwner(
      actorId: _actor,
      pageKey: GoRouterState.of(context).pageKey,
      isActive: () =>
          mounted &&
          TickerMode.valuesOf(context).enabled &&
          (ModalRoute.of(context)?.isCurrent ?? false),
      prepare: _prepareDeparture,
      savedMessage: (context) =>
          AppLocalizations.of(context).proposalSkillsSaved,
    );
    _departure.register(_owner!);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _actor != null) {
      unawaited(_controller.load(_actor));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_owner case final owner?) _departure.unregister(owner);
    super.dispose();
  }

  Future<DraftDepartureOutcome> _prepareDeparture() async {
    final state = ref.read(proposalSkillsProvider(widget.projectId));
    if (!state.dirty) return DraftDepartureOutcome.noChange;
    if (state.busy) return DraftDepartureOutcome.blocked;
    final l = AppLocalizations.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(l.proposalSkillsLeaveTitle),
        content: Text(l.proposalSkillsLeaveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: Text(l.proposalSkillsStay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(l.proposalDraftDiscard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(l.proposalSkillsSave),
          ),
        ],
      ),
    );
    if (!mounted) return DraftDepartureOutcome.blocked;
    if (choice == 'discard') {
      _controller.discard();
      return DraftDepartureOutcome.discarded;
    }
    if (choice == 'save' && await _controller.save()) {
      return DraftDepartureOutcome.saved;
    }
    return DraftDepartureOutcome.blocked;
  }

  Future<void> _reload() async {
    final state = ref.read(proposalSkillsProvider(widget.projectId));
    if (state.dirty) {
      final l = AppLocalizations.of(context);
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(l.proposalSkillsReload),
          content: Text(l.proposalSkillsReloadMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.proposalSkillsStay),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.proposalDraftDiscard),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (_actor != null) await _controller.load(_actor, discardEdits: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(proposalSkillsProvider(widget.projectId));
    final actor = ref.watch(authSessionProvider).identity?.id;
    final identityMatches =
        _actor != null && actor == _actor && state.actorId == _actor;
    final header = _skills(context, state);
    if (!identityMatches ||
        state.failure == ProposalSkillsFailure.forbidden ||
        state.proposal == null) {
      return Scaffold(
        appBar: pageAppBar(context, title: Text(l.proposalNeedsManageTitle)),
        body:
            actor == _actor &&
                (state.busy || (state.actorId == null && state.failure == null))
            ? LoadingState(message: l.proposalLoading)
            : ErrorState(message: l.projectManageUnavailable, onRetry: _reload),
      );
    }
    if (state.role == ProjectManagementRole.creator) {
      return ProjectResourceNeedsScreen(
        projectId: widget.projectId,
        projectKind: ProjectKind.oneTime,
        title: l.proposalNeedsManageTitle,
        header: header,
        onRefresh: _reload,
      );
    }
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l.proposalNeedsManageTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.large),
            children: [
              header,
              const SizedBox(height: AppSpacing.large),
              Semantics(
                header: true,
                child: Text(
                  l.projectResourcesNeededTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                l.proposalResourcesCreatorOnly,
                key: const Key('proposal-materials-creator-only'),
              ),
              ProjectResourceNeedsSection(
                projectId: widget.projectId,
                showHeading: false,
                showEmpty: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skills(BuildContext context, ProposalSkillsState state) {
    final l = AppLocalizations.of(context);
    final enabled = state.editableAt(ref.watch(proposalClockProvider)());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l.proposalSkillsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        ProposalSkillsControl(
          categories: state.categories,
          values: state.edits,
          enabled: enabled,
          onChanged: _controller.change,
        ),
        const SizedBox(height: AppSpacing.medium),
        FilledButton.icon(
          key: const Key('proposal-skills-save'),
          onPressed: enabled && state.dirty
              ? () async {
                  if (await _controller.save() && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.proposalSkillsSaved)),
                    );
                  }
                }
              : null,
          icon: const Icon(Icons.save_outlined),
          label: Text(l.proposalSkillsSave),
        ),
        if (state.busy) const LinearProgressIndicator(),
        if (state.failure != null || state.savedUnverified) ...[
          const SizedBox(height: AppSpacing.small),
          Semantics(
            liveRegion: true,
            child: Text(
              state.savedUnverified
                  ? l.proposalSkillsSavedUnverified
                  : switch (state.failure) {
                      ProposalSkillsFailure.conflict =>
                        l.proposalSkillsConflict,
                      ProposalSkillsFailure.readOnly =>
                        l.proposalSkillsReadOnly,
                      _ => l.proposalSafeError,
                    },
              key: const Key('proposal-skills-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          TextButton(
            key: const Key('proposal-skills-reload'),
            onPressed: state.busy ? null : _reload,
            child: Text(l.proposalSkillsReload),
          ),
        ],
      ],
    );
  }
}
