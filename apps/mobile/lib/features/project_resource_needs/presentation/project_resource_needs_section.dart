import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/project_resource_needs_controllers.dart';

class ProjectResourceNeedsSection extends ConsumerStatefulWidget {
  const ProjectResourceNeedsSection({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<ProjectResourceNeedsSection> createState() =>
      _ProjectResourceNeedsSectionState();
}

class _ProjectResourceNeedsSectionState
    extends ConsumerState<ProjectResourceNeedsSection> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    // A lazy detail section can leave the viewport before its microtask runs.
    if (!mounted) return;
    await ref
        .read(publicProjectResourceNeedsProvider(widget.projectId).notifier)
        .load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(
      publicProjectResourceNeedsProvider(widget.projectId),
    );
    if (state.phase == PublicProjectResourceNeedsPhase.ready &&
        state.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      key: Key('project-resource-needs-${widget.projectId}'),
      padding: const EdgeInsets.only(top: AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.projectResourcesNeededTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(l10n.projectResourcesHint),
          const SizedBox(height: AppSpacing.small),
          if (state.phase == PublicProjectResourceNeedsPhase.loading &&
              state.items.isEmpty)
            Row(
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(child: Text(l10n.projectResourcesLoading)),
              ],
            )
          else if (state.phase == PublicProjectResourceNeedsPhase.failure &&
              state.items.isEmpty)
            _ResourceNeedsFailure(onRetry: _load)
          else ...[
            Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: [
                for (final need in state.items)
                  Chip(
                    key: Key('public-resource-need-${need.id}'),
                    avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text(need.title),
                  ),
              ],
            ),
            for (final need in state.items)
              if (need.details case final details?)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xSmall),
                  child: Text(
                    '${need.title}: $details',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            if (state.failure != null) ...[
              const SizedBox(height: AppSpacing.small),
              _ResourceNeedsFailure(onRetry: _load),
            ],
          ],
        ],
      ),
    );
  }
}

class _ResourceNeedsFailure extends StatelessWidget {
  const _ResourceNeedsFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              l10n.projectResourcesSafeError,
              key: const Key('project-resource-needs-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.retryAction)),
        ],
      ),
    );
  }
}
