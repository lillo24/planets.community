import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/proposal_models.dart';

// Selection is staged in the menu; only Apply changes the discovery query.
class SkillFilter extends StatefulWidget {
  const SkillFilter({
    required this.categories,
    required this.selectedIds,
    required this.onApply,
    this.enabled = true,
    super.key,
  });

  final List<ProposalSkillCategory> categories;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onApply;
  final bool enabled;

  @override
  State<SkillFilter> createState() => _SkillFilterState();
}

class _SkillFilterState extends State<SkillFilter> {
  final _menu = MenuController();
  final _search = TextEditingController();
  Set<String> _draft = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_menu.isOpen) {
      _menu.close();
      return;
    }
    // Opening the filter must not summon a mobile keyboard, even if locality
    // was focused. Search only receives focus when the user explicitly taps it.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _draft = {...widget.selectedIds};
      _search.clear();
    });
    _menu.open();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final query = _search.text.trim().toLowerCase();
    final selected = [
      for (final category in widget.categories)
        for (final skill in category.skills)
          if (widget.selectedIds.contains(skill.id)) skill,
    ];
    final matches = {
      for (final category in widget.categories)
        category: category.skills
            .where(
              (skill) =>
                  skill.label.toLowerCase().contains(query) ||
                  category.label.toLowerCase().contains(query),
            )
            .toList(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MenuAnchor(
          controller: _menu,
          consumeOutsideTap: true,
          menuChildren: [
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): _menu.close,
              },
              child: Focus(
                // Focus the non-text menu for Escape, never the search input.
                autofocus: true,
                child: SizedBox(
                  width: math.min(360, size.width - 32),
                  height: math.min(400, size.height * .55),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          key: const Key('skill-filter-search'),
                          controller: _search,
                          autofocus: false,
                          decoration: InputDecoration(
                            labelText: l10n.skillFilterSearch,
                            prefixIcon: const Icon(Icons.search),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        Expanded(
                          child: ListView(
                            primary: false,
                            key: const Key('skill-filter-options'),
                            children: [
                              if (matches.values.every(
                                (skills) => skills.isEmpty,
                              ))
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(l10n.skillFilterNoMatches),
                                ),
                              for (final entry in matches.entries)
                                if (entry.value.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      entry.key.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ),
                                  for (final skill in entry.value)
                                    CheckboxListTile(
                                      key: Key(
                                        'proposal-filter-skill-${skill.slug}',
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: Text(skill.label),
                                      value: _draft.contains(skill.id),
                                      onChanged: (selected) => setState(() {
                                        if (selected == true) {
                                          _draft.add(skill.id);
                                        } else {
                                          _draft.remove(skill.id);
                                        }
                                      }),
                                    ),
                                ],
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              key: const Key('skill-filter-clear'),
                              onPressed: () => setState(_draft.clear),
                              child: Text(l10n.skillFilterClear),
                            ),
                            FilledButton(
                              key: const Key('skill-filter-apply'),
                              onPressed: () {
                                final selection = Set<String>.unmodifiable(
                                  _draft,
                                );
                                _menu.close();
                                FocusManager.instance.primaryFocus?.unfocus();
                                widget.onApply(selection);
                              },
                              child: Text(l10n.skillFilterApply),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          builder: (context, controller, child) => OutlinedButton.icon(
            key: const Key('skill-filter-trigger'),
            onPressed: widget.enabled ? _toggleMenu : null,
            icon: const Icon(Icons.filter_list),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.profileSkillsTitle),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        if (selected.isNotEmpty)
          Wrap(
            key: const Key('skill-filter-summary'),
            spacing: 6,
            children: [
              for (final skill in selected.take(2))
                Chip(
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(skill.label, overflow: TextOverflow.ellipsis),
                  ),
                ),
              if (selected.length > 2)
                Chip(label: Text(l10n.skillFilterMore(selected.length - 2))),
            ],
          ),
      ],
    );
  }
}
