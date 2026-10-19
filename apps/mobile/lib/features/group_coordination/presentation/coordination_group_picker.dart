import 'dart:math';

import 'package:flutter/material.dart';

import '../../group_contact/presentation/contact_button_style.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../groups/application/group_controllers.dart';
import '../../groups/data/group_gateway.dart';
import '../../groups/domain/group_models.dart';

Future<Map<String, String>?> chooseCoordinationGroups(
  BuildContext context,
  Set<String> excluded,
) => showDialog<Map<String, String>>(
  context: context,
  builder: (_) => CoordinationGroupPicker(excluded: excluded),
);

class CoordinationGroupPicker extends ConsumerStatefulWidget {
  const CoordinationGroupPicker({required this.excluded, super.key});
  final Set<String> excluded;
  @override
  ConsumerState<CoordinationGroupPicker> createState() =>
      _CoordinationGroupPickerState();
}

class _CoordinationGroupPickerState
    extends ConsumerState<CoordinationGroupPicker> {
  late final GroupPager<PublicGroup> pager;
  final search = TextEditingController();
  final selected = <String, String>{};
  String query = '';
  @override
  void initState() {
    super.initState();
    pager = GroupPager(
      (cursor) => ref
          .read(groupGatewayProvider)
          .publicPage(GroupFilters(search: query), cursor),
    );
    pager.addListener(changed);
    Future<void>.microtask(pager.load);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    pager.removeListener(changed);
    pager.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Dialog(
      child: SizedBox(
        width: 560,
        height: min(MediaQuery.sizeOf(context).height * .85, 650),
        child: Padding(
          padding: const EdgeInsets.all(16),
          // At large text sizes the header and actions can fill the dialog.
          // Share its bounded viewport with the results instead of shrinking
          // the selectable list to zero between fixed-height content.
          child: ListView(
            primary: false,
            padding: EdgeInsets.zero,
            children: [
              Text(
                l.coordinationChooseGroups,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(l.coordinationGroupBounds),
              TextField(
                key: const Key('coordination-search'),
                controller: search,
                decoration: InputDecoration(
                  labelText: l.coordinationSearchGroups,
                  suffixIcon: IconButton(
                    key: const Key('coordination-search-run'),
                    tooltip: l.coordinationSearchGroups,
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      query = search.text;
                      pager.reset();
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
                onSubmitted: (value) {
                  query = value;
                  pager.reset();
                },
              ),
              if (selected.isNotEmpty) Text(selected.values.join(' · ')),
              for (final g in pager.rows.where(
                (g) => !widget.excluded.contains(g.id),
              ))
                CheckboxListTile(
                  key: Key('coordination-group-${g.id}'),
                  title: Text(g.content.name),
                  value: selected.containsKey(g.id),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (yes) {
                    if (yes == true && selected.length >= 3) return;
                    setState(() {
                      if (yes == true) {
                        selected[g.id] = g.content.name;
                      } else {
                        selected.remove(g.id);
                      }
                    });
                  },
                ),
              if (pager.busy)
                const Center(child: CircularProgressIndicator())
              else if (pager.error != null) ...[
                Text(l.contactFailure),
                TextButton(onPressed: pager.load, child: Text(l.retryAction)),
              ] else if (pager.more)
                TextButton(
                  onPressed: pager.load,
                  child: Text(l.coordinationMoreGroups),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.groupCancel),
                  ),
                  FilledButton(
                    style: contactFilledButtonStyle,
                    key: const Key('coordination-use-groups'),
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            Map<String, String>.unmodifiable(selected),
                          ),
                    child: Text(l.coordinationUseGroups),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
