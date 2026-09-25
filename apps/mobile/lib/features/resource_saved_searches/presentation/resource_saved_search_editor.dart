import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../resource_listings/domain/resource_listing_models.dart';
import '../application/resource_saved_search_controller.dart';
import '../domain/resource_saved_search_models.dart';

enum ResourceSavedSearchModeChoice { all, donate, exchange }

Future<bool> showResourceSavedSearchEditor(
  BuildContext context, {
  required String expectedProfileId,
  required ResourceSavedSearch savedSearch,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => ResourceSavedSearchEditor(
        expectedProfileId: expectedProfileId,
        savedSearch: savedSearch,
      ),
    ) ??
    false;

class ResourceSavedSearchEditor extends ConsumerStatefulWidget {
  const ResourceSavedSearchEditor({
    required this.expectedProfileId,
    required this.savedSearch,
    super.key,
  });

  final String expectedProfileId;
  final ResourceSavedSearch savedSearch;

  @override
  ConsumerState<ResourceSavedSearchEditor> createState() =>
      _ResourceSavedSearchEditorState();
}

class _ResourceSavedSearchEditorState
    extends ConsumerState<ResourceSavedSearchEditor> {
  late final TextEditingController _queryController;
  late final TextEditingController _localityController;
  late ResourceSavedSearchModeChoice _modeChoice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.savedSearch.query);
    _localityController = TextEditingController(
      text: widget.savedSearch.locality,
    );
    _modeChoice = switch (widget.savedSearch.mode) {
      null => ResourceSavedSearchModeChoice.all,
      ResourceListingMode.donate => ResourceSavedSearchModeChoice.donate,
      ResourceListingMode.exchange => ResourceSavedSearchModeChoice.exchange,
    };
  }

  @override
  void dispose() {
    _queryController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(resourceSavedSearchesProvider);
    final isSaving =
        state.action == ResourceSavedSearchAction.updating &&
        state.actionTargetId == widget.savedSearch.id;
    return AlertDialog(
      title: Text(l10n.resourceSavedSearchEditTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<ResourceSavedSearchModeChoice>(
              key: const Key('saved-search-editor-mode'),
              segments: [
                ButtonSegment(
                  value: ResourceSavedSearchModeChoice.all,
                  label: Text(l10n.resourceModeAll),
                ),
                ButtonSegment(
                  value: ResourceSavedSearchModeChoice.donate,
                  label: Text(l10n.resourceModeDonate),
                ),
                ButtonSegment(
                  value: ResourceSavedSearchModeChoice.exchange,
                  label: Text(l10n.resourceModeExchange),
                ),
              ],
              selected: {_modeChoice},
              onSelectionChanged: isSaving
                  ? null
                  : (selection) => setState(() {
                      _modeChoice = selection.single;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('saved-search-editor-query'),
              controller: _queryController,
              enabled: !isSaving,
              maxLength: resourceSavedSearchTextMaxLength,
              decoration: InputDecoration(labelText: l10n.resourceSearchLabel),
              onChanged: (_) => setState(() => _error = null),
            ),
            TextField(
              key: const Key('saved-search-editor-locality'),
              controller: _localityController,
              enabled: !isSaving,
              maxLength: resourceSavedSearchTextMaxLength,
              decoration: InputDecoration(
                labelText: l10n.resourceLocalityLabel,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error case final error?)
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  key: const Key('saved-search-editor-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.resourceSavedSearchCancel),
        ),
        FilledButton(
          key: const Key('saved-search-editor-save'),
          onPressed: isSaving ? null : _save,
          child: isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.resourceSavedSearchSaveChanges),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final input = ResourceSavedSearchInput.normalized(
      query: _queryController.text,
      mode: switch (_modeChoice) {
        ResourceSavedSearchModeChoice.all => null,
        ResourceSavedSearchModeChoice.donate => ResourceListingMode.donate,
        ResourceSavedSearchModeChoice.exchange => ResourceListingMode.exchange,
      },
      locality: _localityController.text,
    );
    if (!input.isValid) {
      setState(() => _error = l10n.resourceSavedSearchAtLeastOneFilter);
      return;
    }
    final outcome = await ref
        .read(resourceSavedSearchesProvider.notifier)
        .update(widget.expectedProfileId, widget.savedSearch.id, input);
    if (!mounted) return;
    if (outcome == ResourceSavedSearchMutationOutcome.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _error = switch (outcome) {
        ResourceSavedSearchMutationOutcome.duplicate =>
          l10n.resourceSavedSearchUpdateDuplicate,
        ResourceSavedSearchMutationOutcome.invalidInput =>
          l10n.resourceSavedSearchInvalidInput,
        ResourceSavedSearchMutationOutcome.forbidden ||
        ResourceSavedSearchMutationOutcome.notFound =>
          l10n.resourceSavedSearchNoLongerAvailable,
        ResourceSavedSearchMutationOutcome.unavailable ||
        ResourceSavedSearchMutationOutcome.staleIdentity ||
        ResourceSavedSearchMutationOutcome.busy =>
          l10n.resourceSavedSearchUnableUpdate,
        ResourceSavedSearchMutationOutcome.success => null,
      };
    });
  }
}
