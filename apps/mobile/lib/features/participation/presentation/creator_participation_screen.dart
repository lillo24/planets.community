import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../blocking/presentation/blocking_action.dart';
import '../../profile_photo/application/visible_profile_photo_controller.dart';
import '../../profile_photo/domain/visible_profile_photo_models.dart';
import '../../profile_photo/presentation/visible_profile_photo_avatar.dart';
import '../../project_delegates/data/project_delegate_gateway.dart';
import '../../project_delegates/domain/project_delegate_models.dart';
import '../../project_participant_invites/presentation/participant_link_management_screen.dart';
import '../application/project_people_controller.dart';
import '../data/project_people_gateway.dart';
import '../data/participation_gateway.dart';
import '../domain/participation_models.dart';
import '../domain/project_people_models.dart';
import 'actual_contribution_sheet.dart';
import 'join_acceptance_triage_sheet.dart';
import 'membership_commitment_sheet.dart';
import 'project_capacity_label.dart';
import 'project_capacity_presentation.dart';
import 'project_person_tile.dart';

/// Legacy route/class name, now the single current-entitled Project People surface.
class CreatorParticipationScreen extends ConsumerStatefulWidget {
  const CreatorParticipationScreen({
    required this.projectId,
    required this.projectKind,
    super.key,
  });
  final String projectId;
  final ProjectKind projectKind;
  @override
  ConsumerState<CreatorParticipationScreen> createState() =>
      _CreatorParticipationScreenState();
}

class _CreatorParticipationScreenState
    extends ConsumerState<CreatorParticipationScreen> {
  late final String? _expectedProfileId;
  @override
  void initState() {
    super.initState();
    _expectedProfileId = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_load);
  }

  bool get _identityMatches =>
      mounted &&
      _expectedProfileId != null &&
      ref.read(authSessionProvider).identity?.id == _expectedProfileId;
  Future<void> _load() async {
    if (!_identityMatches) return;
    await ref
        .read(projectPeopleProvider.notifier)
        .load(_expectedProfileId!, widget.projectId);
  }

  String _role(AppLocalizations l10n, ProjectDelegatedAuthorityRole role) =>
      role == ProjectDelegatedAuthorityRole.coCreator
      ? l10n.peopleCoCreator
      : l10n.peopleCoOrganizer;
  String _error(AppLocalizations l10n, PeopleFailure failure) =>
      switch (failure) {
        PeopleFailure.forbidden => l10n.peopleForbidden,
        PeopleFailure.capacity => l10n.peopleCapacityConflict,
        PeopleFailure.conflict => l10n.peopleConflict,
        PeopleFailure.unavailable => l10n.peopleUnavailable,
      };
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider);
    final state = ref.watch(projectPeopleProvider);
    final belongs =
        session.identity?.id == _expectedProfileId &&
        state.profileId == _expectedProfileId &&
        state.projectId == widget.projectId;
    if (!belongs) {
      return Scaffold(
        appBar: pageAppBar(context, title: Text(l10n.peopleTitle)),
        body: Center(
          child: session.identity?.id != _expectedProfileId
              ? Text(l10n.peopleForbidden)
              : const CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(l10n.peopleTitle),
        actions: [
          if (state.role.isManager)
            ParticipantLinkManagementButton(
              projectId: widget.projectId,
              kind: widget.projectKind,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (state.loading || state.mutating)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
            if (state.failure != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Column(
                    children: [
                      Text(
                        _error(l10n, state.failure!),
                        key: const Key('creator-participation-error'),
                      ),
                      TextButton(
                        onPressed: state.loading || state.mutating
                            ? null
                            : _load,
                        child: Text(l10n.retryAction),
                      ),
                    ],
                  ),
                ),
              ),
            if (state.capacity case final capacity?)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Card(
                    key: const Key('creator-participation-capacity'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      child: Column(
                        children: [
                          ProjectCapacityLabel(
                            capacity: capacity,
                            presentation:
                                ProjectCapacityPresentation.managerExact,
                          ),
                          if (capacity.registrationCapacity
                              case final registration?)
                            Text(
                              l10n.projectCapacityManagerSummary(
                                capacity.currentParticipantCount,
                                capacity.organizerCount,
                                capacity.capacityUsedCount,
                                registration,
                              ),
                            ),
                          if (capacity.spotsRemaining case final remaining?)
                            Text(l10n.projectCapacityRemaining(remaining)),
                          if (capacity.isFull) Text(l10n.projectNoSpots),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (state.role.isManager) ...[
              _heading(l10n.participationRequests),
              SliverList.builder(
                itemCount: state.requests.items.length,
                itemBuilder: (context, index) {
                  final request = state.requests.items[index];
                  return _RequestCard(
                    request: request,
                    photoEntry: request.isPending
                        ? ref
                              .watch(visibleProfilePhotoProvider)
                              .entryFor(request.requesterProfileId)
                        : null,
                    enabled: !state.loading && !state.mutating,
                    acceptEnabled:
                        !state.loading &&
                        !state.mutating &&
                        (state.capacity?.isFull != true ||
                            request.requesterIsOrganizer),
                    isActing: false,
                    onAccept: () => _accept(request),
                    onReject: () => _mutate(
                      (profileId, projectId) => ref
                          .read(participationGatewayProvider)
                          .rejectRequest(
                            expectedManagerProfileId: profileId,
                            requestId: request.id,
                          ),
                    ),
                    onBlockingChanged: _load,
                  );
                },
              ),
              _pageFooter(
                state.requests,
                PeopleSection.requests,
                l10n.participationNoRequests,
              ),
            ],
            _heading(l10n.peopleOffers),
            SliverList.builder(
              itemCount: state.offers.items.length,
              itemBuilder: (context, index) =>
                  _offerCard(state.offers.items[index], state),
            ),
            _pageFooter(
              state.offers,
              PeopleSection.offers,
              l10n.peopleNoOffers,
            ),
            _heading(l10n.peopleTitle),
            SliverList.builder(
              itemCount: state.people.items.length,
              itemBuilder: (context, index) {
                final person = state.people.items[index];
                return KeyedSubtree(
                  key: person.membershipId == null
                      ? null
                      : Key('participation-member-${person.membershipId}'),
                  child: ProjectPersonTile(
                    person: person,
                    actionsLabel: l10n.peopleActions,
                    roleLabels: [
                      if (person.isCreator) l10n.peopleCreator,
                      if (person.authorityRole case final role?)
                        _role(l10n, role),
                      if (person.isParticipant) l10n.peopleParticipant,
                    ],
                    onActions: state.loading || state.mutating
                        ? null
                        : () => _memberActions(person, state.role),
                  ),
                );
              },
            ),
            _pageFooter(
              state.people,
              PeopleSection.people,
              l10n.participationNoParticipants,
            ),
            if (state.role.isManager) ...[
              _heading(l10n.peoplePastParticipants),
              SliverList.builder(
                itemCount: state.history.items.length,
                itemBuilder: (context, index) {
                  final member = state.history.items[index];
                  return ListTile(
                    key: Key('participation-member-${member.id}'),
                    title: Text(member.participantDisplayName),
                    subtitle: Text(
                      '${_membershipStatusLabel(l10n, member.status)} · ${_formatDate(context, member.joinedAt)}',
                    ),
                    onLongPress: () => _historyActions(member),
                    trailing: IconButton(
                      key: Key('people-history-actions-${member.id}'),
                      tooltip: l10n.peopleActions,
                      onPressed: () => _historyActions(member),
                      icon: const Icon(Icons.more_horiz),
                    ),
                  );
                },
              ),
              _pageFooter(
                state.history,
                PeopleSection.history,
                l10n.participationNoParticipants,
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Text(l10n.peopleNameVisibility),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String title) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
  Widget _pageFooter<T>(
    PeoplePage<T> page,
    PeopleSection section,
    String empty,
  ) {
    final l10n = AppLocalizations.of(context);
    return SliverToBoxAdapter(
      child: Column(
        children: [
          if (page.loading) const LinearProgressIndicator(),
          if (page.failure case final failure?)
            Text(
              _error(l10n, failure),
              key: Key('people-page-error-${section.name}'),
            ),
          if (!page.loading && page.items.isEmpty && page.failure == null)
            Text(empty),
          if (!page.loading && page.hasMore && page.failure != null)
            TextButton(
              key: Key('people-retry-${section.name}'),
              onPressed: () => _more(section),
              child: Text(l10n.retryAction),
            )
          else if (!page.loading && page.hasMore && page.items.isNotEmpty)
            TextButton(
              key: Key('people-more-${section.name}'),
              onPressed: () => _more(section),
              child: Text(l10n.peopleLoadMore),
            ),
        ],
      ),
    );
  }

  Future<void> _more(PeopleSection section) async {
    if (_identityMatches) {
      await ref.read(projectPeopleProvider.notifier).loadMore(section);
    }
  }

  Widget _offerCard(ProjectRoleOffer offer, ProjectPeopleState state) {
    final l10n = AppLocalizations.of(context);
    final own = offer.targetProfileId == _expectedProfileId;
    return Card(
      key: Key('people-offer-${offer.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.peopleOfferDescription(
                offer.issuerDisplayName,
                offer.targetDisplayName,
                _role(l10n, offer.role),
              ),
            ),
            Text(
              l10n.projectDelegateInviteDates(
                _formatDate(context, offer.createdAt),
                _formatDate(context, offer.expiresAt),
              ),
            ),
            if (offer.role == ProjectDelegatedAuthorityRole.coCreator)
              Text(l10n.peopleCoCreatorWarning),
            Wrap(
              children: [
                if (own) ...[
                  TextButton(
                    key: Key('people-offer-decline-${offer.id}'),
                    onPressed: state.mutating || state.loading
                        ? null
                        : () => _mutate(
                            (profileId, projectId) => ref
                                .read(projectPeopleGatewayProvider)
                                .respond(profileId, offer.id, accept: false),
                          ),
                    child: Text(l10n.peopleDeclineOffer),
                  ),
                  FilledButton(
                    key: Key('people-offer-accept-${offer.id}'),
                    onPressed: state.mutating || state.loading
                        ? null
                        : () => _acceptOffer(offer),
                    child: Text(l10n.peopleAcceptOffer),
                  ),
                ] else if (state.role.hasStructuralAuthority)
                  TextButton(
                    key: Key('people-offer-withdraw-${offer.id}'),
                    onPressed: state.mutating || state.loading
                        ? null
                        : () => _withdrawOffer(offer),
                    child: Text(l10n.peopleWithdrawOffer),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(ManagerProjectJoinRequest request) async {
    if (!_identityMatches) return;
    await showJoinAcceptanceTriageSheet(
      context,
      expectedManagerProfileId: _expectedProfileId!,
      requestId: request.id,
      projectId: widget.projectId,
      projectKind: widget.projectKind,
      requesterDisplayName: request.requesterDisplayName,
    );
    await _load();
  }

  Future<void> _mutate(Future<void> Function(String, String) operation) async {
    if (_identityMatches) {
      await ref.read(projectPeopleProvider.notifier).mutate(operation);
      if (mounted && _identityMatches) {
        final failure = ref.read(projectPeopleProvider).failure;
        if (failure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_error(AppLocalizations.of(context), failure)),
            ),
          );
        }
      }
    }
  }

  Future<bool> _confirm(
    String title,
    String message, {
    Key? confirmationKey,
    String? confirmLabel,
  }) async {
    if (!_identityMatches) return false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _IdentityBoundOverlay(
        expectedProfileId: _expectedProfileId!,
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppLocalizations.of(dialogContext).participationKeep),
            ),
            FilledButton(
              key: confirmationKey ?? const Key('people-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel ?? title),
            ),
          ],
        ),
      ),
    );
    return accepted == true && _identityMatches;
  }

  Future<void> _acceptOffer(ProjectRoleOffer offer) async {
    final l10n = AppLocalizations.of(context);
    if (await _confirm(
      l10n.peopleAcceptOffer,
      l10n.peopleOfferHelp +
          (offer.role == ProjectDelegatedAuthorityRole.coCreator
              ? '\n${l10n.peopleCoCreatorWarning}'
              : ''),
    )) {
      await _mutate(
        (profileId, projectId) => ref
            .read(projectPeopleGatewayProvider)
            .respond(profileId, offer.id, accept: true),
      );
    }
  }

  Future<void> _withdrawOffer(ProjectRoleOffer offer) async {
    final l10n = AppLocalizations.of(context);
    if (await _confirm(l10n.peopleWithdrawOffer, l10n.peopleWithdrawOffer)) {
      await _mutate(
        (profileId, projectId) => ref
            .read(projectDelegateGatewayProvider)
            .revokeInvitation(
              expectedStructuralActorId: profileId,
              invitationId: offer.id,
            ),
      );
    }
  }

  Future<void> _memberActions(
    ProjectPerson person,
    ProjectManagementRole viewer,
  ) async {
    if (!_identityMatches) return;
    final l10n = AppLocalizations.of(context);
    final actions = projectPersonActions(person, viewer, _expectedProfileId!);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => _IdentityBoundOverlay(
        expectedProfileId: _expectedProfileId,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  person.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (person.profileId != _expectedProfileId) ...[
                  Text(
                    l10n.peopleSafety,
                    key: const Key('people-safety-section'),
                  ),
                  Text(l10n.peopleSafetyHelp),
                  BlockingActionButton(
                    key: Key(
                      'participation-member-block-${person.membershipId ?? person.profileId}',
                    ),
                    targetProfileId: person.profileId,
                    targetDisplayName: person.displayName,
                    consequence: BlockingContextConsequence.projectMember,
                    onChanged: (_) => _load(),
                  ),
                ],
                if (actions.isNotEmpty)
                  Text(
                    l10n.peopleEvent,
                    key: const Key('people-event-section'),
                  ),
                for (final action in actions)
                  if (action != PeopleAction.actualContributions ||
                      widget.projectKind == ProjectKind.oneTime)
                    ListTile(
                      key: switch (action) {
                        PeopleAction.commitments => Key(
                          'participation-commitments-${person.membershipId}',
                        ),
                        PeopleAction.actualContributions => Key(
                          'participation-actual-contributions-${person.membershipId}',
                        ),
                        PeopleAction.removeParticipant => Key(
                          'participation-remove-${person.membershipId}',
                        ),
                        _ => Key('people-action-${action.name}'),
                      },
                      title: Text(_actionLabel(l10n, action)),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _personAction(person, action, viewer);
                      },
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _actionLabel(AppLocalizations l10n, PeopleAction action) =>
      switch (action) {
        PeopleAction.commitments => l10n.participationCommitments,
        PeopleAction.actualContributions => l10n.actualContributionsAction,
        PeopleAction.removeParticipant => l10n.participationRemove,
        PeopleAction.inviteCoOrganizer => l10n.peopleInviteCoOrganizer,
        PeopleAction.inviteCoCreator => l10n.peopleInviteCoCreator,
        PeopleAction.makeCoOrganizer => l10n.projectDelegateDemoteAction,
        PeopleAction.makeCoCreator => l10n.projectDelegatePromoteAction,
        PeopleAction.revokeAuthority => l10n.projectDelegateRemoveAction,
        PeopleAction.stepDown => l10n.peopleStepDown,
      };
  Future<void> _personAction(
    ProjectPerson person,
    PeopleAction action,
    ProjectManagementRole viewer,
  ) async {
    if (!_identityMatches) return;
    final l10n = AppLocalizations.of(context);
    if (action == PeopleAction.commitments) {
      await showMembershipCommitmentSheet(
        context,
        expectedProfileId: _expectedProfileId!,
        membershipId: person.membershipId!,
        editable: true,
        historical: false,
      );
      return;
    }
    if (action == PeopleAction.actualContributions) {
      await showActualContributionSheet(
        context,
        expectedProfileId: _expectedProfileId!,
        membershipId: person.membershipId!,
        editable: viewer.isManager,
        participantDisplayName: person.displayName,
      );
      return;
    }
    final message = switch (action) {
      PeopleAction.removeParticipant => l10n.peopleRemoveHelp,
      PeopleAction.stepDown => l10n.peopleStepDownHelp,
      PeopleAction.inviteCoCreator =>
        '${l10n.peopleOfferHelp}\n${l10n.peopleCoCreatorWarning}',
      PeopleAction.inviteCoOrganizer => l10n.peopleOfferHelp,
      PeopleAction.makeCoCreator => l10n.projectDelegatePromoteConfirmMessage,
      PeopleAction.makeCoOrganizer => l10n.projectDelegateDemoteConfirmMessage,
      PeopleAction.revokeAuthority =>
        person.authorityRole == ProjectDelegatedAuthorityRole.coCreator
            ? l10n.projectDelegateRemoveCocreatorConfirmMessage
            : l10n.projectDelegateRemoveConfirmMessage,
      _ => throw StateError('Unsupported member mutation.'),
    };
    if (!await _confirm(
      action == PeopleAction.removeParticipant
          ? l10n.participationRemoveConfirmTitle(person.displayName)
          : _actionLabel(l10n, action),
      message,
      confirmationKey: action == PeopleAction.removeParticipant
          ? const Key('participation-confirm-remove')
          : null,
      confirmLabel: _actionLabel(l10n, action),
    )) {
      return;
    }
    await _mutate((profileId, projectId) async {
      switch (action) {
        case PeopleAction.removeParticipant:
          await ref
              .read(participationGatewayProvider)
              .removeMember(
                expectedManagerProfileId: profileId,
                membershipId: person.membershipId!,
              );
        case PeopleAction.stepDown:
          await ref
              .read(projectPeopleGatewayProvider)
              .stepDown(profileId, person.delegateId!);
        case PeopleAction.inviteCoOrganizer || PeopleAction.inviteCoCreator:
          await ref
              .read(projectPeopleGatewayProvider)
              .offer(
                profileId,
                projectId,
                person.membershipId!,
                action == PeopleAction.inviteCoCreator
                    ? ProjectDelegatedAuthorityRole.coCreator
                    : ProjectDelegatedAuthorityRole.coOrganizer,
              );
        case PeopleAction.makeCoCreator || PeopleAction.makeCoOrganizer:
          await ref
              .read(projectDelegateGatewayProvider)
              .changeDelegateRole(
                expectedStructuralActorId: profileId,
                delegateId: person.delegateId!,
                authorityRole: action == PeopleAction.makeCoCreator
                    ? ProjectDelegatedAuthorityRole.coCreator
                    : ProjectDelegatedAuthorityRole.coOrganizer,
              );
        case PeopleAction.revokeAuthority:
          await ref
              .read(projectDelegateGatewayProvider)
              .revokeDelegate(
                expectedStructuralActorId: profileId,
                delegateId: person.delegateId!,
              );
        default:
          throw StateError('Unsupported member mutation.');
      }
    });
  }

  Future<void> _historyActions(ManagerProjectMember member) async {
    if (!_identityMatches) return;
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => _IdentityBoundOverlay(
        expectedProfileId: _expectedProfileId!,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(member.participantDisplayName)),
              if (member.participantProfileId != _expectedProfileId) ...[
                Text(l10n.peopleSafety),
                Text(l10n.peopleSafetyHelp),
                BlockingActionButton(
                  key: Key('participation-member-block-${member.id}'),
                  targetProfileId: member.participantProfileId,
                  targetDisplayName: member.participantDisplayName,
                  consequence: BlockingContextConsequence.projectMember,
                  onChanged: (_) => _load(),
                ),
              ],
              Text(l10n.peopleEvent),
              ListTile(
                key: Key('participation-commitments-${member.id}'),
                title: Text(l10n.participationViewCommitments),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (_identityMatches) {
                    showMembershipCommitmentSheet(
                      context,
                      expectedProfileId: _expectedProfileId,
                      membershipId: member.id,
                      editable: false,
                      historical: true,
                    );
                  }
                },
              ),
              if (widget.projectKind == ProjectKind.oneTime)
                ListTile(
                  key: Key('participation-actual-contributions-${member.id}'),
                  title: Text(l10n.actualContributionsAction),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    if (_identityMatches) {
                      showActualContributionSheet(
                        context,
                        expectedProfileId: _expectedProfileId,
                        membershipId: member.id,
                        editable: true,
                        participantDisplayName: member.participantDisplayName,
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityBoundOverlay extends ConsumerWidget {
  const _IdentityBoundOverlay({
    required this.expectedProfileId,
    required this.child,
  });
  final String expectedProfileId;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    if (session.identity?.id != expectedProfileId ||
        session.phase != AuthSessionPhase.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }
    return child;
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.photoEntry,
    required this.enabled,
    required this.acceptEnabled,
    required this.isActing,
    required this.onAccept,
    required this.onReject,
    required this.onBlockingChanged,
  });

  final ManagerProjectJoinRequest request;
  final VisibleProfilePhotoEntry? photoEntry;
  final bool enabled;
  final bool acceptEnabled;
  final bool isActing;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final Future<void> Function() onBlockingChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      key: Key('participation-request-${request.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                VisibleProfilePhotoAvatar(
                  entry: photoEntry,
                  imageSemanticsLabel: l10n.profilePhotoApplicantAvatarLabel,
                  placeholderSemanticsLabel:
                      l10n.profilePhotoApplicantAvatarLabel,
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Text(
                    request.requesterDisplayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                BlockingActionButton(
                  targetProfileId: request.requesterProfileId,
                  targetDisplayName: request.requesterDisplayName,
                  consequence: request.isPending
                      ? BlockingContextConsequence.pendingRequest
                      : BlockingContextConsequence.none,
                  buttonKey: Key('participation-block-${request.id}'),
                  compact: true,
                  onChanged: (_) => onBlockingChanged(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(_requestStatusLabel(l10n, request.status)),
            Text(
              l10n.participationRequestedAt(
                _formatDate(context, request.createdAt),
              ),
            ),
            if (request.message case final message?) ...[
              const SizedBox(height: AppSpacing.small),
              Text(
                message,
                key: Key('participation-request-message-${request.id}'),
              ),
            ],
            if (request.isPending) ...[
              const SizedBox(height: AppSpacing.medium),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: Key('participation-reject-${request.id}'),
                      onPressed: enabled ? onReject : null,
                      child: Text(l10n.participationReject),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: FilledButton(
                      key: Key('participation-accept-${request.id}'),
                      onPressed: acceptEnabled ? onAccept : null,
                      child: isActing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.participationAccept),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _requestStatusLabel(AppLocalizations l10n, JoinRequestStatus status) =>
    switch (status) {
      JoinRequestStatus.pending => l10n.participationStatusPending,
      JoinRequestStatus.accepted => l10n.participationStatusAccepted,
      JoinRequestStatus.rejected => l10n.participationStatusRejected,
      JoinRequestStatus.withdrawn => l10n.participationStatusWithdrawn,
    };

String _membershipStatusLabel(AppLocalizations l10n, MembershipStatus status) =>
    switch (status) {
      MembershipStatus.current => l10n.participationStatusCurrent,
      MembershipStatus.left => l10n.participationStatusLeft,
      MembershipStatus.removed => l10n.participationStatusRemoved,
    };

String _formatDate(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .add_jm()
        .format(value.toLocal());
