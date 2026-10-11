import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/user_scroll_pagination.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/group_controllers.dart';
import '../data/group_gateway.dart';
import '../domain/group_models.dart';
import 'group_widgets.dart';

class OwnGroupsScreen extends ConsumerWidget {
  const OwnGroupsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return GroupDirectoryScreen(key: ValueKey(session.identity!.id), own: true);
  }
}

class GroupDirectoryScreen extends ConsumerStatefulWidget {
  const GroupDirectoryScreen({this.own = false, super.key});
  final bool own;
  @override
  ConsumerState<GroupDirectoryScreen> createState() =>
      _GroupDirectoryScreenState();
}

class _GroupDirectoryScreenState extends ConsumerState<GroupDirectoryScreen> {
  late final GroupPager<PublicGroup> pager;
  final search = TextEditingController(), locality = TextEditingController();
  final scroll = ScrollController();
  GroupKind? kind;
  bool volunteering = false;
  Timer? debounce;
  late final String? actor;
  GroupFilters get filters => GroupFilters(
    search: search.text,
    locality: locality.text,
    kind: kind,
    volunteering: volunteering,
  );
  bool get valid =>
      groupLength(search.text) <= 120 && groupLength(locality.text) <= 120;
  @override
  void initState() {
    super.initState();
    actor = ref.read(authSessionProvider).identity?.id;
    final gateway = ref.read(groupGatewayProvider);
    pager = GroupPager((cursor) async {
      if (!widget.own) return gateway.publicPage(filters, cursor);
      if (actor == null ||
          ref.read(authSessionProvider).identity?.id != actor ||
          ref.read(authSessionProvider).phase != AuthSessionPhase.ready) {
        throw StateError('Account changed.');
      }
      return gateway.ownPage(actor!, cursor);
    });
    scheduleMicrotask(pager.load);
  }

  void changed({bool delay = false}) {
    debounce?.cancel();
    pager.clear();
    if (scroll.hasClients) scroll.jumpTo(0);
    if (valid) {
      if (delay) {
        debounce = Timer(const Duration(milliseconds: 350), pager.reset);
      } else {
        unawaited(pager.reset());
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    debounce?.cancel();
    pager.dispose();
    search.dispose();
    locality.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.listen(authSessionProvider, (before, after) {
      if (widget.own &&
          (after.identity?.id != actor ||
              after.phase != AuthSessionPhase.ready)) {
        pager.clear();
      }
    });
    return Scaffold(
      appBar: groupAppBar(
        context,
        widget.own ? l.groupsMy : l.groupsTitle,
        fallback: '/proposals',
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListenableBuilder(
              listenable: pager,
              builder: (context, _) => UserScrollPagination(
                enabled: pager.more && !pager.busy && pager.error == null,
                requestKey: (pager.epoch, pager.rows.length),
                onLoad: pager.load,
                builder: (context, fallback) => RefreshIndicator(
                  onRefresh: () => valid ? pager.reset() : Future<void>.value(),
                  child: ListView(
                    key: PageStorageKey(
                      widget.own ? 'own-groups' : 'public-groups',
                    ),
                    controller: scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!widget.own)
                            OutlinedButton.icon(
                              key: const Key('groups-my'),
                              onPressed: () async {
                                await context.push('/groups/mine');
                              },
                              icon: const Icon(Icons.folder_outlined),
                              label: Text(l.groupsMy),
                            ),
                          FilledButton.icon(
                            key: const Key('groups-create'),
                            onPressed: () async {
                              await context.push('/groups/create');
                              if (mounted) await pager.reset();
                            },
                            icon: const Icon(Icons.add),
                            label: Text(l.groupsCreate),
                          ),
                          IconButton(
                            tooltip: l.groupsRefresh,
                            onPressed: valid && !pager.busy
                                ? pager.reset
                                : null,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      if (!widget.own) ...[
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('groups-search'),
                          controller: search,
                          decoration: InputDecoration(
                            labelText: l.groupsSearch,
                            errorText: groupLength(search.text) > 120
                                ? l.groupsLimit
                                : null,
                            prefixIcon: const Icon(Icons.search),
                          ),
                          onChanged: (_) => changed(delay: true),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<GroupKind?>(
                          key: ValueKey(('groups-kind', kind)),
                          initialValue: kind,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(l.groupsAll),
                            ),
                            ...GroupKind.values.map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Text(groupKindLabel(l, v)),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            kind = v;
                            changed();
                          },
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.groupsVolunteer),
                          value: volunteering,
                          onChanged: (v) {
                            volunteering = v!;
                            changed();
                          },
                        ),
                        TextField(
                          key: const Key('groups-territory'),
                          controller: locality,
                          decoration: InputDecoration(
                            labelText: l.groupsTerritory,
                            errorText: groupLength(locality.text) > 120
                                ? l.groupsLimit
                                : null,
                          ),
                          onChanged: (_) => changed(delay: true),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: () {
                              search.clear();
                              locality.clear();
                              kind = null;
                              volunteering = false;
                              changed();
                            },
                            child: Text(l.groupsReset),
                          ),
                        ),
                      ],
                      if (pager.busy) const LinearProgressIndicator(),
                      if (pager.error != null)
                        GroupLoadError(error: pager.error, retry: pager.load),
                      if (!pager.busy &&
                          pager.error == null &&
                          pager.rows.isEmpty &&
                          valid)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            widget.own ? l.groupsOwnEmpty : l.groupsEmpty,
                          ),
                        ),
                      ...pager.rows.map(
                        (group) => Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: Key('group-card-${group.id}'),
                            onTap: () async {
                              await context.push(
                                '/groups/${group.id}${widget.own ? '/edit' : ''}',
                              );
                              if (mounted && widget.own) await pager.reset();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GroupSummary(group),
                                  if (group is OwnGroup) ...[
                                    const SizedBox(height: 12),
                                    Text(groupStateLabel(l, group.publication)),
                                    if (group.suppressed) Text(l.groupsHidden),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (pager.more && pager.error == null && !pager.busy)
                        TextButton(
                          key: const Key('groups-load-more'),
                          onPressed: pager.load,
                          child: Text(l.groupsMore),
                        ),
                      if (!pager.more && pager.rows.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(l.groupsEnd),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
