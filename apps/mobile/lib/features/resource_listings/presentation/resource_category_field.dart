import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/resource_category.dart';

String resourceCategoryLabel(
  AppLocalizations l10n,
  ResourceCategory category,
) => switch (category) {
  ResourceCategory.toolsDiy => l10n.resourceCategoryToolsDiy,
  ResourceCategory.gardenOutdoors => l10n.resourceCategoryGardenOutdoors,
  ResourceCategory.homeFurniture => l10n.resourceCategoryHomeFurniture,
  ResourceCategory.electronics => l10n.resourceCategoryElectronics,
  ResourceCategory.clothingAccessories =>
    l10n.resourceCategoryClothingAccessories,
  ResourceCategory.booksLearning => l10n.resourceCategoryBooksLearning,
  ResourceCategory.sportsHobbies => l10n.resourceCategorySportsHobbies,
  ResourceCategory.materials => l10n.resourceCategoryMaterials,
  ResourceCategory.other => l10n.resourceCategoryOther,
};

class ResourceCategoryText extends StatelessWidget {
  const ResourceCategoryText({required this.category, super.key});
  final ResourceCategory category;

  @override
  Widget build(BuildContext context) => Text(
    resourceCategoryLabel(AppLocalizations.of(context), category),
    style: Theme.of(context).textTheme.labelMedium,
  );
}

/// One category or an explicit unset value. Menu labels wrap; the field stays compact.
class ResourceCategoryField extends StatelessWidget {
  const ResourceCategoryField({
    required this.category,
    required this.onChanged,
    this.enabled = true,
    this.showAll = false,
    this.requiredForPublication = false,
    this.validator,
    super.key,
  });

  final ResourceCategory? category;
  final ValueChanged<ResourceCategory?> onChanged;
  final bool enabled;
  final bool showAll;
  final bool requiredForPublication;
  final FormFieldValidator<ResourceCategory>? validator;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      showAll ? l10n.resourceCategoryAll : l10n.resourceCategoryUnset,
      for (final value in ResourceCategory.values)
        resourceCategoryLabel(l10n, value),
    ];
    return DropdownButtonFormField<ResourceCategory>(
      initialValue: category,
      isExpanded: true,
      itemHeight: null,
      decoration: InputDecoration(labelText: l10n.resourceCategoryField),
      selectedItemBuilder: (context) => [
        for (final label in labels)
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
      items: [
        DropdownMenuItem(value: null, child: Text(labels.first)),
        for (final value in ResourceCategory.values)
          DropdownMenuItem(
            value: value,
            child: Text(resourceCategoryLabel(l10n, value)),
          ),
      ],
      onChanged: enabled ? onChanged : null,
      validator:
          validator ??
          (value) => requiredForPublication && value == null
              ? l10n.resourceCategoryRequired
              : null,
    );
  }
}
