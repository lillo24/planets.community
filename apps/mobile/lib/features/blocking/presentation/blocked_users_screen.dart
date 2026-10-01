import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/blocking_controller.dart';
import '../domain/blocking_models.dart';
import 'blocking_action.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
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
        .read(blockingProvider.notifier)
        .loadList(profileId, refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(blockingProvider);
    final belongs = state.expectedProfileId == _expectedProfileId;
    final items = belongs ? state.blockedProfiles : const <BlockedProfile>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockingBlockedUsersTitle)),
      body: SafeArea(
        child:
            !belongs ||
                (state.listPhase == BlockingListPhase.loading && items.isEmpty)
            ? LoadingState(message: l10n.blockingLoading)
            : state.listPhase == BlockingListPhase.failure && items.isEmpty
            ? ErrorState(message: l10n.blockingLoadError, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  children: [
                    if (items.isEmpty)
                      EmptyState(
                        title: l10n.blockingEmptyTitle,
                        message: l10n.blockingEmptyMessage,
                        icon: Icons.person_off_outlined,
                      )
                    else
                      for (final item in items)
                        Card(
                          key: Key('blocked-user-${item.profileId}'),
                          child: ListTile(
                            title: Text(item.displayName),
                            subtitle: Text(
                              l10n.blockingBlockedOn(
                                DateFormat.yMMMd(
                                  Localizations.localeOf(context).toString(),
                                ).format(item.blockedAt.toLocal()),
                              ),
                            ),
                            trailing: BlockingActionButton(
                              targetProfileId: item.profileId,
                              targetDisplayName: item.displayName,
                              compact: true,
                              buttonKey: Key(
                                'blocked-user-unblock-${item.profileId}',
                              ),
                            ),
                          ),
                        ),
                    if (state.failure != null && items.isNotEmpty)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.blockingLoadError,
                          key: const Key('blocked-users-inline-error'),
                        ),
                      ),
                    if (items.isNotEmpty && state.hasMore)
                      OutlinedButton(
                        key: const Key('blocked-users-load-more'),
                        onPressed:
                            state.listPhase == BlockingListPhase.loadingMore
                            ? null
                            : () => ref
                                  .read(blockingProvider.notifier)
                                  .loadMore(_expectedProfileId!),
                        child: state.listPhase == BlockingListPhase.loadingMore
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.blockingLoadMore),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
