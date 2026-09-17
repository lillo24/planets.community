import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../application/project_resource_needs_controllers.dart';
import '../domain/project_resource_need_models.dart';

class ProjectResourceNeedsScreen extends ConsumerStatefulWidget {
  const ProjectResourceNeedsScreen({
    required this.projectId,
    required this.projectKind,
    super.key,
  });

  final String projectId;
  final ProjectKind projectKind;

  @override
  ConsumerState<ProjectResourceNeedsScreen> createState() =>
      _ProjectResourceNeedsScreenState();
}

class _ProjectResourceNeedsScreenState
    extends ConsumerState<ProjectResourceNeedsScreen> {
  late final String? _expectedCreatorProfileId;

  @override
  void initState() {
    super.initState();
    _expectedCreatorProfileId = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final profileId = _expectedCreatorProfileId;
    if (profileId == null ||
        ref.read(authSessionProvider).identity?.id != profileId) {
      return;
    }
    await ref
        .read(ownProjectResourceNeedsProvider(widget.projectId).notifier)
        .load(profileId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(ownProjectResourceNeedsProvider(widget.projectId));
    final belongsToScreen =
        state.expectedCreatorProfileId == _expectedCreatorProfileId &&
        state.projectId == widget.projectId;
    final items = belongsToScreen ? state.items : const <ProjectResourceNeed>[];
    final open = items.where((need) => need.isOpen).toList(growable: false);
    final closed = items.where((need) => !need.isOpen).toList(growable: false);
    final initiallyLoading =
        !belongsToScreen ||
        (state.phase == OwnProjectResourceNeedsPhase.loading && items.isEmpty);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.projectResourcesManageTitle)),
      body: SafeArea(
        child: initiallyLoading
            ? LoadingState(message: l10n.projectResourcesLoading)
            : state.phase == OwnProjectResourceNeedsPhase.failure &&
                  items.isEmpty
            ? ErrorState(
                message: _failureMessage(l10n, state.failure),
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
                          _failureMessage(l10n, failure),
                          key: const Key('project-resource-owner-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                    if (items.isEmpty)
                      EmptyState(
                        title: l10n.projectResourcesEmptyTitle,
                        message: l10n.projectResourcesEmptyMessage,
                      )
                    else ...[
                      _NeedGroup(
                        title: l10n.projectResourcesOpen,
                        items: open,
                        state: state,
                        onEdit: _edit,
                        onClose: _close,
                      ),
                      if (closed.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.large),
                        _NeedGroup(
                          title: l10n.projectResourcesClosed,
                          items: closed,
                          state: state,
                          onEdit: _edit,
                          onClose: _close,
                        ),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.large * 4),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('project-resource-add'),
        onPressed: state.isBusy ? null : () => _edit(null),
        icon: const Icon(Icons.add),
        label: Text(l10n.projectResourcesAddNeed),
      ),
    );
  }

  Future<void> _edit(ProjectResourceNeed? need) async {
    final input = await showDialog<ProjectResourceNeedInput>(
      context: context,
      builder: (context) => _ProjectResourceNeedDialog(need: need),
    );
    if (input == null || !mounted) return;
    final profileId = _expectedCreatorProfileId;
    if (profileId == null ||
        ref.read(authSessionProvider).identity?.id != profileId) {
      return;
    }
    final controller = ref.read(
      ownProjectResourceNeedsProvider(widget.projectId).notifier,
    );
    if (need == null) {
      await controller.create(
        expectedCreatorProfileId: profileId,
        input: input,
      );
    } else {
      await controller.update(
        expectedCreatorProfileId: profileId,
        resourceNeedId: need.id,
        input: input,
      );
    }
  }

  Future<void> _close(ProjectResourceNeed need) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.projectResourcesCloseConfirmTitle),
        content: Text(l10n.projectResourcesCloseConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.projectResourcesCancelAction),
          ),
          FilledButton(
            key: const Key('project-resource-confirm-close'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.projectResourcesCloseNeed),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final profileId = _expectedCreatorProfileId;
    if (profileId == null ||
        ref.read(authSessionProvider).identity?.id != profileId) {
      return;
    }
    await ref
        .read(ownProjectResourceNeedsProvider(widget.projectId).notifier)
        .close(expectedCreatorProfileId: profileId, resourceNeedId: need.id);
  }
}

class _NeedGroup extends StatelessWidget {
  const _NeedGroup({
    required this.title,
    required this.items,
    required this.state,
    required this.onEdit,
    required this.onClose,
  });

  final String title;
  final List<ProjectResourceNeed> items;
  final OwnProjectResourceNeedsState state;
  final ValueChanged<ProjectResourceNeed> onEdit;
  final ValueChanged<ProjectResourceNeed> onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.small),
        if (items.isEmpty)
          Text(l10n.projectResourcesNoOpenNeeds)
        else
          for (final need in items)
            Card(
              key: Key('owner-resource-need-${need.id}'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      need.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (need.details case final details?) ...[
                      const SizedBox(height: AppSpacing.xSmall),
                      Text(details),
                    ],
                    const SizedBox(height: AppSpacing.small),
                    if (need.isOpen)
                      Wrap(
                        spacing: AppSpacing.small,
                        children: [
                          OutlinedButton(
                            key: Key('project-resource-edit-${need.id}'),
                            onPressed: state.isBusy ? null : () => onEdit(need),
                            child: Text(l10n.projectResourcesEditNeed),
                          ),
                          TextButton(
                            key: Key('project-resource-close-${need.id}'),
                            onPressed: state.isBusy
                                ? null
                                : () => onClose(need),
                            child: Text(l10n.projectResourcesCloseNeed),
                          ),
                        ],
                      )
                    else
                      Text(
                        l10n.projectResourcesClosedReadOnly,
                        key: Key('project-resource-closed-${need.id}'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _ProjectResourceNeedDialog extends StatefulWidget {
  const _ProjectResourceNeedDialog({required this.need});

  final ProjectResourceNeed? need;

  @override
  State<_ProjectResourceNeedDialog> createState() =>
      _ProjectResourceNeedDialogState();
}

class _ProjectResourceNeedDialogState
    extends State<_ProjectResourceNeedDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _details;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.need?.title ?? '');
    _details = TextEditingController(text: widget.need?.details ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.need == null
            ? l10n.projectResourcesAddNeed
            : l10n.projectResourcesEditNeed,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('project-resource-title'),
                controller: _title,
                autofocus: true,
                maxLength: projectResourceNeedTitleMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.projectResourcesNeedTitleField,
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length < projectResourceNeedTitleMinLength ||
                      length > projectResourceNeedTitleMaxLength) {
                    return l10n.projectResourcesInvalidTitle(
                      projectResourceNeedTitleMinLength,
                      projectResourceNeedTitleMaxLength,
                    );
                  }
                  return null;
                },
              ),
              TextFormField(
                key: const Key('project-resource-details'),
                controller: _details,
                minLines: 3,
                maxLines: 6,
                maxLength: projectResourceNeedDetailsMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.projectResourcesDetailsOptional,
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    (value?.trim().length ?? 0) >
                        projectResourceNeedDetailsMaxLength
                    ? l10n.projectResourcesDetailsTooLong(
                        projectResourceNeedDetailsMaxLength,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.projectResourcesCancelAction),
        ),
        FilledButton(
          key: const Key('project-resource-save'),
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              ProjectResourceNeedInput(
                title: _title.text,
                details: _details.text,
              ),
            );
          },
          child: Text(l10n.projectResourcesSaveAction),
        ),
      ],
    );
  }
}

String _failureMessage(
  AppLocalizations l10n,
  ProjectResourceNeedsFailureKind? failure,
) => switch (failure) {
  ProjectResourceNeedsFailureKind.invalidInput =>
    l10n.projectResourcesInvalidInput,
  ProjectResourceNeedsFailureKind.forbidden => l10n.projectResourcesForbidden,
  ProjectResourceNeedsFailureKind.conflict => l10n.projectResourcesConflict,
  ProjectResourceNeedsFailureKind.notFound => l10n.projectResourcesNotFound,
  ProjectResourceNeedsFailureKind.unavailable ||
  null => l10n.projectResourcesSafeError,
};
