import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/group_attribution_draft.dart';
import '../data/group_project_gateway.dart';
import '../domain/group_project_models.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';

class ProjectGroupBadge extends StatelessWidget {
  const ProjectGroupBadge(this.attribution, {super.key});
  final ProjectGroupAttribution? attribution;
  @override
  Widget build(BuildContext context) {
    final group = attribution;
    if (group == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    if (!group.available) {
      return Text(
        l.groupProjectUnavailable,
        key: const Key('project-group-unavailable'),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('project-group-badge'),
        onPressed: () => context.push('/groups/${group.groupId}'),
        icon: const Icon(Icons.groups_outlined),
        label: Text(
          '${l.groupProjectFor(group.name!)} · ${group.kind == 'informal' ? l.groupsInformal : l.groupsOrganization}',
          softWrap: true,
        ),
      ),
    );
  }
}

class GroupPublishSelector extends StatefulWidget {
  const GroupPublishSelector({
    required this.draft,
    required this.enabled,
    required this.onChanged,
    super.key,
  });
  final GroupAttributionDraft draft;
  final bool enabled;
  final VoidCallback onChanged;
  @override
  State<GroupPublishSelector> createState() => _GroupPublishSelectorState();
}

class _GroupPublishSelectorState extends State<GroupPublishSelector> {
  String? selectedName;
  bool nameFailed = false;
  @override
  void initState() {
    super.initState();
    loadName();
  }

  @override
  void didUpdateWidget(GroupPublishSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.draft, widget.draft)) {
      selectedName = null;
      nameFailed = false;
      loadName();
    }
  }

  Future<void> loadName() async {
    final draft = widget.draft, group = widget.draft.groupId;
    if (group == null || draft.confirmed.name != null) return;
    try {
      final name = await draft.gateway.publicName(group);
      if (mounted && identical(widget.draft, draft) && draft.groupId == group) {
        setState(() => selectedName = name);
      }
    } catch (_) {
      if (mounted && identical(widget.draft, draft) && draft.groupId == group) {
        setState(() => nameFailed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selected = widget.draft.groupId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.groupProjectPublishFor,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          OutlinedButton.icon(
            key: const Key('group-publish-selector'),
            onPressed:
                !widget.enabled ||
                    widget.draft.pending ||
                    widget.draft.conflict ||
                    widget.draft.confirmed.frozen
                ? null
                : () async {
                    final owner = widget.draft;
                    final result = await showDialog<(String?, String?)>(
                      context: context,
                      builder: (_) => _GroupChooser(owner),
                    );
                    if (!mounted ||
                        result == null ||
                        !identical(widget.draft, owner)) {
                      return;
                    }
                    widget.draft.select(result.$1);
                    setState(() {
                      selectedName = result.$2;
                      nameFailed = false;
                    });
                    widget.onChanged();
                  },
            icon: Icon(
              selected == null ? Icons.person_outline : Icons.groups_outlined,
            ),
            label: Text(
              selected == null
                  ? l.groupProjectPersonal
                  : selectedName ??
                        (widget.draft.confirmed.groupId == selected
                            ? widget.draft.confirmed.name
                            : null) ??
                        l.groupProjectSelected,
            ),
          ),
          Text(
            l.groupProjectAuthorityBoundary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (widget.draft.pending) Text(l.groupProjectPending),
          if (nameFailed) Text(l.groupProjectLoadError),
          if (widget.draft.failed)
            Text(
              l.groupProjectSaveError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (widget.draft.conflict)
            TextButton(
              onPressed: !widget.enabled
                  ? null
                  : () async {
                      final owner = widget.draft;
                      try {
                        await owner.reload();
                        if (!mounted || !identical(widget.draft, owner)) return;
                        setState(() => selectedName = null);
                        widget.onChanged();
                      } catch (_) {
                        if (mounted && identical(widget.draft, owner)) {
                          setState(() => owner.failed = true);
                        }
                      }
                    },
              child: Text(l.groupProjectReload),
            ),
        ],
      ),
    );
  }
}

class _GroupChooser extends ConsumerStatefulWidget {
  const _GroupChooser(this.draft);
  final GroupAttributionDraft draft;
  @override
  ConsumerState<_GroupChooser> createState() => _GroupChooserState();
}

class _GroupChooserState extends ConsumerState<_GroupChooser> {
  final items = <PublishableGroup>[];
  bool busy = true, more = true;
  bool failed = false;
  bool current() {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == widget.draft.actor;
  }

  void choose((String?, String?) value) {
    Navigator.pop(context, current() ? value : null);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!current()) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final page = await widget.draft.gateway.eligible(
        widget.draft.actor,
        after: items.lastOrNull,
      );
      if (!mounted) return;
      if (!current()) {
        setState(() {
          items.clear();
          busy = false;
          failed = true;
        });
        return;
      }
      setState(() {
        items.addAll(page);
        more = page.length == 20;
        busy = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          if (!current() ||
              (error is PostgrestException && error.code == '42501')) {
            items.clear();
          }
          failed = true;
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.watch(authSessionProvider);
    if (!current()) {
      return AlertDialog(
        title: Text(l.groupProjectPublishFor),
        content: Text(l.groupProjectAccountChanged),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.groupCancel),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(l.groupProjectPublishFor),
      content: SizedBox(
        width: 480,
        height: 360,
        child: ListView(
          children: [
            ListTile(
              key: const Key('group-publish-personal'),
              leading: const Icon(Icons.person_outline),
              title: Text(l.groupProjectPersonal),
              onTap: () => choose((null, null)),
            ),
            for (final item in items)
              ListTile(
                key: ValueKey('publish-for-${item.id}'),
                leading: const Icon(Icons.groups_outlined),
                title: Text(item.name),
                subtitle: Text(
                  item.kind == 'informal'
                      ? l.groupsInformal
                      : l.groupsOrganization,
                ),
                onTap: () => choose((item.id, item.name)),
              ),
            if (busy) const Center(child: CircularProgressIndicator()),
            if (failed) Text(l.groupProjectLoadError),
            if (!busy && (more || failed))
              TextButton(
                onPressed: load,
                child: Text(failed ? l.retryAction : l.groupProjectMore),
              ),
            if (!busy && !failed && items.isEmpty)
              Text(l.groupProjectNoEligible),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.groupCancel),
        ),
      ],
    );
  }
}

class GroupProjectFeed extends ConsumerStatefulWidget {
  const GroupProjectFeed({required this.groupId, super.key});
  final String groupId;
  @override
  ConsumerState<GroupProjectFeed> createState() => _GroupProjectFeedState();
}

class _GroupProjectFeedState extends ConsumerState<GroupProjectFeed> {
  final items = <GroupProject>[];
  bool busy = true, more = true, failed = false;
  int epoch = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(GroupProjectFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      epoch++;
      items.clear();
      more = true;
      load();
    }
  }

  Future<void> load() async {
    final revision = ++epoch;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final page = await ref
          .read(groupProjectGatewayProvider)
          .feed(widget.groupId, after: items.lastOrNull);
      if (!mounted || revision != epoch) return;
      setState(() {
        items.addAll(page);
        more = page.length == 20;
        busy = false;
      });
    } catch (error) {
      if (!mounted || revision != epoch) return;
      setState(() {
        if (error is PostgrestException && error.code == '42501') items.clear();
        failed = true;
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          l.groupProjectFeedTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final item in items)
          Card(
            child: ListTile(
              key: ValueKey('group-project-${item.id}'),
              leading: Icon(
                item.recurring
                    ? Icons.event_repeat
                    : item.idea
                    ? Icons.lightbulb_outline
                    : Icons.event_outlined,
              ),
              title: Text(item.title),
              subtitle: Text(
                '${item.recurring
                    ? l.messagesTavolo
                    : item.idea
                    ? l.proposalPhaseIdea
                    : l.proposalPhaseDefined}\n${item.summary}',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(item.route),
            ),
          ),
        if (busy) const Center(child: CircularProgressIndicator()),
        if (failed) Text(l.groupProjectLoadError),
        if (!busy && (more || failed))
          TextButton(
            onPressed: load,
            child: Text(failed ? l.retryAction : l.groupProjectMore),
          ),
        if (!busy && !failed && items.isEmpty) Text(l.groupProjectFeedEmpty),
      ],
    );
  }
}
