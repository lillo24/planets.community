import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../cover_media/presentation/project_cover_image.dart';
import '../../participation/domain/participation_models.dart';
import '../../profile_photo/presentation/profile_photo_trust_gate.dart';
import '../../project_resource_needs/presentation/project_resource_need_routes.dart';
import '../application/recurring_activity_controllers.dart';
import '../domain/recurring_activity_models.dart';
import 'recurring_activity_widgets.dart';

class OwnRecurringActivitiesScreen extends ConsumerStatefulWidget {
  const OwnRecurringActivitiesScreen({super.key});

  @override
  ConsumerState<OwnRecurringActivitiesScreen> createState() =>
      _OwnRecurringActivitiesScreenState();
}

class _OwnRecurringActivitiesScreenState
    extends ConsumerState<OwnRecurringActivitiesScreen> {
  String? _requestedIdentity;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final identity = ref.read(authSessionProvider).identity;
    if (identity != null && _requestedIdentity != identity.id) {
      _requestedIdentity = identity.id;
      await ref.read(ownRecurringActivitiesProvider.notifier).load(identity.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final identity = ref.watch(authSessionProvider).identity;
    final state = ref.watch(ownRecurringActivitiesProvider);
    final items = state.expectedCreatorId == identity?.id
        ? state.items
        : const <OwnRecurringActivity>[];
    if (identity != null && _requestedIdentity != identity.id) {
      Future<void>.microtask(_load);
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tavoliMyTitle)),
      body: SafeArea(
        child: identity == null
            ? const SizedBox.shrink()
            : items.isEmpty && state.phase == RecurringActivityLoadPhase.loading
            ? LoadingState(message: l10n.tavoliLoading)
            : items.isEmpty && state.phase == RecurringActivityLoadPhase.failure
            ? ErrorState(message: l10n.tavoliSafeError, onRetry: _load)
            : items.isEmpty
            ? EmptyState(
                title: l10n.tavoliMyEmpty,
                message: l10n.tavoliMyEmptyMessage,
              )
            : RefreshIndicator(
                onRefresh: () => ref
                    .read(ownRecurringActivitiesProvider.notifier)
                    .load(identity.id),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.small),
                  itemBuilder: (context, index) => _OwnTavoloCard(
                    activity: items[index],
                    identityId: identity.id,
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('my-tavoli-create-action'),
        onPressed: () => context.push('/tavoli/create'),
        icon: const Icon(Icons.add),
        label: Text(l10n.tavoliCreateTitle),
      ),
    );
  }
}

class _OwnTavoloCard extends ConsumerWidget {
  const _OwnTavoloCard({required this.activity, required this.identityId});
  final OwnRecurringActivity activity;
  final String identityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(recurringActivityClockProvider)();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProjectCoverImage(
            key: Key('own-tavolo-cover-${activity.id}'),
            title: activity.title?.trim().isNotEmpty == true
                ? activity.title!
                : l10n.tavoliLifecycleDraft,
            objectPath: activity.coverObjectPath,
            ownerProfileId: identityId,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title?.trim().isNotEmpty == true
                      ? activity.title!
                      : l10n.tavoliLifecycleDraft,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xSmall),
                RecurringLifecycleBadge(lifecycle: activity.lifecycle),
                if (activity.currentSchedule case final schedule?) ...[
                  Text(formatRecurringSchedule(schedule, context)),
                  if (schedule.isPendingAt(now))
                    Text(
                      l10n.tavoliPendingSchedule(
                        DateFormat.yMMMd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).format(schedule.effectiveFrom),
                      ),
                      key: Key('tavoli-pending-${activity.id}'),
                    ),
                ],
                if (activity.exactMeetingText case final exact?) ...[
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(exact, key: Key('own-tavoli-exact-${activity.id}')),
                ],
                if (activity.lifecycle == RecurringActivityLifecycle.ended)
                  Text(l10n.tavoliEndedReadOnly),
                const SizedBox(height: AppSpacing.medium),
                Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: AppSpacing.xSmall,
                  children: [
                    OutlinedButton.icon(
                      key: Key('tavoli-resources-${activity.id}'),
                      onPressed: () => context.push(
                        ProjectResourceNeedRoutes.manage(
                          ProjectKind.recurring,
                          activity.id,
                        ),
                      ),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text(l10n.projectResourcesManage),
                    ),
                    if (activity.lifecycle != RecurringActivityLifecycle.draft)
                      OutlinedButton(
                        key: Key('tavoli-view-${activity.id}'),
                        onPressed: () => context.push('/tavoli/${activity.id}'),
                        child: Text(l10n.tavoliView),
                      ),
                    if (activity.isEditable)
                      OutlinedButton(
                        key: Key('tavoli-edit-${activity.id}'),
                        onPressed: () =>
                            context.push('/tavoli/${activity.id}/edit'),
                        child: Text(l10n.tavoliEdit),
                      ),
                    if (activity.canPublish)
                      FilledButton(
                        key: Key('tavoli-publish-${activity.id}'),
                        onPressed: () => _run(
                          context,
                          ref,
                          (controller) =>
                              controller.publish(identityId, activity.id),
                          requirePhoto: true,
                        ),
                        child: Text(l10n.tavoliPublish),
                      ),
                    if (activity.canPause)
                      TextButton(
                        key: Key('tavoli-pause-${activity.id}'),
                        onPressed: () => _confirmPause(context, ref),
                        child: Text(l10n.tavoliPause),
                      ),
                    if (activity.canResume)
                      FilledButton.tonal(
                        key: Key('tavoli-resume-${activity.id}'),
                        onPressed: () => _run(
                          context,
                          ref,
                          (controller) =>
                              controller.resume(identityId, activity.id),
                        ),
                        child: Text(l10n.tavoliResume),
                      ),
                    if (activity.canEnd)
                      TextButton(
                        key: Key('tavoli-end-${activity.id}'),
                        onPressed: () => _confirmEnd(context, ref),
                        child: Text(l10n.tavoliEnd),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function(OwnRecurringActivitiesController controller)
    operation, {
    bool requirePhoto = false,
  }) async {
    if (requirePhoto &&
        !await requireProfilePhotoForTrustAction(
          context: context,
          ref: ref,
          expectedProfileId: identityId,
          reason: ProfilePhotoTrustReason.publishPersonalActivity,
        )) {
      return;
    }
    if (!context.mounted) return;
    final ok = await operation(
      ref.read(ownRecurringActivitiesProvider.notifier),
    );
    if (!ok && context.mounted) {
      if (requirePhoto &&
          ref.read(ownRecurringActivitiesProvider).failure ==
              RecurringActivityFailureKind.profilePhotoRequired) {
        await showProfilePhotoTrustGate(
          context: context,
          reason: ProfilePhotoTrustReason.publishPersonalActivity,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tavoliSafeError)),
      );
    }
  }

  Future<void> _confirmPause(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      context,
      title: l10n.tavoliPauseConfirmTitle,
      message: l10n.tavoliPauseConfirmMessage,
      action: l10n.tavoliPause,
    );
    if (confirmed) {
      if (!context.mounted) return;
      await _run(
        context,
        ref,
        (controller) => controller.pause(identityId, activity.id),
      );
    }
  }

  Future<void> _confirmEnd(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      context,
      title: l10n.tavoliEndConfirmTitle,
      message: l10n.tavoliEndConfirmMessage,
      action: l10n.tavoliEnd,
    );
    if (confirmed) {
      if (!context.mounted) return;
      await _run(
        context,
        ref,
        (controller) => controller.end(identityId, activity.id),
      );
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.tavoliKeep),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }
}
