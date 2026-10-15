import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/detail_section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/project_resource_needs_controllers.dart';

class ProjectResourceNeedsSection extends ConsumerStatefulWidget {
  const ProjectResourceNeedsSection({
    required this.projectId,
    this.showHeading = true,
    this.showEmpty = false,
    this.headingAction,
    super.key,
  });

  final String projectId;
  final bool showHeading, showEmpty;

  /// Shown with the heading, including an otherwise hidden empty owner section.
  /// The caller retains ownership of authorization and navigation.
  final Widget? headingAction;

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
        state.items.isEmpty &&
        (!widget.showHeading || widget.headingAction == null)) {
      return widget.showEmpty
          ? Text(l10n.projectResourcesEmptyTitle)
          : const SizedBox.shrink();
    }

    return Padding(
      key: Key('project-resource-needs-${widget.projectId}'),
      padding: const EdgeInsets.only(top: AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeading)
            DetailSectionHeader(
              icon: Icons.inventory_2_outlined,
              title: l10n.detailMaterialsTitle,
              action: widget.headingAction,
            ),
          if (widget.showHeading) Text(l10n.detailMaterialsHint),
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
            for (final need in state.items)
              Padding(
                key: Key('public-resource-need-${need.id}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.medium),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 20),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            need.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (need.details case final details?) ...[
                            const SizedBox(height: AppSpacing.xSmall),
                            Text(details),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.showEmpty &&
                state.items.isEmpty &&
                state.failure == null)
              Text(l10n.projectResourcesEmptyTitle),
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
