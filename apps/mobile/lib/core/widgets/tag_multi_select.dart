import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_tokens.dart';

class TagMultiSelectOption {
  const TagMultiSelectOption({
    required this.id,
    required this.label,
    required this.keyValue,
  });

  final String id;
  final String label;
  final String keyValue;
}

class TagMultiSelectCategory {
  const TagMultiSelectCategory({
    required this.id,
    required this.label,
    required this.options,
  });

  final String id;
  final String label;
  final List<TagMultiSelectOption> options;
}

/// A controlled, compact tag selector backed by a bounded bottom sheet.
///
/// With [staged] set, changes are published only when Apply is tapped. Without
/// it, each chip toggle updates the parent-owned selection immediately.
class TagMultiSelect extends StatelessWidget {
  const TagMultiSelect({
    required this.label,
    required this.placeholder,
    required this.categories,
    required this.selectedIds,
    required this.onChanged,
    required this.keyPrefix,
    this.enabled = true,
    this.staged = false,
    super.key,
  });

  final String label;
  final String placeholder;
  final List<TagMultiSelectCategory> categories;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final String keyPrefix;
  final bool enabled;
  final bool staged;

  List<TagMultiSelectOption> get _options => [
    for (final category in categories) ...category.options,
  ];

  Future<void> _open(BuildContext context) async {
    if (!enabled) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _TagMultiSelectSheet(
        categories: categories,
        initialSelection: selectedIds,
        keyPrefix: keyPrefix,
        staged: staged,
        onImmediateChanged: staged ? null : onChanged,
      ),
    );
    if (staged && result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = _options
        .where((option) => selectedIds.contains(option.id))
        .toList(growable: false);
    final visible = selected.take(2).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: l10n.skillSelectorSelectionCount(selected.length),
          child: InkWell(
            key: Key('$keyPrefix-trigger'),
            borderRadius: AppRadii.medium,
            onTap: enabled ? () => _open(context) : null,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                enabled: enabled,
                suffixIcon: const Icon(Icons.expand_more),
              ),
              isEmpty: selected.isEmpty,
              child: selected.isEmpty
                  ? Text(
                      placeholder,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Wrap(
                      key: Key('$keyPrefix-summary'),
                      spacing: AppSpacing.small,
                      runSpacing: AppSpacing.xSmall,
                      children: [
                        for (final option in visible)
                          Semantics(
                            label: l10n.skillSelectorRemove(option.label),
                            button: true,
                            excludeSemantics: true,
                            child: InputChip(
                              key: Key(
                                '$keyPrefix-selected-${option.keyValue}',
                              ),
                              label: Text(option.label),
                              visualDensity: VisualDensity.compact,
                              deleteIcon: const Icon(Icons.cancel),
                              deleteButtonTooltipMessage: l10n
                                  .skillSelectorRemove(option.label),
                              onDeleted: enabled
                                  ? () => onChanged(
                                      Set<String>.unmodifiable(
                                        selectedIds.difference({option.id}),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        if (selected.length > visible.length)
                          Chip(
                            key: Key('$keyPrefix-more'),
                            label: Text(
                              l10n.skillFilterMore(
                                selected.length - visible.length,
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TagMultiSelectSheet extends StatefulWidget {
  const _TagMultiSelectSheet({
    required this.categories,
    required this.initialSelection,
    required this.keyPrefix,
    required this.staged,
    required this.onImmediateChanged,
  });

  final List<TagMultiSelectCategory> categories;
  final Set<String> initialSelection;
  final String keyPrefix;
  final bool staged;
  final ValueChanged<Set<String>>? onImmediateChanged;

  @override
  State<_TagMultiSelectSheet> createState() => _TagMultiSelectSheetState();
}

class _TagMultiSelectSheetState extends State<_TagMultiSelectSheet> {
  final _search = TextEditingController();
  late Set<String> _selection;

  @override
  void initState() {
    super.initState();
    _selection = {...widget.initialSelection};
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _publishImmediate() {
    widget.onImmediateChanged?.call(Set<String>.unmodifiable(_selection));
  }

  void _toggle(String id) {
    setState(() {
      if (!_selection.add(id)) {
        _selection.remove(id);
      }
    });
    _publishImmediate();
  }

  void _clear() {
    setState(_selection.clear);
    _publishImmediate();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _search.text.trim().toLowerCase();
    final matches = [
      for (final category in widget.categories)
        TagMultiSelectCategory(
          id: category.id,
          label: category.label,
          options:
              (category.label.toLowerCase().contains(query)
                      ? category.options
                      : category.options.where(
                          (option) =>
                              option.label.toLowerCase().contains(query),
                        ))
                  .toList(growable: false),
        ),
    ];
    final hasMatches = matches.any((category) => category.options.isNotEmpty);

    return FractionallySizedBox(
      heightFactor: .78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.medium,
          AppSpacing.small,
          AppSpacing.medium,
          AppSpacing.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            TextField(
              key: Key('${widget.keyPrefix}-search'),
              controller: _search,
              autofocus: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: l10n.skillFilterSearch,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              l10n.skillSelectorSelectionCount(_selection.length),
              key: Key('${widget.keyPrefix}-selection-count'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.small),
            Expanded(
              child: ListView(
                key: Key('${widget.keyPrefix}-options'),
                children: [
                  if (!hasMatches)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.large),
                      child: Text(l10n.skillFilterNoMatches),
                    ),
                  for (final category in matches)
                    if (category.options.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.medium,
                          bottom: AppSpacing.small,
                        ),
                        child: Text(
                          category.label,
                          key: Key(
                            '${widget.keyPrefix}-category-${category.id}',
                          ),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Wrap(
                        spacing: AppSpacing.small,
                        runSpacing: AppSpacing.small,
                        children: [
                          for (final option in category.options)
                            Semantics(
                              selected: _selection.contains(option.id),
                              label: _selection.contains(option.id)
                                  ? l10n.skillSelectorSelected(option.label)
                                  : l10n.skillSelectorNotSelected(option.label),
                              button: true,
                              excludeSemantics: true,
                              child: FilterChip(
                                key: Key(
                                  '${widget.keyPrefix}-option-${option.keyValue}',
                                ),
                                label: Text(option.label),
                                selected: _selection.contains(option.id),
                                showCheckmark: true,
                                onSelected: (_) => _toggle(option.id),
                              ),
                            ),
                        ],
                      ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Row(
              children: [
                TextButton(
                  key: Key('${widget.keyPrefix}-clear'),
                  onPressed: _selection.isEmpty ? null : _clear,
                  child: Text(l10n.skillFilterClear),
                ),
                const Spacer(),
                FilledButton(
                  key: Key('${widget.keyPrefix}-apply'),
                  onPressed: () =>
                      Navigator.of(context)
                          .pop(Set<String>.unmodifiable(_selection)),
                  child: Text(
                    widget.staged
                        ? l10n.skillFilterApply
                        : l10n.skillSelectorDone,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
