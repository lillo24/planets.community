import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../messages/presentation/messages_routes.dart';
import '../../profile_photo/application/visible_profile_photo_controller.dart';
import '../../profile_photo/presentation/visible_profile_photo_avatar.dart';
import '../../resource_listings/domain/resource_listing_models.dart';
import '../../resource_listings/presentation/resource_listing_widgets.dart';
import '../application/resource_request_controllers.dart';
import '../domain/resource_request_models.dart';
import 'resource_request_widgets.dart';

class ResourceRequestScreen extends ConsumerStatefulWidget {
  const ResourceRequestScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<ResourceRequestScreen> createState() =>
      _ResourceRequestScreenState();
}

class _ResourceRequestScreenState extends ConsumerState<ResourceRequestScreen> {
  late final String? _expectedProfileId;

  @override
  void initState() {
    super.initState();
    _expectedProfileId = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final profileId = _expectedProfileId;
    if (profileId == null ||
        ref.read(authSessionProvider).identity?.id != profileId) {
      return;
    }
    await ref
        .read(resourceRequestDetailProvider(widget.requestId).notifier)
        .load(profileId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(resourceRequestDetailProvider(widget.requestId));
    final belongs = state.expectedProfileId == _expectedProfileId;
    final item = belongs ? state.item : null;
    final showRequesterPhoto =
        item != null &&
        item.ownerProfileId == _expectedProfileId &&
        (item.status == ResourceRequestStatus.pending ||
            (item.status == ResourceRequestStatus.accepted &&
                item.coordinationClosedAt == null));
    final requesterPhoto = item == null
        ? null
        : ref
              .watch(visibleProfilePhotoProvider)
              .entryFor(item.requesterProfileId);
    final initialLoading =
        !belongs ||
        (state.phase == ResourceRequestDetailPhase.loading && item == null);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resourceRequestDetailTitle)),
      body: SafeArea(
        child: initialLoading
            ? LoadingState(message: l10n.resourceRequestLoading)
            : item == null
            ? ErrorState(
                message: resourceRequestFailureMessage(
                  l10n,
                  state.failure,
                  loading: true,
                ),
                onRetry: _load,
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  children: [
                    if (state.failure case final failure?) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          resourceRequestFailureMessage(
                            l10n,
                            failure,
                            loading: false,
                          ),
                          key: const Key('resource-request-detail-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                    Text(
                      item.listingTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Wrap(
                      spacing: AppSpacing.small,
                      runSpacing: AppSpacing.small,
                      children: [
                        ResourceRequestStatusChip(status: item.status),
                        ResourceListingModeBadge(mode: item.listingMode),
                        if (item.listingLifecycle ==
                            ResourceListingLifecycle.closed)
                          ResourceListingLifecycleBadge(
                            lifecycle: item.listingLifecycle,
                          ),
                      ],
                    ),
                    if (item.status == ResourceRequestStatus.accepted) ...[
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        item.coordinationClosedAt == null
                            ? l10n.resourceRequestCoordinationOpen
                            : l10n.resourceRequestCoordinationFinished,
                        key: const Key('resource-request-coordination-state'),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.large),
                    _DetailSection(
                      title: l10n.resourceRequestPeopleLabel,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (showRequesterPhoto)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppSpacing.small,
                                  ),
                                  child: VisibleProfilePhotoAvatar(
                                    key: const Key(
                                      'resource-request-requester-photo',
                                    ),
                                    entry: requesterPhoto,
                                    imageSemanticsLabel:
                                        l10n.resourceRequestRequesterPhotoLabel,
                                    placeholderSemanticsLabel:
                                        l10n.resourceRequestRequesterPhotoLabel,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  l10n.resourceRequestRequesterLabel(
                                    item.requesterDisplayName,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            l10n.resourceRequestOwnerLabel(
                              item.ownerDisplayName,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.requestMessage case final message?)
                      _DetailSection(
                        title: l10n.resourceRequestMessageLabel,
                        child: SelectableText(
                          message,
                          key: const Key('resource-request-detail-message'),
                        ),
                      ),
                    _DetailSection(
                      title: l10n.resourceRequestTimelineLabel,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.resourceRequestRequestedAt(
                              formatResourceRequestDate(
                                context,
                                item.createdAt,
                              ),
                            ),
                          ),
                          if (item.resolvedAt case final resolvedAt?)
                            Text(
                              l10n.resourceRequestResolvedAt(
                                formatResourceRequestDate(context, resolvedAt),
                              ),
                            ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('resource-request-view-listing'),
                      onPressed: () => context.go(
                        '/resources/${Uri.encodeComponent(item.listingId)}',
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.resourceViewListing),
                    ),
                    if (item.status == ResourceRequestStatus.accepted &&
                        item.chatId != null) ...[
                      const SizedBox(height: AppSpacing.medium),
                      FilledButton.icon(
                        key: const Key('resource-request-open-conversation'),
                        onPressed: () =>
                            context.push(resourceChatRoute(item.chatId!)),
                        icon: const Icon(Icons.forum_outlined),
                        label: Text(l10n.resourceRequestOpenConversation),
                      ),
                    ],
                    if (item.status == ResourceRequestStatus.pending) ...[
                      const SizedBox(height: AppSpacing.medium),
                      _Actions(
                        item: item,
                        expectedProfileId: _expectedProfileId!,
                        state: state,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.large),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xSmall),
        child,
      ],
    ),
  );
}

class _Actions extends ConsumerWidget {
  const _Actions({
    required this.item,
    required this.expectedProfileId,
    required this.state,
  });

  final ResourceRequest item;
  final String expectedProfileId;
  final ResourceRequestDetailState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      resourceRequestDetailProvider(item.id).notifier,
    );
    final role = item.viewerRoleFor(expectedProfileId);
    if (role == ResourceRequestViewerRole.requester) {
      return OutlinedButton.icon(
        key: const Key('resource-request-withdraw'),
        onPressed: state.isActing
            ? null
            : () => controller.withdraw(expectedProfileId),
        icon: state.action == ResourceRequestMutation.withdrawing
            ? const _ActionProgress()
            : const Icon(Icons.undo),
        label: Text(l10n.resourceRequestWithdraw),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('resource-request-reject'),
            onPressed: state.isActing
                ? null
                : () => controller.reject(expectedProfileId),
            child: state.action == ResourceRequestMutation.rejecting
                ? const _ActionProgress()
                : Text(l10n.resourceRequestReject),
          ),
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: FilledButton(
            key: const Key('resource-request-accept'),
            onPressed: state.isActing
                ? null
                : () => controller.accept(expectedProfileId),
            child: state.action == ResourceRequestMutation.accepting
                ? const _ActionProgress()
                : Text(l10n.resourceRequestAccept),
          ),
        ),
      ],
    );
  }
}

class _ActionProgress extends StatelessWidget {
  const _ActionProgress();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
