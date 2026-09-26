import 'package:flutter/material.dart';

import '../../../core/widgets/tag_multi_select.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/proposal_models.dart';

// Selection is staged in the bounded sheet; only Apply changes discovery.
class SkillFilter extends StatelessWidget {
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
  Widget build(BuildContext context) => TagMultiSelect(
    label: AppLocalizations.of(context).profileSkillsTitle,
    emptyLabel: AppLocalizations.of(context).skillSelectorPlaceholder,
    categories: [
      for (final category in categories)
        TagMultiSelectCategory(
          id: category.slug,
          label: category.label,
          options: [
            for (final skill in category.skills)
              TagMultiSelectOption(
                id: skill.id,
                label: skill.label,
                keyValue: skill.slug,
              ),
          ],
        ),
    ],
    selectedIds: selectedIds,
    onChanged: onApply,
    keyPrefix: 'skill-filter',
    enabled: enabled,
    staged: true,
  );
}
