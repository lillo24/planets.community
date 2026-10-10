import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/tag_multi_select.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/proposal_models.dart';
import '../domain/proposal_time.dart';

/// Raw input and canonical validation remain owned by the editor form.
class ProposalCapacityControl extends StatelessWidget {
  const ProposalCapacityControl({
    required this.controller,
    required this.enabled,
    required this.validator,
    required this.onChanged,
    super.key,
  });
  final TextEditingController controller;
  final bool enabled;
  final FormFieldValidator<String> validator;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final raw = value.text.trim();
        final number = int.tryParse(raw);
        final valid = number != null && number >= 1 && number <= 100000;
        void step(int delta) {
          // Read at tap time too: a paste and a rapid tap may precede rebuild.
          final current = controller.text.trim();
          final parsed = current.isEmpty && delta > 0
              ? 0
              : int.tryParse(current);
          if (parsed == null ||
              (current.isNotEmpty && parsed < 1) ||
              parsed > 100000) {
            return;
          }
          final next = parsed + delta;
          if (next < 1 || next > 100000) {
            return;
          }
          controller.text = next.toString();
          onChanged();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton.outlined(
                  key: const Key('proposal-capacity-minus'),
                  tooltip: l.proposalCapacityDecrease,
                  onPressed: enabled && valid && number > 1
                      ? () => step(-1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: TextFormField(
                    key: const Key('proposal-people-capacity'),
                    controller: controller,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.projectRegistrationCapacityLabel,
                    ),
                    validator: validator,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                IconButton.outlined(
                  key: const Key('proposal-capacity-plus'),
                  tooltip: l.proposalCapacityIncrease,
                  onPressed:
                      enabled && (raw.isEmpty || (valid && number < 100000))
                      ? () => step(1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              l.projectRegistrationCapacityHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

/// Formats named-zone wall time without consulting the device timezone.
class ProposalDateControl extends StatelessWidget {
  const ProposalDateControl({
    required this.label,
    required this.value,
    required this.timezone,
    required this.enabled,
    required this.onPick,
    required this.validator,
    required this.fieldKey,
    required this.pickKey,
    super.key,
  });
  final String label;
  final DateTime? value;
  final String timezone;
  final bool enabled;
  final VoidCallback onPick;
  final FormFieldValidator<DateTime?> validator;
  final Key fieldKey;
  final Key pickKey;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = value == null
        ? l.proposalChooseDateTime
        : !isKnownProposalTimeZone(timezone)
        ? l.proposalTimezoneError
        : DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
              .add_jm()
              .format(proposalUtcToWallTime(value!, timezone));
    return FormField<DateTime?>(
      key: fieldKey,
      validator: validator,
      builder: (field) => InkWell(
        key: pickKey,
        onTap: enabled ? onPick : null,
        borderRadius: AppRadii.medium,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            enabled: enabled,
            errorText: field.errorText,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
            child: Text(text),
          ),
        ),
      ),
    );
  }
}

class ProposalControlPair extends StatelessWidget {
  const ProposalControlPair({
    required this.first,
    required this.second,
    super.key,
  });
  final Widget first;
  final Widget second;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stack =
          constraints.maxWidth < 360 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.4;
      return stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                first,
                const SizedBox(height: AppSpacing.medium),
                second,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: first),
                const SizedBox(width: AppSpacing.medium),
                Expanded(child: second),
              ],
            );
    },
  );
}

/// Shared selected-ID picker plus Project-only importance. New skills are Useful.
class ProposalSkillsControl extends StatelessWidget {
  const ProposalSkillsControl({
    required this.categories,
    required this.values,
    required this.enabled,
    required this.onChanged,
    super.key,
  });
  final List<ProposalSkillCategory> categories;
  final Map<String, ProposalSkillImportance> values;
  final bool enabled;
  final ValueChanged<Map<String, ProposalSkillImportance>> onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TagMultiSelect(
          label: l.proposalSkillsTitle,
          emptyLabel: l.skillSelectorPlaceholder,
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
          selectedIds: values.keys.toSet(),
          enabled: enabled,
          keyPrefix: 'proposal-skills',
          onChanged: (ids) => onChanged({
            for (final id in ids)
              id: values[id] ?? ProposalSkillImportance.useful,
          }),
        ),
        for (final category in categories)
          for (final skill in category.skills.where(
            (skill) => values.containsKey(skill.id),
          ))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              // A full-width selector also fits translated labels at 2x text.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(skill.label),
                  DropdownButton<ProposalSkillImportance>(
                    isExpanded: true,
                    key: Key('proposal-skill-${skill.slug}'),
                    value: values[skill.id],
                    onChanged: enabled
                        ? (importance) {
                            if (importance != null) {
                              onChanged({...values, skill.id: importance});
                            }
                          }
                        : null,
                    items: [
                      DropdownMenuItem(
                        value: ProposalSkillImportance.required,
                        child: Text(l.proposalSkillRequired),
                      ),
                      DropdownMenuItem(
                        value: ProposalSkillImportance.useful,
                        child: Text(l.proposalSkillUseful),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
