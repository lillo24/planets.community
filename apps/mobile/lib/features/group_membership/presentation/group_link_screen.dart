import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../groups/application/group_controllers.dart';
import '../../groups/presentation/group_widgets.dart';
import '../../project_participant_invites/presentation/share_link_buttons.dart';
import '../application/group_relationship_controller.dart';
import '../data/group_relationship_gateway.dart';
import '../domain/group_relationships.dart';
import 'group_membership_widgets.dart';

class GroupLinkScreen extends ConsumerStatefulWidget {
  const GroupLinkScreen({required this.groupId, super.key});
  final String groupId;
  @override
  ConsumerState<GroupLinkScreen> createState() => _GroupLinkScreenState();
}

class _GroupLinkScreenState extends ConsumerState<GroupLinkScreen> {
  String? actor;
  GroupSharingLink? link;
  Object? readError;
  GroupFailure? failure;
  bool loading = false, busy = false;
  int revision = 0;
  late final GroupSharingRegistry registry;
  Map<String, GroupSharingAttempt> get attempts => registry.attempts;
  GroupSharingAttempt? get pending => attempts[widget.groupId];
  bool valid(String id) =>
      mounted &&
      actor == id &&
      ref.read(authSessionProvider).identity?.id == id;
  @override
  void initState() {
    super.initState();
    registry = ref.read(groupSharingAttemptsProvider)
      ..addListener(sharingChanged);
    Future.microtask(bind);
  }

  void sharingChanged() {
    if (mounted) setState(() => busy = pending?.busy == true);
  }

  @override
  void dispose() {
    registry.removeListener(sharingChanged);
    revision++;
    super.dispose();
  }

  void bind() {
    revision++;
    actor = ref.read(authSessionProvider).identity?.id;
    link = null;
    failure = null;
    readError = null;
    busy = pending?.busy == true;
    loading = false;
    if (actor != null) {
      load();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> load() async {
    final id = actor;
    if (id == null) return;
    final epoch = ++revision;
    setState(() {
      loading = true;
      readError = null;
    });
    try {
      final row = await ref
          .read(groupRelationshipGatewayProvider)
          .sharing(id, widget.groupId);
      if (valid(id) && epoch == revision) setState(() => link = row);
    } catch (e) {
      if (valid(id) && epoch == revision) {
        setState(() {
          readError = e;
          if (groupFailure(e) == GroupFailure.denied) link = null;
        });
      }
    } finally {
      if (valid(id) && epoch == revision) setState(() => loading = false);
    }
  }

  Future<void> change({bool replace = false, String? revoke}) async {
    final id = actor;
    if (id == null || busy || !valid(id)) return;
    final l = AppLocalizations.of(context);
    if (pending == null) {
      if ((replace || revoke != null) &&
          !await confirmGroupAction(
            context,
            id,
            replace ? l.groupReplaceLink : l.groupRevokeLink,
            explanation: l.groupLinkConfirm,
          )) {
        return;
      }
      if (!mounted ||
          !valid(id) ||
          !await requireGroupPolicy(context, ref, id)) {
        return;
      }
      attempts[widget.groupId] = GroupSharingAttempt(id, replace, revoke);
    }
    if (!valid(id) || !groupPolicyAllows(ref, id)) return;
    final command = pending!;
    if (command.actor != id || command.busy) return;
    command.busy = true;
    registry.changed();
    final epoch = revision;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final row = await ref
          .read(groupRelationshipGatewayProvider)
          .changeSharing(
            id,
            widget.groupId,
            command.key,
            replace: command.replace,
            revokeId: command.revoke,
          );
      if (!registry.disposed && registry.identity() == id) {
        attempts.remove(widget.groupId);
      }
      if (!valid(id) || epoch != revision) return;
      setState(() {
        link = row;
        readError = null;
      });
      // A null token after later rotation is historical; only an explicit
      // current-sharing read can obtain the new secret.
    } catch (e) {
      if (valid(id) && epoch == revision) {
        setState(() {
          failure = groupFailure(e);
          if (failure == GroupFailure.denied) link = null;
        });
      }
    } finally {
      command.busy = false;
      registry.changed();
      if (valid(id) && epoch == revision) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.listen(
      authSessionProvider.select((s) => s.identity?.id),
      (_, _) => bind(),
    );
    return Scaffold(
      appBar: groupAppBar(context, l.groupParticipantLinks),
      body: GroupBody(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l.groupSharingExplanation),
            const SizedBox(height: 16),
            Text(l.groupReusable),
            if (loading || busy) const LinearProgressIndicator(),
            if (readError != null)
              GroupLoadError(error: readError, retry: load),
            GroupActionFailure(failure),
            if (pending != null &&
                !busy &&
                {
                  GroupFailure.denied,
                  GroupFailure.invalid,
                  GroupFailure.stale,
                  GroupFailure.prerequisite,
                }.contains(failure))
              OutlinedButton(
                onPressed: () {
                  attempts.remove(widget.groupId);
                  registry.changed();
                  load();
                },
                child: Text(l.groupsDiscard),
              ),
            if (!loading && readError == null && link == null)
              Text(l.groupNoLink),
            if (pending != null)
              OutlinedButton(
                onPressed: busy ? null : () => change(),
                child: Text(l.groupsRetry),
              ),
            if (link?.token != null && link?.revokedAt == null)
              ShareLinkButtons(
                projectId: widget.groupId,
                disabled: busy || pending != null,
                prepare: () async {
                  final id = actor;
                  if (id == null) return null;
                  final current = await ref
                      .read(groupRelationshipGatewayProvider)
                      .sharing(id, widget.groupId);
                  if (!valid(id)) return null;
                  setState(() => link = current);
                  return current?.token == null
                      ? null
                      : 'https://planets.community/join/group/${current!.token}';
                },
              ),
            if (link != null && link!.token == null && link!.revokedAt == null)
              Text(l.groupSecretLost),
            OutlinedButton(
              key: const Key('group-link-read'),
              onPressed: busy ? null : load,
              child: Text(l.groupsRefresh),
            ),
            if (link == null && readError == null && !loading)
              FilledButton(
                key: const Key('group-link-create'),
                onPressed: busy || pending != null ? null : () => change(),
                child: Text(l.groupDirectLink),
              ),
            if (link != null && link!.revokedAt == null) ...[
              OutlinedButton(
                key: const Key('group-link-replace'),
                onPressed: busy || pending != null
                    ? null
                    : () => change(replace: true),
                child: Text(l.groupReplaceLink),
              ),
              OutlinedButton(
                key: const Key('group-link-revoke'),
                onPressed: busy || pending != null
                    ? null
                    : () => change(revoke: link!.id),
                child: Text(l.groupRevokeLink),
              ),
            ],
            OutlinedButton(
              onPressed: () =>
                  context.push('/groups/${widget.groupId}/link-history'),
              child: Text(l.groupLinkHistory),
            ),
          ],
        ),
      ),
    );
  }
}
